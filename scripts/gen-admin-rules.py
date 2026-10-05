#!/usr/bin/env python3
"""Generate shared/traefik/advanced/admin-routers.yml from .env (ADR-009).

The Traefik file provider watches shared/traefik/advanced, so after editing
.env (TRUSTED_IP and friends) and re-running this script -- directly or via
scripts/setup.sh -- the admin routers, allow lists, and login redirects
hot-reload without restarting any container.

The output embeds the dashboard basic-auth hash, so it is git-ignored.
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXAMPLE = os.path.join(ROOT, "env.example")
OUT = os.path.join(ROOT, "shared", "traefik", "advanced", "admin-routers.yml")


def load(path):
    values = {}
    if not os.path.exists(path):
        return values
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            val = val.strip()
            # Double-quoted .env values get shell-style unescaping; legacy
            # values may carry backslash-escaped dollars from the old
            # compose-label days (TRAEFIK_BAAUTH="admin:\$apr1$...").
            if len(val) >= 2 and val.startswith('"') and val.endswith('"'):
                val = val[1:-1].replace('\\"', '"').replace("\\$", "$")
            else:
                val = val.strip('"')
            values[key.strip()] = val
    return values


def expand(val, env, depth=10):
    """Resolve ${VAR} references from the same environment (single level)."""
    for _ in range(depth):
        match = re.search(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}", val)
        if not match:
            break
        val = val[: match.start()] + env.get(match.group(1), "") + val[match.end():]
    return val


def emit(obj, indent, out):
    pad = "    " * indent
    if isinstance(obj, dict):
        for key, val in obj.items():
            if isinstance(val, dict):
                if val:
                    out.append(f"{pad}{key}:")
                    emit(val, indent + 1, out)
                else:
                    out.append(f"{pad}{key}: {{}}")
            elif isinstance(val, list):
                if val:
                    out.append(f"{pad}{key}:")
                    emit(val, indent + 1, out)
                else:
                    out.append(f"{pad}{key}: []")
            elif isinstance(val, bool):
                out.append(f"{pad}{key}: {'true' if val else 'false'}")
            elif isinstance(val, (int, float)):
                out.append(f"{pad}{key}: {val}")
            elif val == "":
                out.append(f"{pad}{key}: \"\"")
            else:
                out.append(f"{pad}{key}: {json.dumps(val)}")
    elif isinstance(obj, list):
        for item in obj:
            out.append(f"{pad}- {json.dumps(item)}")


def main():
    env_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, ".env")
    if not os.path.exists(env_path):
        print(f"warning: {env_path} not found; falling back to env.example defaults",
              file=sys.stderr)
    env = load(EXAMPLE)
    user = load(env_path)
    # DOMAIN_NAME and IDENTITY_DOMAIN fall back to the env.example defaults
    # when unset or empty in .env; every other key keeps the .env value.
    for key in ("DOMAIN_NAME", "IDENTITY_DOMAIN"):
        if not user.get(key):
            user[key] = env.get(key, "")
    env.update(user)
    for key in ("TRUSTED_IP", "TRAEFIK_DOMAIN", "EMAIL_HOST", "IDENTITY_DOMAIN",
                "CERTRESOLVER", "TRAEFIK_BAAUTH"):
        env[key] = expand(env.get(key, ""), env)

    trusted = [r.strip() for r in env["TRUSTED_IP"].split(",") if r.strip()]
    clientip = " || ".join(f"ClientIP(`{r}`)" for r in trusted)
    # Plain TLS with the default certificate when CERTRESOLVER is empty
    # (staging/self-signed); otherwise the ACME resolver.
    tls = {"certResolver": env["CERTRESOLVER"]} if env["CERTRESOLVER"] else {}
    redirect = {
        "redirectRegex": {
            "regex": "^https?://.*",
            "replacement": f"https://{env['IDENTITY_DOMAIN']}",
            "permanent": False,
        }
    }
    whitelist = {"ipAllowList": {"sourceRange": trusted}}
    basicauth = {"basicAuth": {"users": [env["TRAEFIK_BAAUTH"]]}}
    entry, mid_secure = ["websecure"], "secure-chain"

    routers = {}
    middlewares = {
        "dashboard-login-redirect": redirect,
        "mailsvstalwart-login-redirect": redirect,
    }
    if trusted:
        # Trusted clients reach the admin service; everyone else is redirected.
        routers["dashboard"] = {
            "rule": f"Host(`{env['TRAEFIK_DOMAIN']}`) && ({clientip})",
            "entryPoints": entry,
            "service": "api@internal",
            "priority": 300,
            "middlewares": [mid_secure, "dashboard-whitelist", "dashboard-auth"],
            "tls": tls,
        }
        routers["mailsvstalwart-admin"] = {
            "rule": (f"Host(`{env['EMAIL_HOST']}`) && ({clientip}) && "
                     "!(PathPrefix(`/jmap`) || PathPrefix(`/.well-known/jmap`))"),
            "entryPoints": entry,
            "service": "mailsvstalwart@docker",
            "priority": 300,
            "middlewares": [mid_secure, "mailsvstalwart-whitelist"],
            "tls": tls,
        }
        middlewares["dashboard-whitelist"] = whitelist
        middlewares["mailsvstalwart-whitelist"] = whitelist
        middlewares["dashboard-auth"] = basicauth
    else:
        print("warning: TRUSTED_IP is empty; admin routers omitted (fail closed)",
              file=sys.stderr)

    routers["dashboard-untrusted"] = {
        "rule": f"Host(`{env['TRAEFIK_DOMAIN']}`)",
        "entryPoints": entry,
        "service": "api@internal",
        "priority": 100,
        "middlewares": [mid_secure, "dashboard-login-redirect"],
        "tls": tls,
    }
    routers["mailsvstalwart-untrusted"] = {
        "rule": (f"Host(`{env['EMAIL_HOST']}`) && "
                 "!(PathPrefix(`/jmap`) || PathPrefix(`/.well-known/jmap`))"),
        "entryPoints": entry,
        "service": "mailsvstalwart@docker",
        "priority": 100,
        "middlewares": [mid_secure, "mailsvstalwart-login-redirect"],
        "tls": tls,
    }

    lines = [
        "# GENERATED by scripts/gen-admin-rules.py -- do not edit by hand.",
        "# Edit .env (TRUSTED_IP, TRAEFIK_DOMAIN, EMAIL_HOST, IDENTITY_DOMAIN,",
        "# CERTRESOLVER, TRAEFIK_BAAUTH) and re-run scripts/setup.sh (or this",
        "# script directly). Traefik watches this directory and hot-reloads,",
        "# so no container restart is needed (ADR-009).",
        "",
    ]
    emit({"http": {"routers": routers, "middlewares": middlewares}}, 0, lines)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {os.path.relpath(OUT, ROOT)} from {env_path} "
          f"({len(routers)} routers, {len(trusted)} trusted ranges)")


if __name__ == "__main__":
    main()

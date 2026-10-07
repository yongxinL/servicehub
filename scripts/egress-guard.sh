#!/bin/sh
# Container egress controls — ADR-009 decision 5.
#
# Two layers, both enforced in the Docker DOCKER-USER chain (container traffic
# only — the host's own outbound traffic is unaffected):
#
#   1. Per-service policy, from egress-policies.conf — the live copy is
#      ${APPS_DATA}/egress-policies.conf (runtime state, seeded from the
#      repository default by scripts/setup.sh), overridden by EGRESS_POLICIES:
#        restricted        RFC1918 destinations plus the host's own public IP
#                          (hairpin to Traefik via login.<domain> etc.); logged,
#                          all else dropped
#        allow-blocked     full internet INCLUDING the blocked ranges (overrides layer 2)
#        internet          default: full internet minus the global block
#        allow-domain <name>  standing exception: this service may reach every
#                          resolved address of <name>; rebuilt each apply
#        block-domain <name>  this service may NOT reach <name>; resolved each
#                          apply, installed above every allow so it wins
#   2. Global block: traffic from ANY container to the CIDRs listed in
#      EGRESS_BLOCK_URL (from .env) is logged and dropped — one ipset holds
#      the ranges, so it is a single rule.
#
# Services are resolved by the Compose service label, so project-prefixed
# container names (servicehub-webappconf-1) do not matter.
#
#   apply               apply all policies and the global block now
#   watch               apply; re-apply when a listed container's address changes;
#                       refreshes the blocked set at startup
#   status              policies, addresses, rules, set size, counters
#   blocked-refresh     reload the blocklist CIDRs into the ipset; every URL
#                       in EGRESS_BLOCK_URL is fetched, one set
#   allow <service> <cidr|ipv4|hostname>   time-boxed exception (a hostname
#                       resolves now to every A record); record it, then revoke
#   revoke <service> <cidr|ipv4|hostname>
#   remove            strip every installed egress rule (policies file is kept;
#                     apply reinstalls — stop the watch unit first if running)
#   selftest            offline check of the rule logic (no root, no Docker)
#
# Requires Docker Engine (podman/netavark does not traverse DOCKER-USER),
# ipset and python3 for the global block.
set -eu

CHAIN=${EGRESS_CHAIN:-DOCKER-USER}
AUX=${EGRESS_AUX_CHAIN:-EGRESS_RESTRICTED}
SET=${EGRESS_BLOCKED_SET:-blocked}
Policies() { # 'service policy' lines from the policy file
  conf=${EGRESS_POLICIES:-}
  if [ -z "$conf" ]; then
    # The live copy lives under APPS_DATA, where a deploy's rsync never touches
    # it (operator edits survive) and the weekly full archive already covers it.
    # Fall back to the repository default on a host that has not been seeded yet.
    apps=$(env_get APPS_DATA)
    case $apps in "~"*) apps=$HOME${apps#"~"} ;; esac
    if [ -n "$apps" ] && [ -f "$apps/egress-policies.conf" ]; then
      conf=$apps/egress-policies.conf
    else
      conf="$(dirname "$0")/egress-policies.conf"
    fi
  fi
  [ -f "$conf" ] || return 0
  awk 'NF >= 2 && $1 !~ /^#/ { if (NF >= 3) print $1, $2, $3; else print $1, $2 }' "$conf"
}
# Value of $1 from EGRESS_ENV_FILE, else from the repo .env (the same file
# Compose and scripts/setup.sh read). Empty when the file or key is absent.
env_get() {
  f=${EGRESS_ENV_FILE:-"$(dirname "$0")/../.env"}
  [ -f "$f" ] || return 0
  sed -n "s/^$1=//p" "$f" | head -1 | tr -d '"'
}
# CIDR feeds, one per line: EGRESS_BLOCK_URL if set, else EGRESS_BLOCK_URL
# from the repo .env (the same file Compose and scripts/setup.sh read).
# EGRESS_ENV_FILE overrides the path, as EGRESS_POLICIES does for the policy
# file. Several feeds may be listed, separated by whitespace; every CIDR they
# publish merges into the one blocked ipset.
feed_urls() {
  v=${EGRESS_BLOCK_URL:-}
  [ -n "$v" ] || v=$(env_get EGRESS_BLOCK_URL)
  [ -n "$v" ] || return 0
  printf '%s\n' $v
}
LOG_RATE=20/min
LIMIT="-m limit --limit $LOG_RATE"

die() { echo "egress: $*" >&2; exit 1; }
warn() { echo "egress: WARNING: $*" >&2; }

if [ "$(id -u)" -ne 0 ] && [ "${1:-}" != "selftest" ] && [ -z "${EGRESS_NOSUDO:-}" ]; then
  exec sudo "$0" "$@"
fi

# The host's own public address — restricted containers hairpin back into
# Traefik when public names (login.<domain>, ...) resolve to it. Override with
# EGRESS_SELF_IP=<ipv4>; otherwise detected via cloud instance metadata.
self_ip() {
  [ -z "${EGRESS_SELF_IP:-}" ] || { printf '%s\n' "$EGRESS_SELF_IP"; return 0; }
  command -v curl >/dev/null 2>&1 || return 1
  ip=$(curl -fsS -m 2 -H 'Authorization: Bearer Oracle' \
      http://169.254.169.254/opc/v2/instance/publicip/ 2>/dev/null ||
    curl -fsS -m 2 http://169.254.169.254/opc/v2/instance/publicip/ 2>/dev/null || true)
  ip=$(printf '%s' "$ip" | tr -d ' \t\n')
  case $ip in
    [0-9]*.[0-9]*.[0-9]*.[0-9]*) printf '%s\n' "$ip" ;;
    *) return 1 ;;
  esac
}

# Destinations for allow/revoke/allow-domain: an explicit CIDR, a bare IPv4
# (normalised to /32), or a hostname resolved NOW to every A record — iptables
# matches addresses, not names. Prints one CIDR per line; nothing if unresolvable.
resolve_dest() {
  case $1 in
    */*) printf '%s\n' "$1" ;;
    *[!0-9.]*)
      for a in $(getent ahostsv4 "$1" 2>/dev/null | awk '{print $1}' | sort -u); do
        printf '%s\n' "$a/32"
      done
      ;;
    *) printf '%s\n' "$1/32" ;;
  esac
}

ids_for() { # service name or exact container name -> running container ids
  ids=$(docker ps -q --filter "label=com.docker.compose.service=$1" 2>/dev/null || true)
  [ -n "$ids" ] || ids=$(docker ps -q --filter "name=^/$1$" 2>/dev/null || true)
  printf '%s\n' "$ids"
}

ips_for() {
  for id in $(ids_for "$1"); do
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' "$id" 2>/dev/null |
      awk '{print $1}'
  done
}

# Remove our rebuildable rules (time-boxed exceptions are kept), then the chain.
# Match covers egress-restricted, egress-blocked, egress-allow-domain and
# egress-block-domain; egress-exception (time-boxed) is deliberately excluded.
remove() {
  nums=$(iptables -S "$CHAIN" 2>/dev/null | grep -En -- "--comment egress-(restricted|blocked|allow-domain|block-domain)" |
    cut -d: -f1 || true)
  for n in $(printf '%s\n' "$nums" | sort -rn); do
    iptables -D "$CHAIN" $((n - 1))
  done
  iptables -F "$AUX" 2>/dev/null || true
  iptables -X "$AUX" 2>/dev/null || true
}

set_ready() { command -v ipset >/dev/null 2>&1 && ipset list "$SET" -n >/dev/null 2>&1; }

apply() {
  remove
  exc=$(iptables -S "$CHAIN" 2>/dev/null | grep -c -- "--comment egress-exception" || true)
  pos=$((exc + 1)) # standing exceptions stay above everything we install

  ready=0
  if set_ready; then
    ready=1
  else
    warn "global block inactive (need 'ipset' and a populated set) — run: $0 blocked-refresh"
  fi

  restricted_ips=""; ok_ips=""; domain_lines=""; block_lines=""
  while read -r svc pol arg; do
    [ -n "$svc" ] || continue
    if [ "$pol" = "allow-domain" ]; then
      domain_lines="$domain_lines$svc $arg
"
      continue
    fi
    if [ "$pol" = "block-domain" ]; then
      block_lines="$block_lines$svc $arg
"
      continue
    fi
    ips=$(ips_for "$svc")
    [ -n "$ips" ] || warn "$svc: not running, no rules applied"
    case $pol in
      restricted) restricted_ips="$restricted_ips $ips" ;;
      allow-blocked) ok_ips="$ok_ips $ips" ;;
      internet) : ;; # default, listed only for clarity
      *) warn "$svc: unknown policy '$pol'" ;;
    esac
  done <<EOF
$(Policies)
EOF

  # Insert bottom-up at $pos: the last insert lands on top.
  if [ "$ready" -eq 1 ]; then
    iptables -I "$CHAIN" "$pos" -m set --match-set "$SET" dst -m comment --comment egress-blocked -j DROP
    iptables -I "$CHAIN" "$pos" -m set --match-set "$SET" dst -m comment --comment egress-blocked \
      $LIMIT -j LOG --log-prefix "egress-blocked: " --log-level 4
  fi
  if [ -n "$restricted_ips" ]; then
    iptables -N "$AUX"
    if sip=$(self_ip); then
      iptables -A "$AUX" -d "$sip/32" -m comment --comment egress-restricted-self -j RETURN
    else
      warn "host public IP unknown — restricted services cannot hairpin to it (set EGRESS_SELF_IP=<ipv4>)"
    fi
    iptables -A "$AUX" -d 10.0.0.0/8 -j RETURN
    iptables -A "$AUX" -d 172.16.0.0/12 -j RETURN
    iptables -A "$AUX" -d 192.168.0.0/16 -j RETURN
    iptables -A "$AUX" -m comment --comment egress-restricted $LIMIT \
      -j LOG --log-prefix "egress-restricted: " --log-level 4
    iptables -A "$AUX" -m comment --comment egress-restricted -j DROP
    for ip in $restricted_ips; do
      iptables -I "$CHAIN" "$pos" -s "$ip" -m comment --comment egress-restricted -j "$AUX"
    done
  fi
  if [ "$ready" -eq 1 ]; then
    for ip in $ok_ips; do
      iptables -I "$CHAIN" "$pos" -s "$ip" -m set --match-set "$SET" dst \
        -m comment --comment egress-blocked-ok -j ACCEPT
    done
  fi
  # Standing allow-domain exceptions: rebuilt at the top of the chain on every
  # apply, keyed to the service's current address, so named dependencies stay
  # reachable even while a restricted jump is stale or misattributed.
  while read -r svc dom; do
    [ -n "$dom" ] || continue
    ips=$(ips_for "$svc")
    if [ -z "$ips" ]; then
      warn "$svc: allow-domain '$dom' skipped (not running)"
      continue
    fi
    dests=$(resolve_dest "$dom")
    if [ -z "$dests" ]; then
      warn "$svc: allow-domain '$dom' cannot resolve, skipped"
      continue
    fi
    for ip in $ips; do
      for d in $dests; do
        iptables -I "$CHAIN" 1 -s "$ip" -d "$d" -m comment --comment egress-allow-domain -j ACCEPT
      done
    done
  done <<EOF
$domain_lines
EOF
  # Domain blocks: resolved at apply and installed at the very top, so a block
  # always wins over a standing allow for the same address. iptables matches
  # addresses, not names — see the limits in EGRESS-CONTROLS.
  while read -r svc dom; do
    [ -n "$dom" ] || continue
    ips=$(ips_for "$svc")
    if [ -z "$ips" ]; then
      warn "$svc: block-domain '$dom' skipped (not running)"
      continue
    fi
    dests=$(resolve_dest "$dom")
    if [ -z "$dests" ]; then
      warn "$svc: block-domain '$dom' cannot resolve, skipped"
      continue
    fi
    for ip in $ips; do
      for d in $dests; do
        iptables -I "$CHAIN" 1 -s "$ip" -d "$d" -m comment --comment egress-block-domain -j DROP
      done
    done
  done <<EOF
$block_lines
EOF
  echo "egress: applied — restricted:[${restricted_ips# }] blocked-ok:[${ok_ips# }] set=$ready"
}

snapshot() { # "service=ip,ip" per policy line — cheap change detection for watch
  while read -r svc pol; do
    [ -n "$svc" ] || continue
    printf '%s=%s\n' "$svc" "$(ips_for "$svc" | tr '\n' ',')"
  done <<EOF
$(Policies)
EOF
}

watch() {
  blocked_refresh || true
  apply
  last=$(snapshot)
  echo "egress: watching (re-applies when a listed container's address changes)"
  while :; do
    docker events --filter event=create --filter event=start --filter event=die \
      --filter event=stop --filter event=destroy --format '{{.Action}}' 2>/dev/null |
      while read -r _ev; do
        sleep 1
        now=$(snapshot)
        if [ "$now" != "$last" ]; then
          apply
          last=$now
        fi
      done
    sleep 5 # events stream ended (daemon restart) — re-apply and re-attach
  done
}

status() {
  echo "-- policies --"
  Policies || true
  echo "-- host public IP --"
  self_ip || echo "(unknown — set EGRESS_SELF_IP=<ipv4>)"
  echo "-- addresses --"
  while read -r svc pol; do
    [ -n "$svc" ] || continue
    printf '%-24s %-18s %s\n' "$svc" "$pol" "$(ips_for "$svc" | tr '\n' ' ')"
  done <<EOF
$(Policies)
EOF
  echo "-- $CHAIN --"
  iptables -S "$CHAIN" | grep -E -- "--comment egress-" || echo "no egress rules installed"
  echo "-- blocked set --"
  ipset list "$SET" -t 2>/dev/null | sed -n '1p;3p' || echo "set absent"
  echo "-- counters --"
  iptables -nvL "$CHAIN" --line-numbers
  iptables -nvL "$AUX" --line-numbers 2>/dev/null || echo "(helper chain absent)"
}

allow() {
  [ $# -eq 2 ] || die "usage: allow <service> <cidr|ipv4|hostname>"
  ip=$(ips_for "$1" | head -1)
  [ -n "$ip" ] || die "$1 is not running"
  dests=$(resolve_dest "$2")
  [ -n "$dests" ] || die "cannot resolve '$2'"
  for d in $dests; do
    iptables -I "$CHAIN" 1 -s "$ip" -d "$d" -m comment --comment egress-exception -j ACCEPT
  done
  echo "egress: exception $1 ($ip) -> $(printf '%s ' $dests)granted; record it, revoke with: $0 revoke $1 $2"
}

revoke() {
  [ $# -eq 2 ] || die "usage: revoke <service> <cidr|ipv4|hostname>"
  dests=$(resolve_dest "$2")
  [ -n "$dests" ] || die "cannot resolve '$2'"
  nums=$(for ip in $(ips_for "$1"); do
    for d in $dests; do
      iptables -S "$CHAIN" | awk -v s="$ip" -v d="$d" '
        /--comment egress-exception/ &&
        (index($0, " -s " s " ") || index($0, " -s " s "/")) &&
        index($0, " -d " d " ") { print NR }'
    done
  done | sort -rn)
  [ -n "$nums" ] || die "no exception for $1 -> $2"
  for n in $nums; do
    iptables -D "$CHAIN" $((n - 1))
  done
  echo "egress: exception for $1 -> $2 revoked"
}

# Remove every egress rule we own — restricted jumps, the global block and
# time-boxed exceptions — leaving the chain as Docker created it.
remove_all() {
  nums=$(iptables -S "$CHAIN" 2>/dev/null | grep -En -- "--comment egress-" | cut -d: -f1 || true)
  for n in $(printf '%s\n' "$nums" | sort -rn); do
    iptables -D "$CHAIN" $((n - 1))
  done
  iptables -F "$AUX" 2>/dev/null || true
  iptables -X "$AUX" 2>/dev/null || true
  echo "egress: all rules removed (restricted, blocked, exceptions) — '$0 apply' reinstalls; stop the watch unit first if it is running"
}

blocked_refresh() {
  urls=$(feed_urls)
  [ -n "$urls" ] || {
    warn "EGRESS_BLOCK_URL not set — add it to .env (or export it) with the CIDR feed"
    return 1
  }
  command -v ipset >/dev/null 2>&1 || {
    warn "ipset not installed — install it (apt install ipset / dnf install ipset)"
    return 1
  }
  command -v python3 >/dev/null 2>&1 || {
    warn "python3 not installed — required to read the feed"
    return 1
  }
  # All feeds must land: a partial merge would silently drop a feed's ranges
  # and weaken the block, so any failure keeps the existing set intact.
  cidrs=$(mktemp)
  : >"$cidrs"
  for u in $urls; do
    if ! python3 - "$cidrs" "$u" <<'PY'
import json, sys, urllib.request
with urllib.request.urlopen(sys.argv[2], timeout=20) as r:
    data = json.load(r)
with open(sys.argv[1], "a") as out:
    for item in data.get("items", []):
        if "cidr" in item:
            out.write(item["cidr"] + "\n")
PY
    then
      rm -f "$cidrs"
      warn "fetch failed ($u) — existing set kept"
      return 1
    fi
  done
  if [ ! -s "$cidrs" ]; then
    rm -f "$cidrs"
    warn "empty range list — existing set kept"
    return 1
  fi
  ipset create "$SET-tmp" hash:net -exist
  ipset flush "$SET-tmp"
  while read -r c; do
    ipset add "$SET-tmp" "$c" -exist 2>/dev/null || true
  done <"$cidrs"
  rm -f "$cidrs"
  ipset create "$SET" hash:net -exist
  ipset swap "$SET-tmp" "$SET"
  ipset destroy "$SET-tmp"
  echo "egress: '$SET' refreshed — $(ipset list "$SET" -t | awk -F': ' '/Number of entries/ {print $2}') CIDRs"
}

# Offline check: stub docker/iptables/ipset/python3, assert the rules produced.
selftest() {
  t=$(mktemp -d)
  trap 'rm -rf "$t"' EXIT
  mkdir "$t/bin"
  printf '%s\n' '#!/bin/sh' \
    'case "$*" in' \
    '  *com.docker.compose.service=webappconf*) echo c1 ;;' \
    '  *com.docker.compose.service=otherapp*) echo c2 ;;' \
    '  *inspect*c1*) echo "10.89.1.42 " ;;' \
    '  *inspect*c2*) echo "10.89.1.43 " ;;' \
    'esac' 'exit 0' >"$t/bin/docker"
  printf '%s\n' '#!/bin/sh' 'echo "$@" >>"$STUB_LOG"' \
    'if [ "$1" = "-S" ]; then cat "$STUB_RULES"; exit 0; fi' 'exit 0' >"$t/bin/iptables"
  printf '%s\n' '#!/bin/sh' 'echo "ipset $@" >>"$STUB_LOG"' \
    '[ "$1" = "list" ] && [ -n "${STUB_SET_ABSENT:-}" ] && exit 1' 'exit 0' >"$t/bin/ipset"
  printf '%s\n' '#!/bin/sh' 'echo "python3 $@" >>"$STUB_LOG"' \
    'printf "%s\n" 192.0.2.0/24 198.51.100.0/24 >>"$2"' 'exit 0' >"$t/bin/python3"
  printf '%s\n' '#!/bin/sh' 'exit 1' >"$t/bin/curl" # instance metadata unreachable offline
  printf '%s\n' '#!/bin/sh' \
    'case "$*" in' \
    '  *login.example.com*) printf "%s\n" "203.0.113.7 STREAM" "203.0.113.8 STREAM" ;;' \
    'esac' 'exit 0' >"$t/bin/getent"
  chmod +x "$t/bin/docker" "$t/bin/iptables" "$t/bin/ipset" "$t/bin/python3" "$t/bin/curl" "$t/bin/getent"
  printf '%s\n' 'webappconf restricted' 'otherapp allow-blocked' >"$t/policies"
  PATH="$t/bin:$PATH" STUB_LOG="$t/log" STUB_RULES="$t/rules" EGRESS_POLICIES="$t/policies" EGRESS_NOSUDO=1 \
    EGRESS_SELF_IP=198.51.100.7 EGRESS_BLOCK_URL=https://feed.example/ranges.json \
    EGRESS_ENV_FILE=$t/no-such-env
  export PATH STUB_LOG STUB_RULES EGRESS_POLICIES EGRESS_NOSUDO EGRESS_SELF_IP EGRESS_BLOCK_URL
  export EGRESS_ENV_FILE
  fail=0

  : >"$STUB_LOG"
  printf -- '-N DOCKER-USER\n-A DOCKER-USER -s 10.89.1.99 -d 203.0.113.9/32 -m comment --comment egress-exception -j ACCEPT\n-A DOCKER-USER -j RETURN\n' >"$STUB_RULES"
  sh "$0" apply >/dev/null 2>&1
  grep -Fqx -- "-I DOCKER-USER 2 -s 10.89.1.42 -m comment --comment egress-restricted -j EGRESS_RESTRICTED" "$STUB_LOG" &&
    grep -Fqx -- "-A EGRESS_RESTRICTED -d 10.0.0.0/8 -j RETURN" "$STUB_LOG" &&
    grep -Fq -- "-A EGRESS_RESTRICTED -m comment --comment egress-restricted -j DROP" "$STUB_LOG" &&
    echo "ok: restricted policy installs jump + helper chain" || { echo "FAIL: restricted"; cat "$STUB_LOG"; fail=1; }

  grep -Fqx -- "-A EGRESS_RESTRICTED -d 198.51.100.7/32 -m comment --comment egress-restricted-self -j RETURN" "$STUB_LOG" &&
    echo "ok: host public IP allowed for restricted hairpin" || { echo "FAIL: self ip"; cat "$STUB_LOG"; fail=1; }

  grep -Fq -- "-m set --match-set blocked dst -m comment --comment egress-blocked -j DROP" "$STUB_LOG" &&
    grep -Fq -- "-j LOG --log-prefix egress-blocked: " "$STUB_LOG" &&
    echo "ok: global block DROP + LOG installed" || { echo "FAIL: blocked"; fail=1; }

  grep -Fq -- "-s 10.89.1.43 -m set --match-set blocked dst -m comment --comment egress-blocked-ok -j ACCEPT" "$STUB_LOG" &&
    echo "ok: allow-blocked policy installed" || { echo "FAIL: allow-blocked"; fail=1; }

  grep -q '^-D' "$STUB_LOG" && { echo "FAIL: exception rule was deleted"; fail=1; } ||
    echo "ok: standing exception preserved across apply"

  : >"$STUB_LOG"
  sh "$0" blocked-refresh >/dev/null 2>&1
  grep -Fq -- "ipset add blocked-tmp 192.0.2.0/24 -exist" "$STUB_LOG" &&
    grep -Fq -- "ipset swap blocked-tmp blocked" "$STUB_LOG" &&
    echo "ok: refresh loads CIDRs and swaps the set atomically" || { echo "FAIL: refresh"; cat "$STUB_LOG"; fail=1; }

  : >"$STUB_LOG"
  EGRESS_BLOCK_URL="https://feed.example/a https://feed.example/b" \
    sh "$0" blocked-refresh >/dev/null 2>&1
  [ "$(grep -c '^python3' "$STUB_LOG")" -eq 2 ] &&
    grep -Fq -- "ipset swap blocked-tmp blocked" "$STUB_LOG" &&
    echo "ok: every listed feed is fetched into one set" ||
    { echo "FAIL: multiple feeds"; cat "$STUB_LOG"; fail=1; }

  : >"$STUB_LOG"
  EGRESS_BLOCK_URL= sh "$0" blocked-refresh >/dev/null 2>"$t/err" || true
  grep -q 'EGRESS_BLOCK_URL not set' "$t/err" && [ ! -s "$STUB_LOG" ] &&
    echo "ok: refresh refuses to run without EGRESS_BLOCK_URL" ||
    { echo "FAIL: missing feed URL"; cat "$t/err" "$STUB_LOG"; fail=1; }

  printf '%s\n' 'EGRESS_BLOCK_URL="https://feed.example/ranges.json"' >"$t/feed.env"
  : >"$STUB_LOG"
  EGRESS_BLOCK_URL= EGRESS_ENV_FILE="$t/feed.env" sh "$0" blocked-refresh >/dev/null 2>&1
  grep -Fq -- "ipset swap blocked-tmp blocked" "$STUB_LOG" &&
    echo "ok: refresh reads EGRESS_BLOCK_URL from .env when unset" ||
    { echo "FAIL: .env fallback"; cat "$STUB_LOG"; fail=1; }

  : >"$STUB_LOG"
  STUB_SET_ABSENT=1 sh "$0" apply >/dev/null 2>&1
  grep -q -- "--match-set" "$STUB_LOG" && { echo "FAIL: set rules without a set"; fail=1; } ||
    echo "ok: no set rules when the set is absent (warning only)"

  : >"$STUB_LOG"
  EGRESS_SELF_IP= sh "$0" apply >/dev/null 2>"$t/err"
  if grep -q 'egress-restricted-self' "$STUB_LOG"; then
    echo "FAIL: self rule when the host IP is unknown"; fail=1
  elif grep -q 'host public IP unknown' "$t/err"; then
    echo "ok: no self rule and a warning when the host IP is unknown"
  else
    echo "FAIL: unknown-IP warning missing"; cat "$STUB_LOG" "$t/err"; fail=1
  fi

  : >"$STUB_LOG"
  printf -- '-N DOCKER-USER\n-A DOCKER-USER -s 10.89.1.99 -d 203.0.113.9/32 -m comment --comment egress-exception -j ACCEPT\n-A DOCKER-USER -s 10.89.1.42 -m comment --comment egress-restricted -j EGRESS_RESTRICTED\n-A DOCKER-USER -j RETURN\n' >"$STUB_RULES"
  sh "$0" remove >/dev/null 2>&1
  [ "$(grep -c -- '^-D' "$STUB_LOG")" -eq 2 ] &&
    grep -Fq -- "-D DOCKER-USER 1" "$STUB_LOG" &&
    grep -Fq -- "-D DOCKER-USER 2" "$STUB_LOG" &&
    grep -Fq -- "-F EGRESS_RESTRICTED" "$STUB_LOG" &&
    grep -Fq -- "-X EGRESS_RESTRICTED" "$STUB_LOG" &&
    echo "ok: remove strips exceptions, restricted jumps and the helper chain" ||
    { echo "FAIL: remove"; cat "$STUB_LOG"; fail=1; }

  : >"$STUB_LOG"
  sh "$0" allow webappconf login.example.com >/dev/null 2>&1
  grep -Fq -- "-I DOCKER-USER 1 -s 10.89.1.42 -d 203.0.113.7/32 -m comment --comment egress-exception -j ACCEPT" "$STUB_LOG" &&
    grep -Fq -- "-I DOCKER-USER 1 -s 10.89.1.42 -d 203.0.113.8/32 -m comment --comment egress-exception -j ACCEPT" "$STUB_LOG" &&
    echo "ok: allow accepts a hostname (one rule per A record)" || { echo "FAIL: allow hostname"; cat "$STUB_LOG"; fail=1; }

  : >"$STUB_LOG"
  printf -- '-N DOCKER-USER\n-A DOCKER-USER -s 10.89.1.42 -d 203.0.113.7/32 -m comment --comment egress-exception -j ACCEPT\n-A DOCKER-USER -s 10.89.1.42 -d 203.0.113.8/32 -m comment --comment egress-exception -j ACCEPT\n-A DOCKER-USER -j RETURN\n' >"$STUB_RULES"
  sh "$0" revoke webappconf login.example.com >/dev/null 2>&1
  [ "$(grep -c -- '^-D' "$STUB_LOG")" -eq 2 ] &&
    grep -Fq -- "-D DOCKER-USER 1" "$STUB_LOG" &&
    grep -Fq -- "-D DOCKER-USER 2" "$STUB_LOG" &&
    echo "ok: revoke re-resolves the hostname and strips every rule" || { echo "FAIL: revoke hostname"; cat "$STUB_LOG"; fail=1; }

  : >"$STUB_LOG"
  printf '%s\n' 'webappconf restricted' 'webappconf allow-domain login.example.com' 'otherapp allow-blocked' >"$t/policies2"
  printf -- '-N DOCKER-USER\n-A DOCKER-USER -s 10.89.1.42 -d 198.51.100.99/32 -m comment --comment egress-allow-domain -j ACCEPT\n-A DOCKER-USER -j RETURN\n' >"$STUB_RULES"
  EGRESS_POLICIES="$t/policies2" sh "$0" apply >/dev/null 2>&1
  grep -Fq -- "-D DOCKER-USER 1" "$STUB_LOG" &&
    grep -Fqx -- "-I DOCKER-USER 1 -s 10.89.1.42 -d 203.0.113.7/32 -m comment --comment egress-allow-domain -j ACCEPT" "$STUB_LOG" &&
    grep -Fqx -- "-I DOCKER-USER 1 -s 10.89.1.42 -d 203.0.113.8/32 -m comment --comment egress-allow-domain -j ACCEPT" "$STUB_LOG" &&
    echo "ok: allow-domain rebuilt as a top-of-chain standing exception" || { echo "FAIL: allow-domain"; cat "$STUB_LOG"; fail=1; }

  printf '%s\n' 'otherapp internet' 'otherapp block-domain login.example.com' >"$t/policies3"
  printf -- '-N DOCKER-USER\n-A DOCKER-USER -j RETURN\n' >"$STUB_RULES"
  EGRESS_POLICIES="$t/policies3" sh "$0" apply >/dev/null 2>&1
  grep -Fqx -- "-I DOCKER-USER 1 -s 10.89.1.43 -d 203.0.113.7/32 -m comment --comment egress-block-domain -j DROP" "$STUB_LOG" &&
    grep -Fqx -- "-I DOCKER-USER 1 -s 10.89.1.43 -d 203.0.113.8/32 -m comment --comment egress-block-domain -j DROP" "$STUB_LOG" &&
    echo "ok: block-domain drops every address of the name" ||
    { echo "FAIL: block-domain"; cat "$STUB_LOG"; fail=1; }

  printf -- '-N DOCKER-USER\n-A DOCKER-USER -s 10.89.1.43 -d 203.0.113.7/32 -m comment --comment egress-block-domain -j DROP\n-A DOCKER-USER -j RETURN\n' >"$STUB_RULES"
  : >"$STUB_LOG"
  sh "$0" remove >/dev/null 2>&1
  [ "$(grep -c -- '^-D' "$STUB_LOG")" -eq 1 ] &&
    grep -Fq -- "-D DOCKER-USER 1" "$STUB_LOG" &&
    echo "ok: remove strips block-domain rules" ||
    { echo "FAIL: remove block-domain"; cat "$STUB_LOG"; fail=1; }

  # Policy file location: ${APPS_DATA}/egress-policies.conf when it exists,
  # otherwise the repository default. EGRESS_POLICIES still wins when set.
  mkdir -p "$t/appdata" "$t/empty"
  printf '%s\n' 'otherapp restricted' >"$t/appdata/egress-policies.conf"
  printf 'APPS_DATA=%s\n' "$t/appdata" >"$t/apps.env"
  printf 'APPS_DATA=%s\n' "$t/empty" >"$t/empty.env"
  printf -- '-N DOCKER-USER\n-A DOCKER-USER -j RETURN\n' >"$STUB_RULES"
  r1= r2=
  : >"$STUB_LOG"
  EGRESS_POLICIES= EGRESS_ENV_FILE="$t/apps.env" sh "$0" apply >/dev/null 2>&1
  grep -Fqx -- "-I DOCKER-USER 1 -s 10.89.1.43 -m comment --comment egress-restricted -j EGRESS_RESTRICTED" "$STUB_LOG" || r1=1
  : >"$STUB_LOG"
  EGRESS_POLICIES= EGRESS_ENV_FILE="$t/empty.env" sh "$0" apply >/dev/null 2>&1
  grep -Fqx -- "-I DOCKER-USER 1 -s 10.89.1.42 -m comment --comment egress-restricted -j EGRESS_RESTRICTED" "$STUB_LOG" || r2=1
  [ -z "$r1$r2" ] && echo "ok: policy file read from APPS_DATA, else the repository default" ||
    { echo "FAIL: policy file resolution (r1=$r1 r2=$r2)"; cat "$STUB_LOG"; fail=1; }

  exit "$fail"
}

case ${1:-apply} in
  apply) apply ;;
  watch) watch ;;
  status) status ;;
  allow) shift; allow "$@" ;;
  revoke) shift; revoke "$@" ;;
  remove) remove_all ;;
  blocked-refresh) blocked_refresh ;;
  selftest) selftest ;;
  *) die "unknown command: $1 (apply|watch|status|allow|revoke|remove|blocked-refresh|selftest)" ;;
esac

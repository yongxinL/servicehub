"""
smartrouter.py — LiteLLM pre-call routing hook for hermes-agent

All requests arrive as model="hermes".  This hook examines the
message content and rewrites data["model"] to either:

  hephaestus — local Gemma-4-4B (128K ctx, private, low-latency)
  prometheus  — MiniMax 2.7 (200K ctx, logic-heavy, long-form)

Decision order (first match wins):
  1. Explicit tag        → honours user intent unconditionally
       [cloud] / [c]     → prometheus
       [edge] / [e]      → hephaestus
  2. Health check       → hephaestus unhealthy → prometheus (auto-failover)
  3. Privacy keywords   → hephaestus  (data never leaves the host)
  4. Input > 50K tokens → prometheus  (large-scale document workload)
  5. Complexity keywords → prometheus (formal / logic-heavy task)
  6. Default             → hephaestus

Explicit tags are stripped from the message before forwarding so the
model never sees the routing instruction.
"""
import os as _os

# Model names — configurable via env vars to match config.default.yaml
_SMARTROUTER_MODEL = _os.environ.get("HERMES_MODEL", "hermes")
_EDGEAI_MODEL = _os.environ.get("HEPHAESTUS_MODEL", "hephaestus")
_CLOUDAI_MODEL = _os.environ.get("PROMETHEUS_MODEL", "prometheus")

# Routing decision tags in logs
_ROUTER_TAG = _SMARTROUTER_MODEL

import re
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone
from typing import Any

from litellm.integrations.custom_logger import CustomLogger


def _log(msg: str) -> None:
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    print(f"{ts} [router] {msg}", flush=True)

# Explicit routing tags typed by the user at the start of a message.
# The tag (and any surrounding whitespace / punctuation) is stripped before
# the message is forwarded so the model never sees the routing instruction.
#   [cloud] or [c]  → prometheus
#   [edge] or [e]   → hephaestus
_TAG_CLOUD = re.compile(r"^\s*\[\s*(?:cloud|c)\s*\]\s*", re.IGNORECASE)
_TAG_EDGE = re.compile(r"^\s*\[\s*(?:edge|e)\s*\]\s*", re.IGNORECASE)

# Approx chars-per-token for English prose; used for fast estimation.
_CHARS_PER_TOKEN = 4
# Requests larger than this are treated as large-document workloads → cloud.
# 50K tokens ≈ 200 pages of text.  context_window_fallbacks in config.yaml
# provides a second safety net at the model's hard limit (120K tokens).
_CLOUD_TOKEN_THRESHOLD = 50_000

# Hephaestus (edge LLM) health check — URL configurable via LITEM_EDGE_HEALTH_URL env var
_EDGE_HEALTH_URL = _os.environ.get("LITEM_EDGE_HEALTH_URL", "http://agsvcchatllm:12326/health")
_EDGE_HEALTH_TIMEOUT = int(_os.environ.get("LITEM_EDGE_HEALTH_TIMEOUT", "3"))  # seconds
# Cache health for this many seconds to avoid hammering the endpoint
_HEALTH_CACHE_TTL = int(_os.environ.get("LITEM_EDGE_HEALTH_CACHE_TTL", "30"))

# ---------------------------------------------------------------------------
# Privacy / sensitivity — always stay local regardless of other signals.
# These patterns cover personal records that must not leave the host.
# ---------------------------------------------------------------------------
_FAST_OVERRIDE = re.compile(
    r"(?:"
    r"confidential"
    r"|(?:sensitive|private|personal)\s+(?:file|data|record|info(?:rmation)?|document)"
    r"|\bIEP\b"
    r"|student\s+record"
    r"|tax\s+return"
    r"|bank\s+statement"
    r"|family\s+calendar"
    r"|medical\s+record"
    r"|health\s+record"
    r"|\bsalar(?:y|ies)\b"
    r"|\bpassport\b"
    r")",
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Complexity / formality / scale — escalate to cloud.
# Groups mirror the user's stated routing guidelines.
# ---------------------------------------------------------------------------
_CLOUD_SIGNALS = re.compile(
    r"(?:"
    # ── Engineering & architecture ──────────────────────────────────────────
    r"system\s+architecture"
    r"|cloud\s+architecture"
    r"|database\s+schema"
    r"|infrastructure\s+design"
    r"|high.level\s+design"
    # ── Root-cause & log correlation ────────────────────────────────────────
    r"|root\s+cause"
    r"|post.?mortem"
    r"|correlat\w+\s+(?:log|trace|issue)"
    r"|multiple\s+(?:log|stack\s+trace)"
    r"|stack\s+traces"
    # ── Long-form writing ───────────────────────────────────────────────────
    r"|academic\s+essay"
    r"|argumentative\s+essay"
    r"|literature\s+review"
    r"|\bdissertation\b"
    r"|\bthesis\b"
    r"|formal\s+report"
    r"|long.form\s+report"
    r"|research\s+paper\s+(?:summar|analys)"
    # ── Education (full-scale / formal) ─────────────────────────────────────
    r"|curriculum\s+map"
    r"|full.year\s+(?:lesson|curriculum)"
    r"|annual\s+(?:lesson|curriculum)"
    r"|national\s+standard"
    r"|state\s+standard"
    r"|grant\s+(?:applic|proposal|writ)"
    r"|school\s+policy"
    # ── Professional documents ───────────────────────────────────────────────
    r"|stakeholder\s+(?:email|memo|report|communic)"
    r"|formal\s+(?:document|proposal|letter)"
    r"|policy\s+document"
    # ── Large-scale document work ────────────────────────────────────────────
    r"|500.?page"
    r"|multiple\s+pdf"
    r"|dozens\s+of\s+(?:pdf|doc|paper)"
    r"|research\s+archive"
    r"|(?:summar(?:iz|is)|analys)\w*\s+(?:the\s+)?textbook"
    # ── Logic-heavy subjects ─────────────────────────────────────────────────
    r"|legal\s+(?:analysis|brief|argument)"
    r"|law\s+(?:school|degree|subject|exam)"
    r"|philosophical\s+(?:argument|essay|analysis)"
    r"|formal\s+logic"
    # ── Certifications & standardised tests ─────────────────────────────────
    r"|\bCISSP\b"
    r"|AWS\s+(?:cert|exam)"
    r"|Azure\s+(?:cert|exam)"
    r"|certification\s+(?:exam|prep|study)"
    r"|standar[ds]i[sz]ed\s+test"
    r"|\bSAT\b|\bACT\b|\bGMAT\b|\bGRE\b"
    # ── Complex student tasks ─────────────────────────────────────────────────
    r"|Socratic\s+(?:tutor|debate|method)"
    r"|debate\s+prep"
    # ── Complex multi-step planning ───────────────────────────────────────────
    r"|overseas\s+(?:trip|holiday|travel|itiner)"
    r"|multi.week\s+(?:trip|travel)"
    r"|budget\s+spreadsheet"
    r"|travel\s+itiner"
    r")",
    re.IGNORECASE,
)


def _extract_text(messages: list) -> str:
    """Flatten all text content from a messages list into a single string."""
    parts: list[str] = []
    for m in messages:
        content = m.get("content", "")
        if isinstance(content, str):
            parts.append(content)
        elif isinstance(content, list):
            for block in content:
                if isinstance(block, dict) and block.get("type") == "text":
                    parts.append(block.get("text", ""))
    return " ".join(parts)


def _check_edge_health() -> bool:
    """
    Check if hephaestus (llama.cpp server) is reachable.
    Returns True if healthy, False if unreachable or error.
    Results are cached for _HEALTH_CACHE_TTL seconds.
    """
    now = time.time()
    # Use module-level cache for the health check result
    cached_result = getattr(_check_edge_health, "_cache", (None, None))
    if cached_result[0] is not None and (now - cached_result[1]) < _HEALTH_CACHE_TTL:
        return cached_result[0]

    healthy = False
    try:
        req = urllib.request.Request(
            _EDGE_HEALTH_URL,
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=_EDGE_HEALTH_TIMEOUT) as resp:
            healthy = resp.status == 200
    except (urllib.error.URLError, OSError, TimeoutError):
        pass

    # Cache the result
    _check_edge_health._cache = (healthy, now)
    return healthy


def _pop_explicit_tag(messages: list) -> str | None:
    """
    Scan the last user message for a leading [cloud/c] or [edge/e] tag.
    If found, strip the tag in-place and return _CLOUDAI_MODEL or _EDGEAI_MODEL.
    Returns None when no explicit tag is present.
    """
    for msg in reversed(messages):
        if msg.get("role") != "user":
            continue
        content = msg.get("content", "")
        if isinstance(content, str):
            if _TAG_CLOUD.match(content):
                msg["content"] = _TAG_CLOUD.sub("", content)
                return _CLOUDAI_MODEL
            if _TAG_EDGE.match(content):
                msg["content"] = _TAG_EDGE.sub("", content)
                return _EDGEAI_MODEL
        elif isinstance(content, list):
            # Multimodal: check first text block only
            for block in content:
                if isinstance(block, dict) and block.get("type") == "text":
                    text = block.get("text", "")
                    if _TAG_CLOUD.match(text):
                        block["text"] = _TAG_CLOUD.sub("", text)
                        return _CLOUDAI_MODEL
                    if _TAG_EDGE.match(text):
                        block["text"] = _TAG_EDGE.sub("", text)
                        return _EDGEAI_MODEL
                    break  # only inspect the first text block
        break  # only inspect the last user message
    return None


class SmartRouter(CustomLogger):
    """
    LiteLLM custom pre-call hook that rewrites model=_SMARTROUTER_MODEL to
    either _EDGEAI_MODEL (hephaestus) or _CLOUDAI_MODEL (prometheus) before
    deployment resolution.  Requests already targeting hephaestus or prometheus
    are passed through unchanged.
    """

    def __init__(self) -> None:
        super().__init__()
        # Tracks routing context keyed by litellm_call_id so the success/failure
        # log events can report the original decision even after a fallback
        # (fallback requests don't carry the original metadata dict).
        self._call_ctx: dict[str, dict] = {}

    async def async_pre_call_hook(
        self,
        user_api_key_dict: Any,
        cache: Any,
        data: dict,
        call_type: str,
    ) -> dict:
        # Strip provider prefix: Hermes sends "openai/hermes";
        # bare "hermes" also accepted for direct API callers.
        raw_model = data.get("model", "")
        model_name = raw_model.split("/", 1)[-1]
        if model_name != _SMARTROUTER_MODEL:
            return data

        messages = data.get("messages") or []

        # Rule 1: explicit tag — user intent overrides everything, including fallbacks
        explicit = _pop_explicit_tag(messages)
        if explicit:
            data["model"] = explicit
            # [local] / [cloud] must never silently fall back to the other tier —
            # the user stated a deliberate choice (e.g. privacy or testing).
            data["disable_fallbacks"] = True
            reason = "explicit_tag"
            _log(f"→ {explicit}  (reason: {reason}, fallbacks disabled)")
            self._store_ctx(data, explicit, reason)
            return data

        # Rule 2: hephaestus health check — route to prometheus if unreachable
        # (unless user explicitly chose local via tag, which is already handled above)
        if not _check_edge_health():
            _log("hephaestus unhealthy → routing to prometheus")
            data["model"] = _CLOUDAI_MODEL
            data["disable_fallbacks"] = True
            reason = "edge_unhealthy"
            self._store_ctx(data, _CLOUDAI_MODEL, reason)
            return data

        text = _extract_text(messages)
        approx_tokens = len(text) // _CHARS_PER_TOKEN

        # Rule 3: privacy — data must never leave the host, even if local is slow
        if _FAST_OVERRIDE.search(text):
            data["model"] = _EDGEAI_MODEL
            data["disable_fallbacks"] = True
            reason = "privacy_keyword"
        # Rule 4: large input — prometheus (large-document workload)
        elif approx_tokens > _CLOUD_TOKEN_THRESHOLD:
            data["model"] = _CLOUDAI_MODEL
            reason = f"large_input (~{approx_tokens:,} tokens)"
        # Rule 5: complexity keyword — prometheus
        elif _CLOUD_SIGNALS.search(text):
            data["model"] = _CLOUDAI_MODEL
            reason = "complexity_keyword"
        # Rule 6: default — hephaestus (fast, local, private, free)
        else:
            data["model"] = _EDGEAI_MODEL
            reason = "default"

        _log(f"→ {data['model']}  (reason: {reason})")
        self._store_ctx(data, data["model"], reason)
        return data

    def _store_ctx(self, data: dict, model: str, reason: str) -> None:
        call_id = data.get("litellm_call_id") or id(data)
        self._call_ctx[call_id] = {"model": model, "reason": reason, "t0": time.monotonic()}

    def _pop_ctx(self, kwargs: dict) -> dict:
        call_id = kwargs.get("litellm_call_id") or kwargs.get("id")
        return self._call_ctx.pop(call_id, {}) if call_id else {}

    async def async_log_success_event(self, kwargs: dict, response_obj: Any, start_time: Any, end_time: Any) -> None:
        ctx = self._pop_ctx(kwargs)
        model = kwargs.get("model") or "unknown"
        reason = ctx.get("reason", "n/a")
        elapsed = f"{time.monotonic() - ctx['t0']:.1f}s" if "t0" in ctx else "n/a"
        routed_to = ctx.get("model", "n/a")
        if model != routed_to and routed_to != "n/a":
            _log(f"response from {model}  (routed: {reason} → FALLBACK from {routed_to}, total: {elapsed})")
        else:
            _log(f"response from {model}  (routed: {reason}, total: {elapsed})")

    async def async_log_failure_event(self, kwargs: dict, response_obj: Any, start_time: Any, end_time: Any) -> None:
        self._pop_ctx(kwargs)
        model = kwargs.get("model") or "unknown"
        error = kwargs.get("exception", "unknown error")
        _log(f"FAILED on {model}: {error}")


# Pre-instantiated singleton — config.yaml must reference this attribute,
# not the class.  LiteLLM's get_instance_fn returns getattr(module, name)
# as-is; pointing it at a class gives an uninstantiated class, not an instance.
smart_router_callback = SmartRouter()

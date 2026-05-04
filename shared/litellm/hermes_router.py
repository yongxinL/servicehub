"""
hermes_router.py — LiteLLM pre-call routing hook for hermes-agent

All requests arrive as model="broker".  This hook examines the
message content and rewrites data["model"] to either:

  edge   — local Gemma-4-4B (128K ctx, private, low-latency)
  remote  — MiniMax 2.7 (200K ctx, logic-heavy, long-form)

Decision order (first match wins):
  1. Explicit tag        → honours user intent unconditionally
       [cloud] / [c]     → remote
       [local] / [l]     → edge
  2. Privacy keywords   → edge  (data never leaves the host)
  3. Input > 50K tokens → remote (large-scale document workload)
  4. Complexity keywords → remote (formal / logic-heavy task)
  5. Default             → edge

Explicit tags are stripped from the message before forwarding so the
model never sees the routing instruction.
"""
import re
import time
from datetime import datetime, timezone
from typing import Any

from litellm.integrations.custom_logger import CustomLogger


def _log(msg: str) -> None:
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    print(f"{ts} [broker] {msg}", flush=True)

# Explicit routing tags typed by the user at the start of a message.
# The tag (and any surrounding whitespace / punctuation) is stripped before
# the message is forwarded so the model never sees the routing instruction.
#   [cloud] or [c]  → remote
#   [local] or [l]  → edge
_TAG_CLOUD = re.compile(r"^\s*\[\s*(?:cloud|c)\s*\]\s*", re.IGNORECASE)
_TAG_LOCAL = re.compile(r"^\s*\[\s*(?:local|l)\s*\]\s*", re.IGNORECASE)

# Approx chars-per-token for English prose; used for fast estimation.
_CHARS_PER_TOKEN = 4
# Requests larger than this are treated as large-document workloads → cloud.
# 50K tokens ≈ 200 pages of text.  context_window_fallbacks in config.yaml
# provides a second safety net at the model's hard limit (120K tokens).
_CLOUD_TOKEN_THRESHOLD = 50_000

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


def _pop_explicit_tag(messages: list) -> str | None:
    """
    Scan the last user message for a leading [cloud/c] or [local/l] tag.
    If found, strip the tag in-place and return "remote" or "edge".
    Returns None when no explicit tag is present.
    """
    for msg in reversed(messages):
        if msg.get("role") != "user":
            continue
        content = msg.get("content", "")
        if isinstance(content, str):
            if _TAG_CLOUD.match(content):
                msg["content"] = _TAG_CLOUD.sub("", content)
                return "remote"
            if _TAG_LOCAL.match(content):
                msg["content"] = _TAG_LOCAL.sub("", content)
                return "edge"
        elif isinstance(content, list):
            # Multimodal: check first text block only
            for block in content:
                if isinstance(block, dict) and block.get("type") == "text":
                    text = block.get("text", "")
                    if _TAG_CLOUD.match(text):
                        block["text"] = _TAG_CLOUD.sub("", text)
                        return "remote"
                    if _TAG_LOCAL.match(text):
                        block["text"] = _TAG_LOCAL.sub("", text)
                        return "edge"
                    break  # only inspect the first text block
        break  # only inspect the last user message
    return None


class HermesRouter(CustomLogger):
    """
    LiteLLM custom pre-call hook that rewrites model="broker" to
    either "edge" or "remote" before deployment resolution.
    Requests that already target edge or remote are passed through.
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
        # Strip provider prefix: Hermes sends "openai/broker";
        # bare "broker" also accepted for direct API callers.
        raw_model = data.get("model", "")
        model_name = raw_model.split("/", 1)[-1]  # "openai/broker" → "broker"
        if model_name != "broker":
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

        text = _extract_text(messages)
        approx_tokens = len(text) // _CHARS_PER_TOKEN

        # Rule 2: privacy — data must never leave the host, even if local is slow
        if _FAST_OVERRIDE.search(text):
            data["model"] = "edge"
            data["disable_fallbacks"] = True
            reason = "privacy_keyword"
        # Rule 3: large input — cloud (large-document workload)
        elif approx_tokens > _CLOUD_TOKEN_THRESHOLD:
            data["model"] = "remote"
            reason = f"large_input (~{approx_tokens:,} tokens)"
        # Rule 4: complexity keyword — cloud
        elif _CLOUD_SIGNALS.search(text):
            data["model"] = "remote"
            reason = "complexity_keyword"
        # Rule 5: default — fast (local, private, free)
        else:
            data["model"] = "edge"
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
hermes_router_callback = HermesRouter()

"""
hermes_router.py — LiteLLM pre-call routing hook for hermes-agent

All requests arrive as model="hermes-router".  This hook examines the
message content and rewrites data["model"] to either:

  llm-fast   — local Gemma-4-4B (128K ctx, private, low-latency)
  llm-cloud  — MiniMax 2.7 (200K ctx, logic-heavy, long-form)

Decision order (first match wins):
  1. Explicit tag        → honours user intent unconditionally
       [cloud] / [c]     → llm-cloud
       [local] / [l]     → llm-fast
  2. Privacy keywords   → llm-fast  (data never leaves the host)
  3. Input > 50K tokens → llm-cloud (large-scale document workload)
  4. Complexity keywords → llm-cloud (formal / logic-heavy task)
  5. Default             → llm-fast

Explicit tags are stripped from the message before forwarding so the
model never sees the routing instruction.
"""
import re
from typing import Any

from litellm.integrations.custom_logger import CustomLogger

# Explicit routing tags typed by the user at the start of a message.
# The tag (and any surrounding whitespace / punctuation) is stripped before
# the message is forwarded so the model never sees the routing instruction.
#   [cloud] or [c]  → llm-cloud
#   [local] or [l]  → llm-fast
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
    If found, strip the tag in-place and return "llm-cloud" or "llm-fast".
    Returns None when no explicit tag is present.
    """
    for msg in reversed(messages):
        if msg.get("role") != "user":
            continue
        content = msg.get("content", "")
        if isinstance(content, str):
            if _TAG_CLOUD.match(content):
                msg["content"] = _TAG_CLOUD.sub("", content)
                return "llm-cloud"
            if _TAG_LOCAL.match(content):
                msg["content"] = _TAG_LOCAL.sub("", content)
                return "llm-fast"
        elif isinstance(content, list):
            # Multimodal: check first text block only
            for block in content:
                if isinstance(block, dict) and block.get("type") == "text":
                    text = block.get("text", "")
                    if _TAG_CLOUD.match(text):
                        block["text"] = _TAG_CLOUD.sub("", text)
                        return "llm-cloud"
                    if _TAG_LOCAL.match(text):
                        block["text"] = _TAG_LOCAL.sub("", text)
                        return "llm-fast"
                    break  # only inspect the first text block
        break  # only inspect the last user message
    return None


class HermesRouter(CustomLogger):
    """
    LiteLLM custom pre-call hook that rewrites model="hermes-router" to
    either "llm-fast" or "llm-cloud" before deployment resolution.
    Requests that already target llm-fast or llm-cloud are passed through.
    """

    async def async_pre_call_hook(
        self,
        user_api_key_dict: Any,
        cache: Any,
        data: dict,
        call_type: str,
    ) -> dict:
        if data.get("model") != "hermes-router":
            return data

        messages = data.get("messages") or []

        # Rule 1: explicit tag — user intent overrides everything
        explicit = _pop_explicit_tag(messages)
        if explicit:
            data["model"] = explicit
            return data

        text = _extract_text(messages)
        approx_tokens = len(text) // _CHARS_PER_TOKEN

        # Rule 2: privacy — always local
        if _FAST_OVERRIDE.search(text):
            data["model"] = "llm-fast"
        # Rule 3: large input — cloud (large-document workload)
        elif approx_tokens > _CLOUD_TOKEN_THRESHOLD:
            data["model"] = "llm-cloud"
        # Rule 4: complexity keyword — cloud
        elif _CLOUD_SIGNALS.search(text):
            data["model"] = "llm-cloud"
        # Rule 5: default — fast (local, private, free)
        else:
            data["model"] = "llm-fast"

        return data

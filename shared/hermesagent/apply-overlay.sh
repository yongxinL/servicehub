#!/usr/bin/env bash
# =============================================================================
# apply-overlay.sh — Reapply persistent edits to /opt/hermes at container start
#
# The image's /opt/hermes is the read-only baseline (~1.4 GB, not duplicated).
# Edits the agent (or you) make to /opt/hermes inside the container are
# captured into the host-mounted overlay folder via overlay-save / overlay-patch,
# then replayed onto /opt/hermes on next start by this script.
#
# Overlay layout (under /opt/data/overlay/, host-mounted via /opt/data):
#   files/      sparse mirror of /opt/hermes — only saved files (whole-file overlay)
#   originals/  pristine baseline copies of touched files (for diff generation)
#   patches/    *.patch files applied in lexical order on top of files/
#
# Order: file overlays first (bulk replacement), then patches (surgical edits).
# Excludes: __pycache__/, *.pyc, .venv/  (machine-specific or huge).
# Fails loud on patch errors — half-applied state is worse than no state.
# =============================================================================
set -euo pipefail

OVERLAY_DIR="${OVERLAY_DIR:-/opt/data/overlay}"
HERMES_DIR="${HERMES_DIR:-/opt/hermes}"

if [[ ! -d "${OVERLAY_DIR}" ]]; then
    echo "[overlay] No overlay dir at ${OVERLAY_DIR} — first run, creating empty skeleton."
    mkdir -p "${OVERLAY_DIR}/files" "${OVERLAY_DIR}/originals" "${OVERLAY_DIR}/patches"
    return 0 2>/dev/null || exit 0
fi

mkdir -p "${OVERLAY_DIR}/files" "${OVERLAY_DIR}/originals" "${OVERLAY_DIR}/patches"

# ---------------------------------------------------------------------------
# 1. File overlays — rsync sparse mirror onto /opt/hermes
# ---------------------------------------------------------------------------
if [[ -n "$(ls -A "${OVERLAY_DIR}/files" 2>/dev/null || true)" ]]; then
    file_count=$(find "${OVERLAY_DIR}/files" -type f \
        ! -name '*.pyc' ! -path '*/__pycache__/*' ! -path '*/.venv/*' \
        | wc -l | tr -d ' ')
    echo "[overlay] Applying ${file_count} file overlay(s) from ${OVERLAY_DIR}/files/"
    rsync -a \
        --exclude='__pycache__/' \
        --exclude='*.pyc' \
        --exclude='.venv/' \
        "${OVERLAY_DIR}/files/" "${HERMES_DIR}/"
fi

# ---------------------------------------------------------------------------
# 2. Patches — apply *.patch in lexical order
# ---------------------------------------------------------------------------
shopt -s nullglob
patches=( "${OVERLAY_DIR}/patches"/*.patch )
shopt -u nullglob

if (( ${#patches[@]} > 0 )); then
    echo "[overlay] Applying ${#patches[@]} patch(es) from ${OVERLAY_DIR}/patches/"
    for p in "${patches[@]}"; do
        name="$(basename "${p}")"
        # --forward: skip if already applied (rsync may have placed the patched file)
        # Without --forward, a re-applied patch would prompt interactively.
        if patch -d "${HERMES_DIR}" -p1 --forward --silent --dry-run < "${p}" >/dev/null 2>&1; then
            patch -d "${HERMES_DIR}" -p1 --forward --silent < "${p}"
            echo "[overlay]   → applied ${name}"
        elif patch -d "${HERMES_DIR}" -p1 -R --silent --dry-run < "${p}" >/dev/null 2>&1; then
            echo "[overlay]   → ${name} already applied (skip)"
        else
            echo "[overlay] FAILED to apply ${name} — conflict against /opt/hermes."
            echo "[overlay] Inspect with:  patch -d ${HERMES_DIR} -p1 --dry-run < ${p}"
            exit 1
        fi
    done
fi

echo "[overlay] Overlay applied."

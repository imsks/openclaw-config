#!/usr/bin/env bash
# Manually sync the live OpenClaw config into this repo.
# Runs automatically via the precmd hook in ~/.zshrc,
# but you can also invoke it directly or via: openclaw-sync
set -euo pipefail

SOURCE="$HOME/.openclaw/openclaw.json"
TARGET="$HOME/Documents/Codebase/openclaw/openclaw.json"

if [[ ! -f "$SOURCE" ]]; then
  echo "[sync] Source not found: $SOURCE" >&2
  exit 1
fi

if cmp -s "$SOURCE" "$TARGET" 2>/dev/null; then
  echo "[sync] Already in sync."
  exit 0
fi

cp "$SOURCE" "$TARGET"
echo "[sync] $(date '+%Y-%m-%d %H:%M:%S') — openclaw.json synced."

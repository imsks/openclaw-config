#!/usr/bin/env bash
# OpenClaw Model Test Suite
# Usage: ./test-model.sh [model-name]
# Runs 5 tests against the currently configured model and reports results.
# Useful when swapping models to validate capabilities before committing.
set -euo pipefail

TIMEOUT_CMD="timeout"
if ! command -v timeout &>/dev/null; then
  if command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
  else
    echo "❌ 'timeout' not found. Install GNU coreutils: brew install coreutils"
    exit 1
  fi
fi

PHONE="+918072937581"
REPO="imsks/Rajniti"
RAJNITI_PATH="/Users/sacmini/Documents/Codebase/Personal/Rajniti"

MODEL="${1:-$(openclaw config get agents.defaults.model.primary 2>/dev/null | tr -d '"' || echo 'unknown')}"
RESULTS=()
PASS=0
FAIL=0

run_test() {
  local num="$1" name="$2" msg="$3" timeout="${4:-300}"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  TEST $num: $name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local start_ms=$(($(date +%s) * 1000))
  local output
  output=$($TIMEOUT_CMD "$timeout" openclaw agent \
    --to "$PHONE" \
    --message "$msg" \
    --deliver \
    --json 2>&1) || {
    echo "  ❌ FAIL — timed out or errored after ${timeout}s"
    RESULTS+=("TEST $num ($name): ❌ FAIL — timeout/error")
    FAIL=$((FAIL + 1))
    return
  }

  local status text dur tokens_in tokens_out model_used
  status=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])" 2>/dev/null || echo "error")
  text=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result']['payloads'][0]['text'][:300])" 2>/dev/null || echo "NO RESPONSE")
  dur=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['meta']['durationMs'])" 2>/dev/null || echo "0")
  tokens_in=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['meta']['agentMeta'].get('usage',{}).get('input',0))" 2>/dev/null || echo "0")
  tokens_out=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['meta']['agentMeta'].get('usage',{}).get('output',0))" 2>/dev/null || echo "0")
  model_used=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['meta']['agentMeta']['model'])" 2>/dev/null || echo "unknown")

  local dur_s=$((dur / 1000))

  if [ "$status" = "ok" ]; then
    echo "  ✅ PASS"
    PASS=$((PASS + 1))
    RESULTS+=("TEST $num ($name): ✅ PASS — ${dur_s}s, ${tokens_out} output tokens")
  else
    echo "  ❌ FAIL — status: $status"
    FAIL=$((FAIL + 1))
    RESULTS+=("TEST $num ($name): ❌ FAIL — status: $status")
  fi

  echo "  Model:    $model_used"
  echo "  Duration: ${dur_s}s"
  echo "  Tokens:   in=$tokens_in out=$tokens_out"
  echo "  Response: ${text:0:200}..."
}

echo "╔══════════════════════════════════════════════════╗"
echo "║     OpenClaw Model Test Suite                    ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  Model:   $MODEL"
echo "║  Phone:   $PHONE"
echo "║  Repo:    $REPO"
echo "║  Date:    $(date '+%Y-%m-%d %H:%M:%S')"
echo "╚══════════════════════════════════════════════════╝"

# Verify gateway
echo ""
echo "Checking gateway..."
if ! openclaw gateway status 2>&1 | grep -q "RPC probe: ok"; then
  echo "❌ Gateway not healthy. Run: openclaw gateway stop && openclaw gateway install"
  exit 1
fi
echo "✅ Gateway healthy"

# Verify model is loaded
echo "Checking model..."
if ollama ps 2>&1 | grep -q "qwen3\|gemma\|qwen2\|llama"; then
  echo "✅ Model loaded: $(ollama ps 2>&1 | tail -1 | awk '{print $1}')"
else
  echo "⚠️  No model loaded — first test will have cold start penalty"
fi

# ── Test 1: Simple query ──
run_test 1 "Simple WhatsApp Query" \
  "What's the capital of Japan and what time zone is it in? Keep it brief."

# ── Test 2: Reasoning / thinking ──
run_test 2 "Reasoning Prompt" \
  "A farmer has 17 sheep. All but 9 die. How many sheep are left? Explain your reasoning step by step."

# ── Test 3: GitHub skill ──
run_test 3 "GitHub Skill (gh CLI)" \
  "Check CI status on GitHub repo $REPO. List the last 3 workflow runs using gh CLI." \
  300

# ── Test 4: Code reading via Claude Code ──
run_test 4 "Claude Code (read + summarize)" \
  "Use Claude Code to read the README.md file in $RAJNITI_PATH and give me a 3-sentence summary of the project." \
  300

# ── Test 5: Exec via Cursor agent ──
run_test 5 "Exec (Cursor Agent)" \
  "Run this shell command and show me the output: ls -la $RAJNITI_PATH/src/ | head -20" \
  300

# ── Summary ──
echo ""
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║     TEST RESULTS                                 ║"
echo "╠══════════════════════════════════════════════════╣"
for r in "${RESULTS[@]}"; do
  echo "║  $r"
done
echo "╠══════════════════════════════════════════════════╣"
echo "║  Total: $PASS passed, $FAIL failed (of 5)       ║"
echo "║  Model: $MODEL"
echo "║  Date:  $(date '+%Y-%m-%d %H:%M:%S')"
echo "╚══════════════════════════════════════════════════╝"

exit $FAIL

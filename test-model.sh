#!/usr/bin/env bash
# OpenClaw Multi-Provider Model Benchmark
#
# Usage:
#   ./test-model.sh              # run all providers
#   ./test-model.sh groq         # run one provider
#   ./test-model.sh local groq   # run a subset
#   ./test-model.sh --dry-run    # parse config and show what would run
#   ./test-model.sh --help
#
# Config: test-providers.json  (see test-providers.example.json)
set -euo pipefail

# ── Globals ──────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/test-providers.json"
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
RESULTS_BASE="$SCRIPT_DIR/test-results"
BACKUP_FILE=""
ORIGINAL_MODEL=""
DRY_RUN=false
PROVIDER_FILTERS=()
TMP_DIR=""

# ── Helpers ──────────────────────────────────────────────────────────────────

usage() {
  cat <<'EOF'
OpenClaw Multi-Provider Model Benchmark

Usage:
  ./test-model.sh                  Run all providers defined in test-providers.json
  ./test-model.sh <id> [<id>...]   Run only the listed provider ids
  ./test-model.sh --dry-run        Show config & what would run, without executing
  ./test-model.sh --help           This message

Config file: test-providers.json (copy test-providers.example.json and fill in API keys)

Provider config format:
  {
    "id": "groq",
    "label": "Groq (Llama 3.3 70B)",
    "model": "groq/llama-3.3-70b-versatile",
    "provider": "groq",
    "apiKey": "gsk_..."
  }

To add a new provider/model, just append another entry to the "providers" array.
EOF
  exit 0
}

die() { echo "❌ $*" >&2; exit 1; }

require_timeout() {
  if command -v timeout &>/dev/null; then
    TIMEOUT_CMD="timeout"
  elif command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
  else
    die "'timeout' not found. Install GNU coreutils: brew install coreutils"
  fi
}

# Read a field from the config JSON. Uses python3 for portability.
cfg_read() {
  python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
path = sys.argv[2]
default = sys.argv[3] if len(sys.argv) > 3 else ''
try:
    for k in path.split('.'):
        d = d[int(k)] if k.isdigit() else d[k]
    print(d)
except Exception:
    print(default)
" "$CONFIG_FILE" "$@"
}

# Store a test result value to a temp file
result_put() {
  local pidx="$1" tidx="$2" field="$3" value="$4"
  echo "$value" > "$TMP_DIR/r_${pidx}_${tidx}_${field}"
}

# Retrieve a test result value from a temp file
result_get() {
  local pidx="$1" tidx="$2" field="$3" default="${4:-}"
  local f="$TMP_DIR/r_${pidx}_${tidx}_${field}"
  if [[ -f "$f" ]]; then
    cat "$f"
  else
    echo "$default"
  fi
}

# ── Parse CLI args ───────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)  usage ;;
    --dry-run)  DRY_RUN=true; shift ;;
    -*)         die "Unknown flag: $1" ;;
    *)          PROVIDER_FILTERS+=("$1"); shift ;;
  esac
done

# ── Load config ──────────────────────────────────────────────────────────────

[[ -f "$CONFIG_FILE" ]] || die "Config not found: $CONFIG_FILE
Copy test-providers.example.json → test-providers.json and fill in your API keys."

PHONE=$(cfg_read "phone")
PROVIDER_COUNT=$(python3 -c "import json; print(len(json.load(open('$CONFIG_FILE'))['providers']))")
TEST_COUNT=$(python3 -c "import json; print(len(json.load(open('$CONFIG_FILE'))['tests']))")

# Build list of provider indices to run
PROVIDER_INDICES=()
for (( i=0; i<PROVIDER_COUNT; i++ )); do
  pid=$(cfg_read "providers.$i.id")
  if [[ ${#PROVIDER_FILTERS[@]} -eq 0 ]]; then
    PROVIDER_INDICES+=("$i")
  else
    for f in "${PROVIDER_FILTERS[@]}"; do
      if [[ "$pid" == "$f" ]]; then
        PROVIDER_INDICES+=("$i")
        break
      fi
    done
  fi
done

[[ ${#PROVIDER_INDICES[@]} -gt 0 ]] || die "No matching providers. Available: $(
  for (( i=0; i<PROVIDER_COUNT; i++ )); do cfg_read "providers.$i.id"; done | tr '\n' ' '
)"

# ── Dry-run ──────────────────────────────────────────────────────────────────

if $DRY_RUN; then
  echo "╔══════════════════════════════════════════════════╗"
  echo "║     DRY RUN — Config Summary                     ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
  echo "  Phone:     $PHONE"
  echo "  Providers: ${#PROVIDER_INDICES[@]} of $PROVIDER_COUNT"
  echo "  Tests:     $TEST_COUNT"
  echo ""
  for idx in "${PROVIDER_INDICES[@]}"; do
    label=$(cfg_read "providers.$idx.label")
    model=$(cfg_read "providers.$idx.model")
    provider=$(cfg_read "providers.$idx.provider")
    skip_auth=$(cfg_read "providers.$idx.skip_auth" "false")
    echo "  [$idx] $label"
    echo "      model:     $model"
    echo "      provider:  $provider"
    echo "      skip_auth: $skip_auth"
    echo ""
  done
  echo "  Tests:"
  for (( t=0; t<TEST_COUNT; t++ )); do
    tname=$(cfg_read "tests.$t.name")
    ttimeout=$(cfg_read "tests.$t.timeout" "300")
    echo "    $((t+1)). $tname (timeout: ${ttimeout}s)"
  done
  exit 0
fi

# ── Setup ────────────────────────────────────────────────────────────────────

require_timeout

ORIGINAL_MODEL=$(openclaw config get agents.defaults.model.primary 2>/dev/null | tr -d '"' || echo "unknown")
RUN_TS=$(date '+%Y-%m-%d_%H-%M-%S')
RESULTS_DIR="$RESULTS_BASE/$RUN_TS"
mkdir -p "$RESULTS_DIR"

TMP_DIR=$(mktemp -d /tmp/openclaw-bench.XXXXXX)

# Back up openclaw config
BACKUP_FILE=$(mktemp /tmp/openclaw-config-backup.XXXXXX.json)
cp "$OPENCLAW_CONFIG" "$BACKUP_FILE"

cleanup() {
  echo ""
  echo "Restoring original config..."
  if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
    cp "$BACKUP_FILE" "$OPENCLAW_CONFIG"
    rm -f "$BACKUP_FILE"
  fi
  if [[ -n "$ORIGINAL_MODEL" && "$ORIGINAL_MODEL" != "unknown" ]]; then
    openclaw models set "$ORIGINAL_MODEL" &>/dev/null || true
  fi
  echo "✅ Restored default model: $ORIGINAL_MODEL"
  rm -rf "$TMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     OpenClaw Multi-Provider Benchmark                       ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Providers: ${#PROVIDER_INDICES[@]}                                              ║"
echo "║  Tests:     $TEST_COUNT per provider                                  ║"
echo "║  Phone:     $PHONE"
echo "║  Original:  $ORIGINAL_MODEL"
echo "║  Results:   $RESULTS_DIR"
echo "║  Date:      $(date '+%Y-%m-%d %H:%M:%S')"
echo "╚══════════════════════════════════════════════════════════════╝"

# Verify gateway
echo ""
echo "Checking gateway..."
if ! openclaw gateway status 2>&1 | grep -q "RPC probe: ok"; then
  die "Gateway not healthy. Run: openclaw gateway stop && openclaw gateway install"
fi
echo "✅ Gateway healthy"

# ── Test runner ──────────────────────────────────────────────────────────────

run_test() {
  local pidx="$1" tidx="$2" provider_label="$3"
  local tname tmesg ttimeout tnum
  tname=$(cfg_read "tests.$tidx.name")
  tmesg=$(cfg_read "tests.$tidx.message")
  ttimeout=$(cfg_read "tests.$tidx.timeout" "300")
  tnum=$((tidx + 1))

  echo ""
  echo "  ── Test $tnum: $tname ──"

  local output
  output=$($TIMEOUT_CMD "$ttimeout" openclaw agent \
    --to "$PHONE" \
    --message "$tmesg" \
    --deliver \
    --json 2>&1) || {
    echo "    ❌ FAIL — timed out or errored after ${ttimeout}s"
    result_put "$pidx" "$tidx" "status" "FAIL"
    result_put "$pidx" "$tidx" "dur" "0"
    result_put "$pidx" "$tidx" "tokens_in" "0"
    result_put "$pidx" "$tidx" "tokens_out" "0"
    result_put "$pidx" "$tidx" "model" "unknown"
    result_put "$pidx" "$tidx" "text" "timeout/error"
    return
  }

  local status dur tokens_in tokens_out model_used text
  eval "$(echo "$output" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    st = d.get('status', 'error')
    r = d.get('result', {})
    meta = r.get('meta', {})
    am = meta.get('agentMeta', {})
    usage = am.get('usage', {})
    payloads = r.get('payloads', [{}])
    txt = payloads[0].get('text', 'NO RESPONSE')[:300] if payloads else 'NO RESPONSE'
    # shell-safe quoting
    txt_safe = txt.replace(\"'\", \"'\\\\''\")
    print(f\"status='{st}'\")
    print(f\"dur='{meta.get(\\\"durationMs\\\", 0)}'\")
    print(f\"tokens_in='{usage.get(\\\"input\\\", 0)}'\")
    print(f\"tokens_out='{usage.get(\\\"output\\\", 0)}'\")
    print(f\"model_used='{am.get(\\\"model\\\", \\\"unknown\\\")}'\")
    print(f\"text='{txt_safe}'\")
except Exception as e:
    print(\"status='error'\")
    print(\"dur='0'\")
    print(\"tokens_in='0'\")
    print(\"tokens_out='0'\")
    print(\"model_used='unknown'\")
    print(f\"text='parse error: {e}'\")
" 2>/dev/null)" || {
    status="error"; dur="0"; tokens_in="0"; tokens_out="0"; model_used="unknown"; text="parse error"
  }

  local dur_s=0
  if [[ "$dur" =~ ^[0-9]+$ ]] && [[ "$dur" -gt 0 ]]; then
    dur_s=$(( dur / 1000 ))
  fi

  if [[ "$status" == "ok" ]]; then
    echo "    ✅ PASS  ${dur_s}s  in=${tokens_in} out=${tokens_out}  model=${model_used}"
    result_put "$pidx" "$tidx" "status" "PASS"
  else
    echo "    ❌ FAIL  status=$status"
    result_put "$pidx" "$tidx" "status" "FAIL"
  fi

  result_put "$pidx" "$tidx" "dur" "$dur_s"
  result_put "$pidx" "$tidx" "tokens_in" "$tokens_in"
  result_put "$pidx" "$tidx" "tokens_out" "$tokens_out"
  result_put "$pidx" "$tidx" "model" "$model_used"
  result_put "$pidx" "$tidx" "text" "${text:0:200}"

  # Save raw JSON output
  echo "$output" > "$RESULTS_DIR/provider-${pidx}_test-${tnum}.json" 2>/dev/null || true
}

# ── Provider loop ────────────────────────────────────────────────────────────

for pidx in "${PROVIDER_INDICES[@]}"; do
  label=$(cfg_read "providers.$pidx.label")
  model=$(cfg_read "providers.$pidx.model")
  provider=$(cfg_read "providers.$pidx.provider")
  skip_auth=$(cfg_read "providers.$pidx.skip_auth" "false")
  api_key=$(cfg_read "providers.$pidx.apiKey" "")

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  PROVIDER: $label"
  echo "  Model:    $model"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Register API key for cloud providers
  if [[ "$skip_auth" != "True" && "$skip_auth" != "true" && -n "$api_key" ]]; then
    echo "  Registering API key for $provider..."
    echo "$api_key" | openclaw models auth paste-token --provider "$provider" 2>&1 | head -3 || {
      echo "  ⚠️  Failed to register API key for $provider — skipping"
      for (( t=0; t<TEST_COUNT; t++ )); do
        result_put "$pidx" "$t" "status" "SKIP"
        result_put "$pidx" "$t" "dur" "0"
        result_put "$pidx" "$t" "tokens_in" "0"
        result_put "$pidx" "$t" "tokens_out" "0"
        result_put "$pidx" "$t" "model" "$model"
        result_put "$pidx" "$t" "text" "auth failed"
      done
      continue
    }
  fi

  # Switch model
  echo "  Switching model to $model..."
  openclaw models set "$model" 2>&1 | head -3 || {
    echo "  ⚠️  Failed to set model $model — skipping provider"
    for (( t=0; t<TEST_COUNT; t++ )); do
      result_put "$pidx" "$t" "status" "SKIP"
      result_put "$pidx" "$t" "dur" "0"
      result_put "$pidx" "$t" "tokens_in" "0"
      result_put "$pidx" "$t" "tokens_out" "0"
      result_put "$pidx" "$t" "model" "$model"
      result_put "$pidx" "$t" "text" "model switch failed"
    done
    continue
  }

  # Verify active model
  active=$(openclaw config get agents.defaults.model.primary 2>/dev/null | tr -d '"' || echo "?")
  echo "  Active model: $active"

  # Run all tests for this provider
  for (( t=0; t<TEST_COUNT; t++ )); do
    run_test "$pidx" "$t" "$label"
  done
done

# ── Comparison Report ────────────────────────────────────────────────────────

W=78

echo ""
echo ""
echo "╔$(printf '═%.0s' $(seq 1 $W))╗"
echo "║  BENCHMARK RESULTS — ${#PROVIDER_INDICES[@]} providers × $TEST_COUNT tests$(printf ' %.0s' $(seq 1 $((W - 40))))║"
echo "╠$(printf '═%.0s' $(seq 1 $W))╣"

for (( t=0; t<TEST_COUNT; t++ )); do
  tname=$(cfg_read "tests.$t.name")
  tnum=$((t + 1))
  echo "║"
  echo "║  Test $tnum: $tname"
  for pidx in "${PROVIDER_INDICES[@]}"; do
    label=$(cfg_read "providers.$pidx.label")
    st=$(result_get "$pidx" "$t" "status" "SKIP")
    dur=$(result_get "$pidx" "$t" "dur" "0")
    tout=$(result_get "$pidx" "$t" "tokens_out" "0")
    if [[ "$st" == "PASS" ]]; then
      mark="✅ PASS"
    elif [[ "$st" == "FAIL" ]]; then
      mark="❌ FAIL"
    else
      mark="⏭  SKIP"
    fi
    printf "║    %-34s %s  %4ss  %5s tok out\n" "$label" "$mark" "$dur" "$tout"
  done
done

echo "║"
echo "╠$(printf '═%.0s' $(seq 1 $W))╣"
echo "║  TOTALS"

for pidx in "${PROVIDER_INDICES[@]}"; do
  label=$(cfg_read "providers.$pidx.label")
  pass=0
  fail=0
  skip=0
  total_dur=0
  total_tokens=0
  for (( t=0; t<TEST_COUNT; t++ )); do
    st=$(result_get "$pidx" "$t" "status" "SKIP")
    dur=$(result_get "$pidx" "$t" "dur" "0")
    tout=$(result_get "$pidx" "$t" "tokens_out" "0")
    case "$st" in
      PASS) pass=$((pass + 1)) ;;
      FAIL) fail=$((fail + 1)) ;;
      *)    skip=$((skip + 1)) ;;
    esac
    total_dur=$((total_dur + dur))
    total_tokens=$((total_tokens + tout))
  done
  ran=$((pass + fail))
  if [[ $ran -gt 0 ]]; then
    avg_dur=$((total_dur / ran))
  else
    avg_dur=0
  fi
  printf "║    %-34s %d/%d passed  avg %3ss  %5s total tok\n" \
    "$label" "$pass" "$TEST_COUNT" "$avg_dur" "$total_tokens"
done

echo "║"
echo "║  Results saved: $RESULTS_DIR"
echo "║  Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "╚$(printf '═%.0s' $(seq 1 $W))╝"

# Write machine-readable summary
python3 << PYEOF
import json, os

cfg = json.load(open("$CONFIG_FILE"))
indices = [int(x) for x in "$( IFS=,; echo "${PROVIDER_INDICES[*]}" )".split(",")]
test_count = int("$TEST_COUNT")
tmp = "$TMP_DIR"
results_dir = "$RESULTS_DIR"

def read_result(pidx, tidx, field, default=""):
    path = os.path.join(tmp, f"r_{pidx}_{tidx}_{field}")
    try:
        with open(path) as f:
            return f.read().strip()
    except:
        return default

summary = {
    "timestamp": "$RUN_TS",
    "original_model": "$ORIGINAL_MODEL",
    "providers": [],
}

for pidx in indices:
    prov = cfg["providers"][pidx]
    tests = []
    for t in range(test_count):
        tests.append({
            "test_id": t + 1,
            "name": cfg["tests"][t]["name"],
            "status": read_result(pidx, t, "status", "SKIP"),
            "duration_s": read_result(pidx, t, "dur", "0"),
            "tokens_in": read_result(pidx, t, "tokens_in", "0"),
            "tokens_out": read_result(pidx, t, "tokens_out", "0"),
            "model": read_result(pidx, t, "model", "unknown"),
        })
    summary["providers"].append({
        "id": prov["id"],
        "label": prov["label"],
        "model": prov["model"],
        "tests": tests,
    })

with open(os.path.join(results_dir, "summary.json"), "w") as f:
    json.dump(summary, f, indent=2)
PYEOF

echo ""
echo "Done. Original model ($ORIGINAL_MODEL) will be restored on exit."

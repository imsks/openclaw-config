# OpenClaw — AI Automation Hub

Personal OpenClaw setup: WhatsApp → Ollama routing → Cursor CLI (Claude 4.6 Opus Thinking) → results back to WhatsApp.

## Architecture

```
You (WhatsApp)
  → OpenClaw Gateway (port 18789)
    → qwen3:8b on Ollama (intent routing, quick replies)
      ├─ Coding task  → Cursor agent (opus-4.6-thinking) → output relayed back to WhatsApp
      ├─ GitHub task  → gh CLI (issues, PRs, CI status)
      └─ Simple chat  → responds directly

Local embeddings (embeddinggemma-300m) for memory search.
```

## Prerequisites

| Tool | Install | Purpose |
|------|---------|---------|
| **Ollama** | `brew install ollama` | Local LLM runtime (qwen3:8b for routing) |
| **OpenClaw** | `npm install -g openclaw` | AI gateway + WhatsApp |
| **Cursor CLI** | Symlinked to `/opt/homebrew/bin/cursor` | Coding agent (Claude 4.6 Opus Thinking) |
| **GitHub CLI** | `brew install gh` | GitHub integration |
| **Node.js 18+** | Required by OpenClaw | Runtime |

## Setup from Scratch

### 1. Pull Ollama models

```bash
ollama pull qwen3:8b           # Routing model (~5 GB, 40k context, tool calling)
```

### 2. Onboard OpenClaw

```bash
openclaw onboard   # Follow wizard: local mode, ollama provider
```

### 3. Link WhatsApp

```bash
openclaw channels login --channel whatsapp   # Scan QR with WhatsApp > Linked Devices
```

**To relink to a different phone number**, see [Relink WhatsApp](#relink-whatsapp) below.

### 4. Auth GitHub

```bash
gh auth login --web --git-protocol https
```

### 5. Start the gateway

```bash
openclaw gateway install   # macOS LaunchAgent, auto-starts on login
```

### 6. (Optional) Web search — Brave Search API

The `web_search` tool needs a **Brave Search API key**. Without it, the agent will report that the tool requires configuration.

1. **Get a key:** [brave.com/search/api](https://brave.com/search/api) → sign up → choose **Data for Search** (not "Data for AI") → create an API key. Free tier: 2,000 requests/month.

2. **Configure OpenClaw** (saves to `~/.openclaw/openclaw.json`):
   ```bash
   openclaw configure --section web
   ```
   Enter your Brave API key when prompted.

3. **Or set via environment:** put `BRAVE_API_KEY=your_key_here` in the gateway environment (e.g. in the LaunchAgent plist or in `~/.openclaw/.env` if you load it before starting the gateway).

4. **Restart the gateway** so it picks up the new config:
   ```bash
   openclaw gateway stop && openclaw gateway install
   ```

## Skills

| Skill | Trigger (WhatsApp message example) | What happens |
|-------|-----------------------------------|-------------|
| **coding-agent** | "Add pagination to the politicians API" | Spawns Cursor agent (opus-4.6-thinking) on Rajniti repo, relays output back to WhatsApp |
| **github** | "What's the CI status on main?" | Runs `gh` commands, returns results |
| **gh-issues** | "List open issues on Rajniti" | Queries GitHub issues |

## Workspace

OpenClaw's workspace points to the active project:

```bash
openclaw config get agents.defaults.workspace
# → /Users/sacmini/Documents/Codebase/Personal/Rajniti
```

The agent also reads `~/.openclaw/workspace/USER.md` for context about you and your projects.

## Daily Operations

| Command | What it does |
|---------|-------------|
| `openclaw gateway install` | Start the gateway service |
| `openclaw gateway stop` | Stop the gateway |
| `openclaw gateway status` | Check if running |
| `openclaw doctor` | Diagnose issues |
| `openclaw tui` | Terminal chat UI |
| `openclaw cron list` | List scheduled jobs |
| `openclaw memory status --deep` | Check memory health |

After config changes:

```bash
openclaw gateway stop && openclaw gateway install
```

## Config Sync

`~/.openclaw/openclaw.json` auto-syncs to this repo via a zsh `precmd` hook.

```bash
openclaw-sync   # Manual sync alias
./sync-config.sh  # Script alternative
```

## Cron Jobs

| Job | Schedule | What it does |
|-----|----------|--------------|
| **openclaw-heartbeat** | Every hour | Keeps the model warm; agent reply (e.g. "OK") is sent to WhatsApp. |

**Run a job by ID (not by name):**
```bash
openclaw cron list   # first column is the job ID
openclaw cron run 149d5320-243c-40cd-af19-b84dec2c40c1 --timeout 120000
```

## Auto-Restart (Power Failure Recovery)

### Boot chain

| Step | Component | Mechanism | Needs login? |
|------|-----------|-----------|:------------:|
| 1 | **Mac reboots** | `pmset autorestart 1` | No |
| 2 | **FileVault unlock** | User enters password at pre-boot screen | **Yes** |
| 3 | **Ollama** | macOS Login Items (`Ollama.app`, hidden) | Yes |
| 4 | **OpenClaw Gateway** | LaunchAgent (`KeepAlive: true`, `RunAtLoad: true`) | Yes |
| 5 | **Ollama keepalive** | LaunchAgent (hourly curl ping keeps model in VRAM) | Yes |
| 6 | **Cursor CLI** | On-demand (spawned per coding task) | — |

After login: Ollama.app launches → LaunchAgent starts gateway → gateway connects WhatsApp → ready.

### FileVault limitation

FileVault is enabled, which blocks auto-login. After a power outage the Mac reboots automatically but **waits at the FileVault password screen** until someone logs in. Only then do LaunchAgents and Login Items start.

**Options to make recovery fully hands-free:**

| Option | Security trade-off | Effort |
|--------|--------------------|--------|
| Disable FileVault (`sudo fdesetup disable`) + enable auto-login | No disk encryption | Low |
| UPS (keeps Mac alive through short outages) | None — keeps FileVault | Hardware purchase |
| Keep FileVault, accept manual password entry | None | Zero |

### Verify power-failure settings

```bash
pmset -g | grep autorestart        # Should show 1
fdesetup status                    # FileVault on/off
sudo defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null
launchctl list | grep openclaw     # LaunchAgent loaded?
```

### After login — if gateway didn't start

```bash
openclaw gateway status                              # Check current state
openclaw gateway stop && openclaw gateway install     # Force restart
```

## Logs & Debugging

### Log files

| File | Contents | Format |
|------|----------|--------|
| `~/.openclaw/logs/gateway.log` | Gateway stdout (connections, messages sent) | Plain text |
| `~/.openclaw/logs/gateway.err.log` | Gateway stderr (errors, warnings, diagnostics) | Plain text |
| `/tmp/openclaw/openclaw-YYYY-MM-DD.log` | Detailed daily log (all subsystems) | JSON (one object per line) |
| `/tmp/openclaw/ollama-keepalive.log` | Ollama keepalive ping results | Plain text |
| `~/.openclaw/logs/config-audit.jsonl` | Config change history | JSONL |

### Live tailing

```bash
# Gateway activity (human-readable)
tail -f ~/.openclaw/logs/gateway.log

# Errors and warnings
tail -f ~/.openclaw/logs/gateway.err.log

# Both streams interleaved
tail -f ~/.openclaw/logs/gateway.log ~/.openclaw/logs/gateway.err.log

# Full structured log (today)
tail -f /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log
```

### Filtering the daily JSON log with jq

```bash
LOG=/tmp/openclaw/openclaw-$(date +%Y-%m-%d).log

# Pretty-print the last 20 entries
tail -20 "$LOG" | jq .

# Errors only
cat "$LOG" | jq 'select(._meta.logLevelName == "ERROR")'

# Filter by subsystem (whatsapp, agent, gateway, cron, diagnostic, etc.)
cat "$LOG" | jq 'select(."0" | test("whatsapp"))'

# Agent runs — start, end, duration
cat "$LOG" | jq 'select(."1" | tostring | test("embedded run"))'

# Timestamps + one-line summary
cat "$LOG" | jq -r '[.time, ._meta.logLevelName, ."0", (."1" | tostring)[:80]] | join(" | ")'
```

### Quick health checks

```bash
openclaw gateway status        # Service status + gateway probe
openclaw doctor                # Full diagnostic (state, services, cleanup hints)
openclaw health                # Gateway health endpoint
ollama ps                      # Running models, VRAM usage, quantization
launchctl list | grep openclaw # LaunchAgent status (exit code -15 = SIGTERM)
```

### Verbose foreground mode

Stop the service and run the gateway in the foreground with full logging for deep debugging:

```bash
openclaw gateway stop
openclaw gateway run --verbose          # All log levels to terminal
openclaw gateway run --verbose --compact # Condensed WebSocket logs
```

Press `Ctrl+C` to stop, then `openclaw gateway install` to restore the background service.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Gateway won't start | `openclaw gateway stop && openclaw gateway install` |
| Model too slow | `ollama ps` — ensure <24 GB usage and >80% GPU |
| WhatsApp disconnected | `openclaw channels login --channel whatsapp` |
| Agent not responding | `tail -50 ~/.openclaw/logs/gateway.err.log` |
| Config broken | `cp ~/.openclaw/openclaw.json.bak ~/.openclaw/openclaw.json` |
| Pairing required | `openclaw devices list` then `openclaw devices approve <id>` |
| `web_search` needs Brave API key | `openclaw configure --section web` then restart gateway (see **Web search** in Setup) |
| **Context limit exceeded** | Set `agents.defaults.compaction.reserveTokensFloor` to 4000 or higher in `openclaw.json`, then restart gateway. Keeps a token buffer so compaction runs before hitting the model limit. |
| **Tool call validation failed** (e.g. "github" was not in request.tools) | Usually caused by a tight context: the tool list gets trimmed. Increase `reserveTokensFloor` (see above) and/or start a fresh session (`/reset` or `/new` in chat). Ensure `commands.nativeSkills` is `auto` so skills like github are included. |

## Memory & State

OpenClaw persists state across sessions via workspace files and a local vector DB.

| File | Purpose | Updated by |
|------|---------|------------|
| `MEMORY.md` | Long-term curated memory (decisions, lessons, project state) | Agent during heartbeats |
| `memory/YYYY-MM-DD.md` | Raw daily session logs | session-memory hook (automatic) |
| `HEARTBEAT.md` | Checklist for hourly heartbeat (gateway health, Ollama, memory) | You (manual) |
| `USER.md` | Your context, projects, preferences | You (manual) |
| `TOOLS.md` | Routing rules, CLI inventory, skill patterns | You or agent |
| `memory/*.sqlite` | Vector DB for semantic memory search | Automatic (embeddinggemma-300m) |

The agent reads `MEMORY.md` + recent daily logs each session to maintain continuity. During heartbeats, it checks system health and distills daily notes into long-term memory.

## Extensibility

**Swap routing model:** Change `agents.defaults.model.primary` in `openclaw.json` to any OpenAI-compatible provider. Add a new entry under `models.providers` (e.g. Groq, Gemini, OpenRouter) with `api: "openai-completions"`. All agents without a per-agent model override will use the new default.

**Add a project:** One row in `TOOLS.md` + one section in `USER.md`. The coding-agent skill reads the project path from TOOLS.md.

**Add a workspace:** New entry in `agents.list` with its own `workspace` and `agentDir`. Each workspace gets independent AGENTS.md, TOOLS.md, USER.md, and memory.

## Adding Models & Providers

OpenClaw has a built-in catalog of 700+ models across providers (Groq, OpenRouter, Anthropic, etc.). To use a cloud model:

### 1. Register the API key

```bash
# Paste token interactively — pipe it or type when prompted
echo "gsk_YOUR_KEY" | openclaw models auth paste-token --provider groq
echo "sk-or-v1-YOUR_KEY" | openclaw models auth paste-token --provider openrouter
```

`--provider` is required. Common values: `groq`, `openrouter`, `anthropic`, `google`, `openai`.

### 2. Switch the default model

```bash
openclaw models set groq/llama-3.3-70b-versatile
```

### 3. Restart the gateway

```bash
openclaw gateway stop && openclaw gateway install
```

### Available models

```bash
openclaw models list                        # Currently configured models
openclaw models list --all --json           # Full 700+ model catalog
openclaw models list --all --provider groq  # Filter by provider
openclaw models status                      # Show active model + auth state
```

### Benchmark across providers

The test suite supports multi-provider comparison. Add providers to `test-providers.json`:

```json
{
  "id": "groq",
  "label": "Groq (Llama 3.3 70B)",
  "model": "groq/llama-3.3-70b-versatile",
  "provider": "groq",
  "apiKey": "gsk_..."
}
```

Then run:

```bash
./test-model.sh              # All providers
./test-model.sh groq         # Single provider
./test-model.sh --dry-run    # Preview without running
```

See `test-providers.example.json` for the full config format.

## Relink WhatsApp

To switch WhatsApp to a new phone number:

### 1. Log out the current session

```bash
openclaw channels logout --channel whatsapp
```

This disconnects the existing linked device. You can also remove it manually from WhatsApp > Settings > Linked Devices on your old phone.

### 2. Link the new number

```bash
openclaw channels login --channel whatsapp
```

Scan the QR code with the new phone's WhatsApp > Settings > Linked Devices > Link a Device.

### 3. Update the allowlist

Edit `~/.openclaw/openclaw.json` and change the phone number in `channels.whatsapp.allowFrom`:

```bash
openclaw config set channels.whatsapp.allowFrom '["+91NEW_NUMBER"]' --strict-json
```

Or edit the file directly — the relevant section:

```json
{
  "channels": {
    "whatsapp": {
      "allowFrom": ["+91NEW_NUMBER"]
    }
  }
}
```

### 4. Restart the gateway

```bash
openclaw gateway stop && openclaw gateway install
```

### 5. Verify

```bash
openclaw channels status --probe   # Should show whatsapp: connected
openclaw gateway status            # RPC probe: ok
```

## File Layout

```
~/.openclaw/
├── openclaw.json              # Main config (source of truth)
├── workspace/                 # Main agent workspace
│   ├── AGENTS.md              # Agent behavior rules
│   ├── SOUL.md                # Personality
│   ├── IDENTITY.md            # Agent identity (name, vibe, emoji)
│   ├── USER.md                # Your context + projects
│   ├── TOOLS.md               # Routing rules + tool notes
│   ├── MEMORY.md              # Long-term curated memory
│   ├── HEARTBEAT.md           # Hourly heartbeat checklist
│   └── memory/                # Daily logs (YYYY-MM-DD.md)
├── workspaces/
│   ├── tbe/                   # TBE agent workspace (planned)
│   └── office/                # Office agent workspace (planned)
├── agents/main/               # Session state
├── logs/                      # Gateway logs
└── memory/                    # SQLite vector DBs (main.sqlite, tbe.sqlite, office.sqlite)

~/Documents/Codebase/openclaw/  (this repo)
├── openclaw.json              # Synced config copy
├── sync-config.sh             # Manual sync script
├── test-model.sh              # Multi-provider benchmark runner
├── test-providers.json        # Provider config with API keys (gitignored)
├── test-providers.example.json # Template — copy and fill in keys
├── test-results/              # Timestamped benchmark outputs (gitignored)
├── TODO.md                    # Roadmap and future plans
└── README.md                  # This file
```

## Future Plans

See [TODO.md](./TODO.md) for the full roadmap including Notion integration, multi-workspace setup, and PR auto-review.
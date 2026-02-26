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
openclaw whatsapp link   # Scan QR with WhatsApp > Linked Devices
```

### 4. Auth GitHub

```bash
gh auth login --web --git-protocol https
```

### 5. Start the gateway

```bash
openclaw gateway install   # macOS LaunchAgent, auto-starts on login
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

All components auto-start on boot:

| Component | Mechanism |
|-----------|-----------|
| **Ollama** | macOS Login Items (`Ollama.app`, hidden) |
| **OpenClaw Gateway** | LaunchAgent (`KeepAlive: true`, `RunAtLoad: true`) |
| **Ollama keepalive** | LaunchAgent (hourly curl ping keeps model in VRAM) |
| **Cursor CLI** | On-demand (spawned per coding task) |

Boot sequence: Mac starts → Ollama.app launches → LaunchAgent starts gateway → gateway connects WhatsApp → ready.

If WhatsApp fails to reconnect after a network outage (gateway exhausts retries), restart manually:
```bash
openclaw gateway stop && openclaw gateway install
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Gateway won't start | `openclaw gateway stop && openclaw gateway install` |
| Model too slow | Check `ollama ps` — ensure <24GB usage and >80% GPU |
| WhatsApp disconnected | `openclaw whatsapp link` |
| Agent not responding | Check `tail -50 /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log` |
| Config broken | `cp ~/.openclaw/openclaw.json.bak ~/.openclaw/openclaw.json` |
| Pairing required | `openclaw devices list` then `openclaw devices approve <id>` |

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
├── test-model.sh              # 5-test validation suite for model swaps
├── TODO.md                    # Roadmap and future plans
└── README.md                  # This file
```

## Future Plans

See [TODO.md](./TODO.md) for the full roadmap including Notion integration, multi-workspace setup, and PR auto-review.

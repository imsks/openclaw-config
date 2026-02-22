# OpenClaw — AI Automation Hub

Personal OpenClaw setup: WhatsApp bot + Claude Code for coding + GitHub automation.

## Architecture

```
You (WhatsApp)
  → OpenClaw Gateway (port 18789)
    → gemma3:4b on Ollama (intent routing, quick replies)
      ├─ Coding task  → spawns Claude Code on target repo
      ├─ GitHub task  → gh CLI (issues, PRs, CI status)
      └─ Simple chat  → responds directly

Local embeddings (embeddinggemma-300m) for memory search.
```

## Prerequisites

| Tool | Install | Purpose |
|------|---------|---------|
| **Ollama** | `brew install ollama` | Local LLM runtime |
| **OpenClaw** | `npm install -g openclaw` | AI gateway + WhatsApp |
| **Claude Code** | `npm install -g @anthropic-ai/claude-code` | Coding agent |
| **GitHub CLI** | `brew install gh` | GitHub integration |
| **Node.js 18+** | Required by OpenClaw | Runtime |

## Setup from Scratch

### 1. Pull Ollama models

```bash
ollama pull gemma3:4b          # Chat model (~3 GB, fast on 24GB M4)
# nomic-embed-text optional — local provider auto-downloads its own
```

Create a context-limited variant (prevents Ollama from using the model's default huge context):

```bash
printf 'FROM gemma3:4b\nPARAMETER num_ctx 16384\nPARAMETER num_predict 1024\n' > /tmp/Modelfile.gemma
ollama create gemma3-4b-16k -f /tmp/Modelfile.gemma
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
| **coding-agent** | "Add pagination to the politicians API" | Spawns Claude Code on Rajniti repo |
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

```bash
# Daily CI check at 9am
openclaw cron add --every "9am" --message "Check Rajniti CI status on GitHub Actions and summarize any failures" --announce

# Weekly issues digest on Monday
openclaw cron add --at "monday 9am" --message "List all open GitHub issues for Rajniti with priorities" --announce
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

## File Layout

```
~/.openclaw/
├── openclaw.json              # Main config (source of truth)
├── workspace/
│   ├── AGENTS.md              # Agent behavior rules
│   ├── SOUL.md                # Personality
│   ├── USER.md                # Your context + projects
│   ├── TOOLS.md               # Local tool notes
│   └── memory/                # Daily logs + long-term memory
├── agents/main/               # Session state
├── logs/                      # Gateway logs
└── memory/                    # SQLite vector DB

~/Documents/Codebase/openclaw/  (this repo)
├── openclaw.json              # Synced config copy
├── sync-config.sh             # Manual sync script
├── TODO.md                    # Roadmap and future plans
└── README.md                  # This file
```

## Future Plans

See [TODO.md](./TODO.md) for the full roadmap including Notion integration, multi-workspace setup, and PR auto-review.

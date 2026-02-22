# OpenClaw + Ollama — Local AI WhatsApp Bot

Personal OpenClaw setup running **entirely local** via Ollama. No cloud API keys required.

## Architecture

```
WhatsApp ←→ OpenClaw Gateway (port 18789) ←→ Ollama (port 11434)
                  ↓
        Local embeddings (embeddinggemma-300m)
        Memory search (SQLite vector DB)
```

## Prerequisites

| Tool | Install |
|------|---------|
| **Ollama** | `brew install ollama` or [ollama.com](https://ollama.com) |
| **OpenClaw** | `npm install -g openclaw` |
| **Node.js** | Required by OpenClaw (v18+) |

## Setup from Scratch

### 1. Pull Ollama models

```bash
ollama pull qwen3-coder        # Primary chat model (18 GB)
ollama pull glm-4.7-flash      # Secondary model (19 GB)
ollama pull nomic-embed-text   # Embedding model (274 MB) — optional, local provider downloads its own
```

### 2. Onboard OpenClaw

```bash
openclaw onboard
```

Follow the wizard. Choose **local** mode and **ollama** as the provider.

### 3. Link WhatsApp

The onboard wizard handles this. If you need to re-link later:

```bash
openclaw whatsapp link
```

Scan the QR code with WhatsApp > Linked Devices.

### 4. Start the gateway

```bash
openclaw gateway install   # Installs as a macOS LaunchAgent (auto-starts on login)
```

## Daily Operations

| Command | What it does |
|---------|-------------|
| `openclaw gateway install` | Install and start the gateway service |
| `openclaw gateway stop` | Stop the gateway |
| `openclaw gateway status` | Check if it's running |
| `openclaw doctor` | Diagnose issues |
| `openclaw doctor --fix` | Auto-fix what it can |
| `openclaw memory status --deep` | Check embedding/memory health |
| `openclaw memory index --force` | Force reindex memory files |
| `openclaw config get <path>` | Read a config value |
| `openclaw config set <path> <value>` | Set a config value |
| `openclaw config unset <path>` | Remove a config value |

After config changes, restart the gateway:

```bash
openclaw gateway stop && openclaw gateway install
```

## Config Reference

The live config lives at `~/.openclaw/openclaw.json`. A synced copy is kept in this repo (see [Config Sync](#config-sync) below).

### Key settings

| Path | Current Value | Purpose |
|------|--------------|---------|
| `agents.defaults.model.primary` | `ollama/qwen3-coder` | Main chat model |
| `agents.defaults.memorySearch.enabled` | `true` | Semantic memory search |
| `agents.defaults.memorySearch.provider` | `local` | Uses local embeddings (no API key) |
| `channels.whatsapp.selfChatMode` | `true` | Chat with yourself for testing |
| `channels.whatsapp.dmPolicy` | `allowlist` | Only responds to allowed numbers |
| `channels.whatsapp.allowFrom` | `["+918072937581"]` | Allowed phone numbers |
| `gateway.port` | `18789` | Local gateway port |
| `gateway.mode` | `local` | Local-only mode |

### Switching models

```bash
# Use a different primary model
openclaw config set agents.defaults.model.primary ollama/glm-4.7-flash

# Restart to apply
openclaw gateway stop && openclaw gateway install
```

### Adding a new Ollama model

1. Pull it: `ollama pull <model-name>`
2. Register it in config under `models.providers.ollama.models` (see `openclaw.json`)
3. Optionally set as primary: `openclaw config set agents.defaults.model.primary ollama/<model-name>`
4. Restart gateway

## Config Sync

The live config (`~/.openclaw/openclaw.json`) auto-syncs to this repo via a `precmd` hook in `~/.zshrc`. Every time you get a new shell prompt, it checks for changes and copies silently.

**Manual sync:**

```bash
openclaw-sync
# or
./sync-config.sh
```

**How it works:** The `_openclaw_sync` function in `~/.zshrc` runs `cmp -s` (near-zero cost) on every prompt and only copies when files differ.

## Troubleshooting

### Gateway won't start

```bash
openclaw gateway stop
openclaw gateway install
# Check logs
tail -50 ~/.openclaw/logs/gateway.log
```

### Memory search not working

```bash
openclaw memory status --deep
```

If it says "no embedding provider":

```bash
openclaw config set agents.defaults.memorySearch.provider local
openclaw gateway stop && openclaw gateway install
openclaw memory status --deep   # Will download the local model (~329 MB) on first run
```

### WhatsApp disconnected

```bash
openclaw whatsapp link   # Re-scan QR code
```

### Session history reset

```bash
# Check for missing transcript files
openclaw doctor
```

This is usually harmless — start a new session and history builds up again.

### Config validation error

If you edit `openclaw.json` manually and break validation:

```bash
# Restore from auto-backup
cp ~/.openclaw/openclaw.json.bak ~/.openclaw/openclaw.json
```

## File Layout

```
~/.openclaw/
├── openclaw.json            # Main config (source of truth)
├── openclaw.json.bak        # Auto-backup on every config write
├── agents/main/             # Agent state, sessions, auth
├── logs/                    # Gateway and sync logs
├── memory/                  # SQLite vector DB for memory search
├── workspace/               # Agent workspace and memory files
├── credentials/             # Auth credentials
└── devices/                 # Linked device info

~/Documents/Codebase/openclaw/   (this repo)
├── openclaw.json            # Synced copy of the live config
├── sync-config.sh           # Manual sync script
└── README.md                # This file
```

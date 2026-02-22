# OpenClaw Automation — TODO

## Done

- [x] Install OpenClaw + Ollama
- [x] Link WhatsApp
- [x] Configure local memory search (embeddinggemma-300m)
- [x] Config sync to project repo (zsh precmd hook)
- [x] Set workspace to Rajniti project
- [x] Update USER.md with project context
- [x] Create glm-4.7-flash-16k custom model (context-limited for 24GB M4)

## In Progress

- [ ] Pull gemma3:4b (lightweight routing model for 24GB M4)
- [x] GitHub CLI auth (`gh auth login`)
- [ ] Configure OpenClaw to use gemma3:4b as primary model
- [ ] Test end-to-end: WhatsApp → agent → Claude Code on Rajniti

## Next Up — Personal Workspace

- [ ] Test coding-agent: send WhatsApp message → spawns Claude Code on Rajniti
- [ ] Test github skill: "check CI status", "list open issues"
- [ ] Set up cron: daily CI status summary (9am)
- [ ] Set up cron: weekly open issues digest (Monday 9am)

## Future — Extensibility

- [ ] **Notion integration** — via Claude Code MCP server (`@modelcontextprotocol/server-notion`)
- [ ] **TBE workspace** — add second workspace/agent when ready
- [ ] **Office workspace** — add Jira + Slack integrations
- [ ] **Multi-agent** — separate agents per workspace if needed (`openclaw agents add`)
- [ ] **Gemini API** — upgrade from Ollama to Gemini free tier if local model quality is insufficient
- [ ] **PR auto-review** — cron job to review new PRs with Claude Code via git worktree

## Architecture Notes

```
WhatsApp message
  → OpenClaw Gateway (port 18789)
    → gemma3:4b (intent routing, light responses)
      ├─ coding task → spawns Claude Code (`claude -p "..." --add-dir /path`)
      ├─ github task → gh CLI (issues, PRs, CI)
      ├─ notion task → Claude Code MCP (future)
      └─ simple chat → responds directly
```

- **Model strategy:** gemma3:4b handles routing + simple replies (fast, 3GB).
  Claude Code handles heavy coding (cloud, high quality). Best of both worlds.
- **Workspace:** pointed at Rajniti. To add repos, update USER.md — no config changes needed.
- **Config sync:** `~/.openclaw/openclaw.json` auto-syncs to this repo via zsh precmd hook.

## Commands Cheat Sheet

```bash
# Gateway
openclaw gateway stop && openclaw gateway install  # restart
openclaw gateway status                            # check health
openclaw doctor                                    # diagnose issues

# Models
ollama ps                                          # check loaded models
ollama stop <model>                                # unload model

# Messaging
openclaw message send --target +91... --message "text"
openclaw tui                                       # terminal chat UI

# Cron
openclaw cron list                                 # list jobs
openclaw cron add --every "9am" --message "..."    # add job

# Skills
openclaw skills list --eligible                    # what's available
openclaw skills info <name>                        # skill details

# Memory
openclaw memory status --deep                      # check embeddings
openclaw memory index --force                      # reindex

# Logs
tail -f /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log | python3 -c "
import sys,json
for l in sys.stdin:
 try:
  d=json.loads(l);m=d.get('1',d.get('0',''))
  if isinstance(m,dict):m=d.get('2',str(m))
  print(f\"{d.get('time','')[-12:]} [{d['_meta']['logLevelName']}] {m}\")
 except:pass
"
```

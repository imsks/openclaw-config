# OpenClaw Automation — TODO

## Done

- [x] Install OpenClaw + Ollama
- [x] Link WhatsApp
- [x] Configure local memory search (embeddinggemma-300m)
- [x] Config sync to project repo (zsh precmd hook)
- [x] Set workspace to Rajniti project
- [x] Update USER.md with project context
- [x] Create custom Ollama models (glm-4.7-flash-16k, qwen2.5-7b-32k)
- [x] GitHub CLI auth (`gh auth login`)
- [x] Switch to qwen2.5-7b-32k (tool support + performance)
- [x] Configure TOOLS.md with routing rules (general vs coding)

## In Progress

- [ ] Test general question routing ("What's the tech stack of Rajniti?")
- [ ] Test coding task routing (spawn Claude Code via coding-agent skill)

## Next Up — Personal Workspace

- [ ] Test end-to-end: WhatsApp → coding-agent → Claude Code on Rajniti
- [ ] Test github skill: "check CI status", "list open issues"
- [ ] Set up cron: daily CI status summary (9am)
- [ ] Set up cron: weekly open issues digest (Monday 9am)

## Future — Extensibility

- [ ] **Notion integration** — via Claude Code MCP server (`@modelcontextprotocol/server-notion`)
- [ ] **TBE workspace** — add project to TOOLS.md + USER.md when ready
- [ ] **Office workspace** — add Jira + Slack integrations
- [ ] **Multi-agent** — separate agents per workspace if needed (`openclaw agents add`)
- [ ] **Gemini API** — upgrade from Ollama to Gemini free tier if local model quality is insufficient
- [ ] **PR auto-review** — cron job to review new PRs with Claude Code via git worktree

## Architecture

```
WhatsApp message
  → OpenClaw Gateway (port 18789)
    → qwen2.5-7b-32k (reads TOOLS.md for routing)
      ├─ general question → answers directly from USER.md context
      ├─ coding task → coding-agent skill → bash pty:true → claude '<task>'
      ├─ github task → gh CLI (issues, PRs, CI)
      └─ notion task → Claude Code MCP (future)
```

- **Routing:** Defined in TOOLS.md. Bot decides general vs coding based on message intent.
- **No per-project scripts.** The coding-agent skill handles spawning Claude Code with the right workdir.
- **Extensibility:** New project = one row in TOOLS.md + one section in USER.md.

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
openclaw cron add --cron "0 9 * * *" --tz "Asia/Kolkata" --name "job" --message "..."

# Skills
openclaw skills list                               # what's available

# Memory
openclaw memory status --deep                      # check embeddings

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

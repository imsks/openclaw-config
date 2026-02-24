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
- [x] Switch to qwen3:8b (8.2B params, 40k context, tool calling)
- [x] Enable exec tool (`tools.exec.security: "allowlist"`)
- [x] Configure TOOLS.md with routing rules (general vs coding)
- [x] Test general question routing (answered from USER.md context)
- [x] Test exec tool (file listing + code reading via bash)
- [x] Symlink Cursor CLI to PATH (`/opt/homebrew/bin/cursor`)
- [x] Update TOOLS.md to use Cursor agent instead of Claude Code
- [x] Create multi-workspace agents (main, tbe, office)

- [x] Test Cursor agent spawn via OpenClaw coding task
- [x] Configure browser/web tools (Brave, openclaw profile, web search + fetch)
- [x] Fix exec tool security (`allowlist` → `full` — allowlist blocked all commands)

- [x] Test github skill via OpenClaw (`gh run list`, `gh issue list` with `--repo` flag)
- [x] Set up cron: daily CI status summary (9am IST) — `rajniti-ci-daily`
- [x] Set up cron: weekly open issues digest (Monday 9am IST) — `rajniti-issues-weekly`
- [x] Test end-to-end: WhatsApp → coding-agent → Cursor agent on Rajniti (message delivered)
- [x] Ollama keepalive LaunchAgent (hourly heartbeat, 24h `keep_alive`)
- [x] Increase maxTokens to 4096 for longer responses
- [x] Create `test-model.sh` — reusable 5-test validation suite for model swaps
- [x] qwen3:8b full test pass (simple query, reasoning, GitHub, Claude Code, Cursor exec)

## Next Up

- [ ] GitHub PR creation flow: Cursor agent makes changes → gh pr create
- [ ] Get Cursor agent to return results back through WhatsApp (monitor + relay output)

## Future — Extensibility

- [ ] **TBE workspace** — add repos to tbe agent when ready
- [ ] **Office workspace** — add repos + Jira/Slack integrations
- [ ] **Notion integration** — via MCP server (`@modelcontextprotocol/server-notion`)
- [ ] **Browser automation** — headless Chromium for cron tasks + testing
- [ ] **Gemini Flash** — upgrade routing model if qwen3:8b quality is insufficient
- [ ] **PR auto-review** — cron job to review new PRs with Cursor agent via git worktree

## Architecture

```
WhatsApp message
  → OpenClaw Gateway (port 18789)
    → Route to agent (main / tbe / office)
      → qwen3:8b (reads TOOLS.md for routing)
        ├─ general question → answers directly from USER.md context
        ├─ coding task → coding-agent skill → cursor agent -p '<task>' --yolo
        ├─ github task → gh CLI (issues, PRs, CI)
        └─ browser task → headless Chromium (future)

Agents:
  main (Personal) → ~/.openclaw/workspace       → Rajniti
  tbe             → ~/.openclaw/workspaces/tbe   → TBD
  office          → ~/.openclaw/workspaces/office → TBD
```

- **Coding agent:** Cursor CLI (`cursor agent -p --yolo --model auto`). Uses Cursor subscription — zero extra API cost.
- **Routing:** Defined in each agent's TOOLS.md. Bot decides general vs coding based on message intent.
- **Extensibility:** New project = one row in TOOLS.md + one section in USER.md.

## Commands Cheat Sheet

```bash
# Model Testing
./test-model.sh                                    # run 5-test suite on current model
./test-model.sh ollama/qwen3:8b                    # run with explicit model name

# Gateway
openclaw gateway stop && openclaw gateway install  # restart
openclaw gateway status                            # check health
openclaw doctor                                    # diagnose issues

# Agents
openclaw agents list                               # list all agents
openclaw agent --message "..." --to +91... --agent main  # talk to specific agent

# Models
ollama ps                                          # check loaded models
ollama stop <model>                                # unload model

# Messaging
openclaw message send --target +91... --message "text"
openclaw tui                                       # terminal chat UI

# Cron
openclaw cron list                                 # list jobs
openclaw cron add --cron "0 9 * * *" --tz "Asia/Kolkata" --name "job" --message "..."

# Cursor Agent (manual)
cursor agent -p "task" --workspace /path --yolo --model auto

# Skills
openclaw skills list                               # what's available

# Logs (live)
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

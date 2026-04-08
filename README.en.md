# claude-morning-cron

Schedule Claude CLI prompts via crontab. Supports macOS and Linux.

[中文版 →](README.md)

---

## Why This Exists

Claude's usage resets on a **rolling 5-hour window** — starting from your *first message*, not a fixed clock time.

### What happens if you start at 10 AM?

Assume you haven't touched Claude all morning and send your first message at 10:00:

```
Window 1: 10:00 → 15:00   ← only 2 hours before lunch, quota barely touched
Window 2: 15:00 → 20:00   ← heavy afternoon coding, easy to burn through by 18:00
Window 3: 20:00 → 01:00   ← resets at 8 PM — you've already clocked out
```

What this feels like in practice:

- Morning 10–12: only 2 hours before lunch, quota is far from exhausted
- After the 15:00 reset, heavy coding easily **burns through the full 5-hour window before 18:00**
- You hit the rate limit with 1–2 hours left in the workday, right when you need it most
- The 20:00 reset arrives after you've stopped work — that entire window's quota expires overnight
- Result: **throttled in the afternoon, quota wasted while you sleep**

### How bad is the misalignment?

| First message | Reset times | Problem |
|--------------|-------------|---------|
| 10:00 | 15:00 / **20:00** | Rate-limited before EOD; 20:00 quota burns overnight |
| 09:00 | 14:00 / **19:00** | 19:00 reset after work, too tired to use it |
| **07:01** | **12:01 / 17:01** | **Morning / afternoon / evening — all three covered** |

### Why 07:01 / 12:01 / 17:01?

The default schedule sends a lightweight message just before each work block, anchoring resets to a developer-friendly rhythm:

```
Window 1: 07:01 → 12:01   ← warm up before work, full morning covered
Window 2: 12:01 → 17:01   ← triggered at lunch, full afternoon covered
Window 3: 17:01 → 22:01   ← triggered before EOD, evening covered
```

The one-minute offset (`07:01` instead of `07:00`) avoids the top-of-hour traffic spike.

---

## Quick Start

```bash
# Enable default schedule (07:01, 12:01, 17:01 — sends "早安")
./claude-morning-cron.sh on

# Check status
./claude-morning-cron.sh status

# Disable
./claude-morning-cron.sh off
```

## Commands

| Command | Description |
|---------|-------------|
| `on` / `enable` | Enable scheduled tasks |
| `off` / `disable` | Disable scheduled tasks |
| `status` / `st` | Show current state |
| `test` / `dry-run` | Run prompt once immediately |
| `log` / `logs` | Tail the log file |

## Configuration

Configure via environment variables or a `.env` file in the project root:

```bash
# .env
CLAUDE_CRON_MODEL=haiku
CLAUDE_CRON_PROMPT=早安
CLAUDE_CRON_SCHEDULE="1 7 * * *|1 12 * * *|1 17 * * *"
CLAUDE_CRON_LOG_DIR=~/.claude/logs
CLAUDE_CRON_TAG=claude-cron-greeting
```

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_CRON_MODEL` | `haiku` | Claude model name |
| `CLAUDE_CRON_PROMPT` | `早安` | Prompt text |
| `CLAUDE_CRON_SCHEDULE` | `1 7 * * *\|1 12 * * *\|1 17 * * *` | Cron expressions, `\|` separated |
| `CLAUDE_CRON_LOG_DIR` | `~/.claude/logs` | Log directory |
| `CLAUDE_CRON_TAG` | `claude-cron-greeting` | Crontab identifier tag |

## Examples

```bash
# Custom prompt every hour
CLAUDE_CRON_PROMPT="hello" CLAUDE_CRON_SCHEDULE="0 * * * *" ./claude-morning-cron.sh on

# Test with opus model
CLAUDE_CRON_MODEL=opus ./claude-morning-cron.sh test
```

## macOS Note

cron requires "Full Disk Access" to work properly:  
**System Settings → Privacy & Security → Full Disk Access → add `/usr/sbin/cron`**

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude` command available)
- `bash` 4+, `crontab`

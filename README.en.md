# claude-morning-cron

Manipulate Claude Code's 5-hour usage window into resetting when you actually need it. Via crontab. Supports macOS and Linux.

[中文版 →](README.md)

> **Alternative:** Claude Code now natively supports scheduled tasks at https://claude.ai/code/scheduled — no local cron needed. The "Why" section below is still useful for understanding the window mechanics.

---

## Why

Claude Code gives you a token budget that resets every 5 hours. The window starts when you send your first message, **floored to the clock hour** (e.g., message at 8:30 → window starts at 8:00).

### Without vs With Warmup

```
            6am    7     8     9    10    11    12    1pm    2     3     4     5    6pm
             |     |     |     |     |     |     |     |     |     |     |     |     |

Without:              [========== window 1 =========]
                       work ~8:30-11am  ░░ dead ░░
                                                    [========== window 2 =========]
                                                             work ~1pm-6pm

          cron trigger
               │
               ▼
With:        [========== window 1 =========]
              ░ idle ░  work ~8:30-11am
                                          [========== window 2 =========]
                                                  work ~11am-4pm
                                                                        [== win 3 ==]
                                                                        work ~4pm-6pm
```

> With warmup, you squeeze in an extra fresh window starting at 4 PM.

### Default Schedule

The default **07:01 / 12:01 / 17:01** anchors windows to a developer-friendly rhythm:

```
Window 1: 07:01 → 12:01   ← warm up before work, full morning covered
Window 2: 12:01 → 17:01   ← triggered at lunch, full afternoon covered
Window 3: 17:01 → 22:01   ← triggered before EOD, evening covered
```

The one-minute offset (`07:01` not `07:00`) avoids a boundary race between the trigger and window reset.

---

## Quick Start

```bash
git clone https://github.com/<your-user>/claude-morning-cron.git
cd claude-morning-cron

# Enable default schedule
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
# CLAUDE_CRON_PROMPT=hello          # unset = random pick
CLAUDE_CRON_SCHEDULE="1 7 * * *|1 12 * * *|1 17 * * *"
CLAUDE_CRON_LOG_DIR=~/.claude/logs
CLAUDE_CRON_TAG=claude-cron-greeting
```

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_CRON_MODEL` | `haiku` | Claude model name |
| `CLAUDE_CRON_PROMPT` | random | Prompt text (if unset, picks randomly from 100 built-in short phrases) |
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

---

## About the Quota Window

Some underdocumented details about Claude Code's 5-hour window (as of April 2026):

- **Fixed block**: once anchored, boundaries don't move no matter how much you use
- **Floors to clock hours**: message at 8:15 → window starts at 8:00
- **Shared across products**: claude.ai, Claude Code, and Claude Desktop share one pool
- **Token-based, not message-based**: Extended Thinking and tool use consume budget faster than regular chat
- **Separate 7-day weekly cap**: independent of the 5-hour window, they don't interact

## FAQ

**Does this waste budget?**
One Haiku "hi" with no tools, no context. You won't notice it.

**What if I'm already rate-limited?**
Still works. The request reaches Anthropic's servers either way, and it still anchors the window.

**Don't want to use cron?**
Claude Code natively supports scheduled tasks: https://claude.ai/code/scheduled — no local setup needed.

---

## Proxy Support

crontab does not inherit your terminal's proxy settings. If your network requires a proxy to reach the Claude API, the script **automatically captures** your current proxy variables (`http_proxy`, `https_proxy`, etc.) when you run `on` and injects them into the crontab entry.

- No proxy: nothing to configure, no impact
- With proxy: run `./claude-morning-cron.sh on` from a terminal where the proxy is active
- Proxy changed: re-run `on` to update

## Troubleshooting

### cron returns 403

```
Failed to authenticate. API Error: 403 {"error":{"type":"forbidden","message":"Request not allowed"}}
```

This is usually **not an auth issue** — it means crontab is missing proxy variables, so the request can't reach the Claude API. To fix:

1. Verify `claude -p "hi"` works in your terminal
2. Re-run `./claude-morning-cron.sh on` from a terminal **with proxy active**
3. Check `crontab -l` to confirm the entry includes `http_proxy=...` etc.

### macOS cron permission denied

cron requires "Full Disk Access":
**System Settings → Privacy & Security → Full Disk Access → add `/usr/sbin/cron`**

### claude command not found

Make sure Claude Code CLI is installed and in your PATH:

```bash
which claude         # confirm path
claude -p "hi"       # confirm it runs
```

The script searches `claude`, `~/.local/bin/claude`, `/usr/local/bin/claude` in order.

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude` command available)
- `bash` 4+, `crontab`

## License

[MIT](LICENSE)

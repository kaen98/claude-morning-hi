#!/usr/bin/env bash
#
# claude-cron.sh — Schedule Claude CLI to run prompts on a cron schedule
#
# Supports macOS and Linux. Manages crontab entries tagged with a unique
# identifier so they can be enabled/disabled without affecting other jobs.
#
# Usage:
#   ./claude-cron.sh on              Enable scheduled tasks
#   ./claude-cron.sh off             Disable scheduled tasks
#   ./claude-cron.sh status          Show current state
#   ./claude-cron.sh test            Run the prompt once immediately (dry run)
#   ./claude-cron.sh log             Tail the log file
#
# Configuration (environment variables or .env file):
#   CLAUDE_CRON_MODEL    Model to use           (default: haiku)
#   CLAUDE_CRON_PROMPT   Prompt text             (default: 早安)
#   CLAUDE_CRON_SCHEDULE Cron expressions, "|"   (default: "1 7 * * *|1 12 * * *|1 17 * * *")
#   CLAUDE_CRON_LOG_DIR  Log directory           (default: ~/.claude/logs)
#   CLAUDE_CRON_TAG      Unique crontab tag      (default: claude-cron-greeting)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Load .env if present ─────────────────────────────────────────────
ENV_FILE="${SCRIPT_DIR}/.env"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

# ── Defaults ─────────────────────────────────────────────────────────
MODEL="${CLAUDE_CRON_MODEL:-haiku}"
PROMPT="${CLAUDE_CRON_PROMPT:-早安}"
SCHEDULE="${CLAUDE_CRON_SCHEDULE:-1 7 * * *|1 12 * * *|1 17 * * *}"
LOG_DIR="${CLAUDE_CRON_LOG_DIR:-$HOME/.claude/logs}"
CRON_TAG="# ${CLAUDE_CRON_TAG:-claude-cron-greeting}"

# ── Detect claude binary ─────────────────────────────────────────────
find_claude() {
  if command -v claude >/dev/null 2>&1; then
    command -v claude
  elif [ -x "$HOME/.local/bin/claude" ]; then
    echo "$HOME/.local/bin/claude"
  elif [ -x "/usr/local/bin/claude" ]; then
    echo "/usr/local/bin/claude"
  else
    echo ""
  fi
}

CLAUDE_BIN="$(find_claude)"

# ── OS detection ─────────────────────────────────────────────────────
OS="$(uname -s)"

# ── Helpers ──────────────────────────────────────────────────────────
ensure_log_dir() {
  mkdir -p "$LOG_DIR"
}

current_crontab() {
  crontab -l 2>/dev/null || true
}

stripped_crontab() {
  current_crontab | grep -v "$CRON_TAG" || true
}

parse_schedules() {
  local IFS='|'
  read -ra SCHEDS <<< "$SCHEDULE"
  echo "${SCHEDS[@]}"
}

format_time() {
  local m="$1" h="$2"
  printf "%02d:%02d" "$h" "$m"
}

macos_hint() {
  if [ "$OS" = "Darwin" ]; then
    echo ""
    echo "⚠  macOS 注意 / macOS Note:"
    echo "   cron 需要「全盘访问」权限才能正常运行。"
    echo "   cron requires \"Full Disk Access\" to work properly."
    echo "   系统设置 → 隐私与安全 → 全盘访问 → 添加 /usr/sbin/cron"
    echo "   System Settings → Privacy & Security → Full Disk Access → add /usr/sbin/cron"
  fi
}

# ── Commands ─────────────────────────────────────────────────────────
cmd_on() {
  if [ -z "$CLAUDE_BIN" ]; then
    echo "❌ 找不到 claude 命令 / claude command not found"
    echo "   请先安装: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
  fi

  ensure_log_dir

  local base
  base="$(stripped_crontab)"

  local new_entries=""
  local IFS='|'
  read -ra SCHEDS <<< "$SCHEDULE"
  for sched in "${SCHEDS[@]}"; do
    new_entries="${new_entries}${sched}  ${CLAUDE_BIN} --model ${MODEL} -p '${PROMPT}' >> ${LOG_DIR}/claude-cron.log 2>&1 ${CRON_TAG}
"
  done

  echo "${base}
${new_entries}" | crontab -

  echo "✅ 定时任务已开启 / Scheduled tasks enabled:"
  for sched in "${SCHEDS[@]}"; do
    local m h
    m=$(echo "$sched" | awk '{print $1}')
    h=$(echo "$sched" | awk '{print $2}')
    echo "   $(format_time "$m" "$h")  ${MODEL} → \"${PROMPT}\""
  done
  echo ""
  echo "📄 日志 / Log: ${LOG_DIR}/claude-cron.log"
  macos_hint
}

cmd_off() {
  local base
  base="$(stripped_crontab)"
  echo "$base" | crontab -
  echo "❌ 定时任务已关闭 / Scheduled tasks disabled"
}

cmd_status() {
  local count
  count=$(current_crontab | grep -c "$CRON_TAG" || true)
  if [ "$count" -gt 0 ]; then
    echo "✅ 运行中 / Active (${count} jobs):"
    current_crontab | grep "$CRON_TAG" | while IFS= read -r line; do
      local m h
      m=$(echo "$line" | awk '{print $1}')
      h=$(echo "$line" | awk '{print $2}')
      echo "   $(format_time "$m" "$h")  ${MODEL} → \"${PROMPT}\""
    done
  else
    echo "❌ 未开启 / Inactive"
  fi
  echo ""
  echo "OS: ${OS}  Claude: ${CLAUDE_BIN:-not found}"
}

cmd_test() {
  if [ -z "$CLAUDE_BIN" ]; then
    echo "❌ 找不到 claude 命令 / claude command not found"
    exit 1
  fi
  echo "🧪 测试运行 / Test run: ${CLAUDE_BIN} --model ${MODEL} -p '${PROMPT}'"
  echo "---"
  "$CLAUDE_BIN" --model "$MODEL" -p "$PROMPT"
}

cmd_log() {
  local logfile="${LOG_DIR}/claude-cron.log"
  if [ -f "$logfile" ]; then
    tail -50 "$logfile"
  else
    echo "📄 日志文件不存在 / Log file not found: $logfile"
  fi
}

cmd_help() {
  local lang="${LANG:-}"
  # Auto-detect: Chinese locale → zh, otherwise → en
  # Override with: CLAUDE_CRON_LANG=zh or CLAUDE_CRON_LANG=en
  local ul="${CLAUDE_CRON_LANG:-}"
  if [ -z "$ul" ]; then
    case "$lang" in
      zh_*|ZH_*) ul="zh" ;;
      *)         ul="en" ;;
    esac
  fi

  if [ "$ul" = "zh" ]; then
    cat <<'HELP'
claude-cron.sh — 通过 crontab 定时执行 Claude CLI 提示词

用法:
  ./claude-cron.sh on        开启定时任务
  ./claude-cron.sh off       关闭定时任务
  ./claude-cron.sh status    查看当前状态
  ./claude-cron.sh test      立即执行一次（测试）
  ./claude-cron.sh log       查看日志
  ./claude-cron.sh help      显示帮助信息

配置项（环境变量或 .env 文件）:
  CLAUDE_CRON_MODEL     模型名称         (默认: haiku)
  CLAUDE_CRON_PROMPT    提示词           (默认: 早安)
  CLAUDE_CRON_SCHEDULE  Cron 表达式,"|" (默认: "1 7 * * *|1 12 * * *|1 17 * * *")
  CLAUDE_CRON_LOG_DIR   日志目录         (默认: ~/.claude/logs)
  CLAUDE_CRON_TAG       Crontab 标签     (默认: claude-cron-greeting)
  CLAUDE_CRON_LANG      帮助语言 zh/en   (默认: 自动检测)

示例:
  # 自定义提示词，每小时执行
  CLAUDE_CRON_PROMPT="你好" CLAUDE_CRON_SCHEDULE="0 * * * *" ./claude-cron.sh on

  # 使用 .env 文件配置
  echo 'CLAUDE_CRON_PROMPT="早上好"' > .env
  ./claude-cron.sh on

macOS 注意:
  cron 需要「全盘访问」权限才能正常运行。
  系统设置 → 隐私与安全 → 全盘访问 → 添加 /usr/sbin/cron
HELP
  else
    cat <<'HELP'
claude-cron.sh — Schedule Claude CLI prompts via crontab

Usage:
  ./claude-cron.sh on        Enable scheduled tasks
  ./claude-cron.sh off       Disable scheduled tasks
  ./claude-cron.sh status    Show current state
  ./claude-cron.sh test      Run the prompt once (dry run)
  ./claude-cron.sh log       Tail the log file
  ./claude-cron.sh help      Show this help message

Configuration (env vars or .env file):
  CLAUDE_CRON_MODEL     Model name       (default: haiku)
  CLAUDE_CRON_PROMPT    Prompt text       (default: 早安)
  CLAUDE_CRON_SCHEDULE  Cron exprs, "|"  (default: "1 7 * * *|1 12 * * *|1 17 * * *")
  CLAUDE_CRON_LOG_DIR   Log directory    (default: ~/.claude/logs)
  CLAUDE_CRON_TAG       Crontab tag      (default: claude-cron-greeting)
  CLAUDE_CRON_LANG      Help language     (default: auto-detect from LANG)

Examples:
  # Custom prompt, every hour
  CLAUDE_CRON_PROMPT="hello" CLAUDE_CRON_SCHEDULE="0 * * * *" ./claude-cron.sh on

  # Use .env file
  echo 'CLAUDE_CRON_PROMPT="Good morning"' > .env
  ./claude-cron.sh on

macOS Note:
  cron requires "Full Disk Access" to work properly.
  System Settings → Privacy & Security → Full Disk Access → add /usr/sbin/cron
HELP
  fi
}

# ── Main ─────────────────────────────────────────────────────────────
case "${1:-help}" in
  on|enable|start)   cmd_on     ;;
  off|disable|stop)  cmd_off    ;;
  status|st)         cmd_status ;;
  test|dry-run)      cmd_test   ;;
  log|logs)          cmd_log    ;;
  help|-h|--help)    cmd_help   ;;
  *)
    echo "Unknown command: $1"
    cmd_help
    exit 1
    ;;
esac

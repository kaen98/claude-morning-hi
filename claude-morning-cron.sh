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
PROMPT="${CLAUDE_CRON_PROMPT:-__random__}"

# ── Random prompts pool ──────────────────────────────────────────────
RANDOM_PROMPTS=(
  "早安，今天天气怎么样？"
  "帮我讲个冷笑话"
  "推荐一首适合工作时听的歌"
  "用一句话总结今天的日期"
  "给我一个编程小技巧"
  "你觉得咖啡和茶哪个更适合写代码？"
  "随便聊聊，最近有什么新鲜事？"
  "帮我想一个变量名，要有创意"
  "你最喜欢哪种编程语言？"
  "早上好，给我一点动力"
  "讲一个关于程序员的段子"
  "今天适合重构代码吗？"
  "用emoji描述一下你的心情"
  "推荐一部科幻电影"
  "如果代码会说话，它会说什么？"
  "hello, what's your favorite color?"
  "给我一个有趣的历史冷知识"
  "用三个词形容今天"
  "你怎么看待 tabs vs spaces？"
  "写一首关于debug的俳句"
  "推荐一本技术书"
  "如果你是一个函数，你的返回值是什么？"
  "今天是星期几？"
  "说一个你知道的最短的笑话"
  "bonjour, comment ça va?"
  "帮我取个项目名"
  "你觉得AI会写诗吗？写一首试试"
  "おはようございます"
  "给我一个摸鱼的理由"
  "用一行代码表达你的心情"
  "推荐一个好用的命令行工具"
  "如果bug是一种动物，它是什么？"
  "早起的鸟儿有虫吃，早起的程序员呢？"
  "hey, tell me something interesting"
  "你觉得递归和循环哪个更优雅？"
  "给我一个随机数，1到100"
  "用一个比喻描述编程"
  "今天的幸运数字是？"
  "推荐一个周末活动"
  "hello world 的一百种写法，来一个"
  "你知道什么有趣的unicode字符？"
  "hola, ¿cómo estás?"
  "给我一句鼓励的话"
  "如果你能发明一个关键字，你会叫它什么？"
  "讲一个关于Linux的趣事"
  "今天适合学点什么新东西？"
  "你怎么看待暗色主题vs亮色主题？"
  "来一个脑筋急转弯"
  "guten Morgen!"
  "推荐一首中文歌"
  "用一句话解释什么是API"
  "如果编程语言是食物，Python是什么？"
  "给我一个commit message的灵感"
  "你觉得什么时候该用微服务？"
  "随机推荐一个GitHub上的有趣项目"
  "안녕하세요"
  "给我一个摸鱼时可以学的小知识"
  "你觉得注释重要吗？"
  "来一句程序员的土味情话"
  "如果你是一个容器，你会装什么？"
  "今天要不要写点测试？"
  "推荐一种新的编程范式让我了解"
  "привет, как дела?"
  "给我一个正则表达式的小挑战"
  "你觉得什么是好的代码？"
  "来一个关于数据库的冷知识"
  "buongiorno!"
  "如果你能穿越到任何年代写代码，你选哪年？"
  "推荐一个好用的VS Code插件"
  "你觉得未来的编程会是什么样？"
  "说一个你知道的算法，用大白话解释"
  "给我一个激励自己的座右铭"
  "今天的代码运势如何？"
  "你更喜欢前端还是后端？"
  "来一个关于网络协议的趣事"
  "sawadee krub"
  "如果代码有味道，好代码闻起来像什么？"
  "推荐一个提高效率的习惯"
  "你知道第一个bug的故事吗？"
  "用一句话解释什么是递归"
  "今天要不要学一个新的快捷键？"
  "给我一个关于git的小技巧"
  "你觉得结对编程怎么样？"
  "来一个数学趣题"
  "olá, tudo bem?"
  "如果你能给所有程序员一个建议，是什么？"
  "推荐一个有趣的API"
  "你觉得什么是最被低估的编程语言？"
  "来一句关于时间复杂度的俏皮话"
  "merhaba!"
  "给我一个让代码更可读的建议"
  "你觉得开源的意义是什么？"
  "来一个关于编译器的冷知识"
  "sveiki!"
  "如果你是一个排序算法，你是哪个？"
  "推荐一个有趣的命令行彩蛋"
  "今天学到了什么新东西？"
  "jambo!"
  "给我一个减少技术债的小建议"
  "你觉得最优雅的设计模式是哪个？"
  "来，干了这杯咖啡，继续写代码"
)

pick_random_prompt() {
  local count=${#RANDOM_PROMPTS[@]}
  local index=$((RANDOM % count))
  echo "${RANDOM_PROMPTS[$index]}"
}
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
    new_entries="${new_entries}${sched}  ${SCRIPT_DIR}/$(basename "$0") run >> ${LOG_DIR}/claude-cron.log 2>&1 ${CRON_TAG}
"
  done

  echo "${base}
${new_entries}" | crontab -

  echo "✅ 定时任务已开启 / Scheduled tasks enabled:"
  for sched in "${SCHEDS[@]}"; do
    local m h
    m=$(echo "$sched" | awk '{print $1}')
    h=$(echo "$sched" | awk '{print $2}')
    echo "   $(format_time "$m" "$h")  ${MODEL} → $([ "$PROMPT" = "__random__" ] && echo "随机提示词/random" || echo "\"${PROMPT}\"")"
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
      echo "   $(format_time "$m" "$h")  ${MODEL} → $([ "$PROMPT" = "__random__" ] && echo "随机提示词/random" || echo "\"${PROMPT}\"")"
    done
  else
    echo "❌ 未开启 / Inactive"
  fi
  echo ""
  echo "OS: ${OS}  Claude: ${CLAUDE_BIN:-not found}"
}

resolve_prompt() {
  if [ "$PROMPT" = "__random__" ]; then
    pick_random_prompt
  else
    echo "$PROMPT"
  fi
}

cmd_run() {
  if [ -z "$CLAUDE_BIN" ]; then
    echo "❌ 找不到 claude 命令 / claude command not found"
    exit 1
  fi
  local p
  p="$(resolve_prompt)"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] prompt: ${p}"
  "$CLAUDE_BIN" --model "$MODEL" -p "$p"
}

cmd_test() {
  if [ -z "$CLAUDE_BIN" ]; then
    echo "❌ 找不到 claude 命令 / claude command not found"
    exit 1
  fi
  local p
  p="$(resolve_prompt)"
  echo "🧪 测试运行 / Test run: ${CLAUDE_BIN} --model ${MODEL} -p '${p}'"
  echo "---"
  "$CLAUDE_BIN" --model "$MODEL" -p "$p"
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
  run)               cmd_run    ;;
  test|dry-run)      cmd_test   ;;
  log|logs)          cmd_log    ;;
  help|-h|--help)    cmd_help   ;;
  *)
    echo "Unknown command: $1"
    cmd_help
    exit 1
    ;;
esac

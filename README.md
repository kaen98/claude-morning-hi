# claude-morning-cron

通过 crontab 定时执行 Claude CLI 提示词。支持 macOS 和 Linux。

[English Version →](README.en.md)

---

## 为什么需要这个

Claude 的用量按**滚动 5 小时窗口**重置。关键在于：**窗口从你第一条消息开始计时**，而不是固定在某个整点。

### 如果 10 点才开始用，会发生什么？

假设你早上没碰 Claude，10:00 开始工作，发出第一条消息：

```
窗口 1：10:00 → 15:00   ← 上午只有 2 小时就到午饭，额度没用完
窗口 2：15:00 → 20:00   ← 下午高强度使用，很容易在 18 点前就打满
窗口 3：20:00 → 01:00   ← 晚上 8 点重置——但你已经下班了
```

实际体验：

- 上午 10–12 点只有 2 小时，窗口额度大概率没耗完就到午饭
- 下午 15:00 重置后，高强度写代码很容易 **在 18 点前就把这 5 小时额度打满**
- 打满之后被限速，偏偏还有 1–2 小时才下班，正卡在最需要用的时候
- 20:00 重置时你已经下班——这整个窗口的额度基本浪费在深夜
- 结果：**下午被卡住，晚上的额度睡觉时才到期**

### 错位有多严重？

| 第一条消息时间 | 窗口重置点 | 问题 |
|--------------|-----------|------|
| 10:00 | 15:00 / **20:00** | 下午易打满被卡，20:00 后额度熬夜才用得上 |
| 09:00 | 14:00 / **19:00** | 19:00 重置，下班后没精力用 |
| **07:01** | **12:01 / 17:01** | **上午/下午/傍晚，三段全覆盖** |

### 默认时间表的设计逻辑

默认的 **07:01 / 12:01 / 17:01** 通过在上班前发一条轻量消息，把窗口锚定到对程序员友好的节奏：

```
窗口 1：07:01 → 12:01   ← 早上开工前预热，上午用满
窗口 2：12:01 → 17:01   ← 午休前触发，下午用满
窗口 3：17:01 → 22:01   ← 下班前触发，晚上用满
```

偏移 1 分钟（`07:01` 而非 `07:00`）是为了避免 cron 触发时间和窗口重置时间恰好重叠的边界问题——确保每次触发都落入新窗口。

---

## 快速开始

```bash
# 开启默认定时任务（07:01、12:01、17:01 发送「早安」）
./claude-morning-cron.sh on

# 查看状态
./claude-morning-cron.sh status

# 关闭
./claude-morning-cron.sh off
```

## 命令

| 命令 | 说明 |
|------|------|
| `on` / `enable` | 开启定时任务 |
| `off` / `disable` | 关闭定时任务 |
| `status` / `st` | 查看当前状态 |
| `test` / `dry-run` | 立即执行一次 |
| `log` / `logs` | 查看日志 |

## 配置

通过环境变量或项目根目录的 `.env` 文件配置：

```bash
# .env
CLAUDE_CRON_MODEL=haiku
# CLAUDE_CRON_PROMPT=早安          # 不设则随机选取
CLAUDE_CRON_SCHEDULE="1 7 * * *|1 12 * * *|1 17 * * *"
CLAUDE_CRON_LOG_DIR=~/.claude/logs
CLAUDE_CRON_TAG=claude-cron-greeting
```

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `CLAUDE_CRON_MODEL` | `haiku` | Claude 模型名 |
| `CLAUDE_CRON_PROMPT` | 随机 | 提示词（不设则从内置 100 条短词中随机选取） |
| `CLAUDE_CRON_SCHEDULE` | `1 7 * * *\|1 12 * * *\|1 17 * * *` | Cron 表达式，`\|` 分隔多个 |
| `CLAUDE_CRON_LOG_DIR` | `~/.claude/logs` | 日志目录 |
| `CLAUDE_CRON_TAG` | `claude-cron-greeting` | Crontab 标识标签 |

## 示例

```bash
# 每小时发送自定义提示词
CLAUDE_CRON_PROMPT="你好" CLAUDE_CRON_SCHEDULE="0 * * * *" ./claude-morning-cron.sh on

# 使用 opus 模型测试
CLAUDE_CRON_MODEL=opus ./claude-morning-cron.sh test
```

## macOS 注意

cron 需要「全盘访问」权限：  
**系统设置 → 隐私与安全 → 全盘访问 → 添加 `/usr/sbin/cron`**

## 方案二：远程定时代理（/schedule）

除了本地 crontab，还可以使用 Claude Code 官方的**远程定时代理**功能。代理在 Anthropic 云端运行，无需本地机器保持在线，也不存在 cron 环境下 OAuth 认证失败的问题。

### 本地 crontab vs 远程代理

| | 本地 crontab | 远程代理 /schedule |
|---|---|---|
| 运行位置 | 本地机器 | Anthropic 云端 |
| 认证 | 依赖本地 CLI 凭据（cron 环境可能失败） | 云端自动处理，无需担心 |
| 机器依赖 | 需要机器开机、cron 服务正常 | 无需本地机器 |
| 最小间隔 | 1 分钟 | 1 小时 |
| 访问本地文件 | 可以 | 不可以（隔离沙箱） |
| GitHub | 不需要 | 需要连接 GitHub 仓库 |
| 管理界面 | 命令行 | https://claude.ai/code/scheduled |

### 前置条件

1. Claude Max / Team / Enterprise 订阅
2. 连接 GitHub 仓库：运行 `/web-setup` 或访问 https://claude.ai/code/onboarding?magic=github-app-setup
3. Claude Code CLI 已安装

### 快速开始

在 Claude Code 中使用 `/schedule` 命令创建，或手动配置。项目提供了预设的提示词文件：

```bash
# 查看提示词文件
cat PROMPT.md
```

### 创建远程代理

在 Claude Code 中执行 `/schedule`，按引导创建。推荐配置：

| 参数 | 推荐值 | 说明 |
|------|--------|------|
| 名称 | `morning-greeting-07` | 按时段命名 |
| Cron (UTC) | `1 23 * * *` | 对应北京时间 07:01 |
| 模型 | `claude-haiku-4-5-20251001` | 轻量模型，节省 token |
| 提示词 | 见 `PROMPT.md` | 一句话即可 |

默认三个时段的 UTC cron 表达式（Asia/Shanghai UTC+8）：

| 本地时间 | UTC 时间 | Cron 表达式 |
|---------|---------|------------|
| 07:01 | 23:01 (前一天) | `1 23 * * *` |
| 12:01 | 04:01 | `1 4 * * *` |
| 17:01 | 09:01 | `1 9 * * *` |

### 管理远程代理

- **查看所有代理**：在 Claude Code 中运行 `/schedule` → 选择 List
- **手动触发**：`/schedule` → 选择 Run now
- **修改配置**：`/schedule` → 选择 Update
- **删除代理**：访问 https://claude.ai/code/scheduled
- **切换回本地方案**：`./claude-morning-cron.sh on`

---

## 依赖

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)（`claude` 命令可用）
- 本地方案：`bash` 4+、`crontab`
- 远程方案：GitHub 仓库连接、Claude Max/Team/Enterprise 订阅

# claude-morning-cron

通过 crontab 定时执行 Claude CLI 提示词，操控 5 小时用量窗口在你需要时重置。支持 macOS 和 Linux。

[English Version →](README.en.md)

> **替代方案：** Claude Code 现已原生支持定时任务，访问 https://claude.ai/code/scheduled 即可配置，无需本地 cron。下方的「为什么」章节仍然适用于理解窗口机制。

---

## 为什么需要这个

Claude Code 的用量按**滚动 5 小时窗口**重置。窗口从你第一条消息开始计时，并**向下取整到整点**（如 8:30 发消息，窗口从 8:00 开始算）。

### 不做预热 vs 做预热

```
            6am    7     8     9    10    11    12    1pm    2     3     4     5    6pm
             |     |     |     |     |     |     |     |     |     |     |     |     |

不做预热：            [========== 窗口 1 ==========]
                      工作 ~8:30-11am  ░░ 空等 ░░
                                                   [========== 窗口 2 ==========]
                                                            工作 ~1pm-6pm

          cron 触发
               │
               ▼
做预热：     [========== 窗口 1 ==========]
              ░ 空闲 ░  工作 ~8:30-11am
                                         [========== 窗口 2 ==========]
                                                 工作 ~11am-4pm
                                                                       [== 窗口 3 ==]
                                                                       工作 ~4pm-6pm
```

> 预热后，多挤出一个下午 4 点开始的新窗口。

### 默认时间表

默认的 **07:01 / 12:01 / 17:01** 把窗口锚定到对程序员友好的节奏：

```
窗口 1：07:01 → 12:01   ← 早上开工前预热，上午用满
窗口 2：12:01 → 17:01   ← 午休前触发，下午用满
窗口 3：17:01 → 22:01   ← 下班前触发，晚上用满
```

偏移 1 分钟（`07:01` 而非 `07:00`）避免触发时间和窗口边界重叠。

---

## 快速开始

```bash
git clone https://github.com/<your-user>/claude-morning-cron.git
cd claude-morning-cron

# 开启默认定时任务
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

---

## 关于用量窗口

一些关于 Claude Code 5 小时窗口的机制细节（截至 2026 年 4 月）：

- **窗口是固定区间**：一旦锚定，边界不会因使用量变化而移动
- **向下取整到整点**：8:15 发消息，窗口从 8:00 开始算
- **跨产品共享**：claude.ai、Claude Code、Claude Desktop 共用同一个额度池
- **按 token 计费，不是消息数**：Extended Thinking 和工具调用比普通对话消耗更快
- **额外有 7 天周限额**：与 5 小时窗口独立计算，互不影响

## 常见问题

**会浪费额度吗？**
一条 Haiku「hi」，无工具、无上下文，几乎零消耗。

**已经被限速了还有用吗？**
有用。请求仍会到达 Anthropic 服务器，窗口照样锚定。

**不想用 cron，有其他方式吗？**
有。Claude Code 原生支持定时任务：https://claude.ai/code/scheduled ，无需本地配置。

---

## 代理支持

crontab 环境不会继承终端的代理设置。如果你的网络需要通过代理访问 Claude API，脚本会在执行 `on` 时**自动捕获**当前终端的代理变量（`http_proxy`、`https_proxy` 等）并写入 crontab 条目。

- 无代理环境：无需任何配置，不受影响
- 有代理环境：确保在代理已生效的终端中运行 `./claude-morning-cron.sh on`
- 代理变更后：重新运行 `on` 即可更新

## 排障

### cron 执行报 403

```
Failed to authenticate. API Error: 403 {"error":{"type":"forbidden","message":"Request not allowed"}}
```

这通常**不是认证问题**，而是 crontab 环境缺少代理变量，导致请求无法到达 Claude API。解决方法：

1. 确认终端中 `claude -p "hi"` 能正常执行
2. 在**代理已生效**的终端中重新运行 `./claude-morning-cron.sh on`
3. 用 `crontab -l` 确认条目中包含 `http_proxy=...` 等变量

### macOS cron 无权限

cron 需要「全盘访问」权限：
**系统设置 → 隐私与安全 → 全盘访问 → 添加 `/usr/sbin/cron`**

### 找不到 claude 命令

确保 Claude Code CLI 已安装且在 PATH 中：

```bash
which claude         # 确认路径
claude -p "hi"       # 确认能执行
```

脚本会依次查找 `claude`、`~/.local/bin/claude`、`/usr/local/bin/claude`。

## 依赖

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)（`claude` 命令可用）
- `bash` 4+、`crontab`

## License

[MIT](LICENSE)

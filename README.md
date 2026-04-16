# Human-Like Memory Skill

通用长期记忆 Skill，可用于召回历史对话、搜索旧上下文、保存稳定偏好和关键决策。

这个版本面向 Hermes Agent 和其他可运行 `SKILL.md + Node.js 脚本` 的平台，不依赖任何平台私有配置目录。

## 能力

- 记忆召回：根据当前问题召回相关历史上下文
- 记忆搜索：按主题检索过去的记忆
- 记忆保存：保存单轮或批量对话到 Human-Like Memory
- 平台无关：支持 Hermes 配置，也支持通用环境变量和 CLI flags

## 快速开始

### Hermes Agent

如果你希望 Hermes 直接把 Human-Like Memory 作为原生 `memory.provider` 使用，有两种方式：

#### 方式 A：直接执行安装命令

```bash
curl -fsSL https://cdn.jsdelivr.net/npm/@humanlikememory/human-like-mem-hermes-plugin@latest/install.sh | bash
```

#### 方式 B：先安装 skill，再让 Hermes / Agent 执行本地 setup 脚本

如果这个 skill 已经安装到 Hermes，会话里可以直接执行本地脚本：

```bash
bash ~/.hermes/skills/memory/human-like-memory/scripts/setup-hermes-provider.sh
```

这个脚本会从 npm 拉取 Hermes provider 包，然后完成接线和配置写入；用户不需要再手动执行外部的 `curl | bash`。

上面两种方式最终都会：

- 把 provider 挂到 `~/.hermes/hermes-agent/plugins/memory/humanlike`
- 自动把 `~/.hermes/config.yaml` 里的 `memory.provider` 切换成 `humanlike`

安装完成后，重启 Hermes gateway 或当前 Hermes 进程。

如果你只是把这个仓库当作 skill 复制到 `~/.hermes/skills/human-like-memory`，它本身不会在“安装时”自动切换 Hermes 的 `memory.provider`；需要再显式运行一次本地 setup 脚本，或让 Agent 在会话中执行它。

### Hermes Skill 模式

1. 把目录复制到 `~/.hermes/skills/human-like-memory`
2. 配置 API Key

```bash
hermes config set HUMAN_LIKE_MEM_API_KEY "mp_xxx"
```

3. 配置非敏感参数（可选）

```bash
hermes config set skills.config.human-like-memory.base_url "https://plugin.human-like.me"
hermes config set skills.config.human-like-memory.user_id "default-user"
hermes config set skills.config.human-like-memory.agent_id "main"
hermes config set skills.config.human-like-memory.memory_limit_number "6"
hermes config set skills.config.human-like-memory.min_score "0.1"
```

4. 验证脚本

```bash
node ~/.hermes/skills/human-like-memory/scripts/memory.mjs config
```

### 其他平台 / 手动运行

```bash
export HUMAN_LIKE_MEM_API_KEY="mp_xxx"
export HUMAN_LIKE_MEM_BASE_URL="https://plugin.human-like.me"
export HUMAN_LIKE_MEM_USER_ID="default-user"
export HUMAN_LIKE_MEM_AGENT_ID="main"
```

然后直接执行：

```bash
node scripts/memory.mjs config
node scripts/memory.mjs recall "我最近在推进什么项目"
node scripts/memory.mjs save "我偏好北京时间" "收到，我会记住这一点"
```

## CLI 参数

脚本除环境变量外，还支持显式参数：

```text
--base-url <url>
--user-id <id>
--agent-id <id>
--scenario <name>
--memory-limit <number>
--min-score <float>
--timeout-ms <number>
--recall-enabled <true|false>
--add-enabled <true|false>
--auto-save-enabled <true|false>
--save-trigger-turns <number>
--save-max-messages <number>
```

示例：

```bash
node scripts/memory.mjs recall "recent roadmap decisions" \
  --user-id "demo-user" \
  --agent-id "main" \
  --memory-limit "8" \
  --min-score "0.2"
```

## 常用命令

```bash
# 检查配置
node scripts/memory.mjs config

# 召回 / 搜索记忆
node scripts/memory.mjs recall "上次的路线图决策"
node scripts/memory.mjs search "命名偏好"

# 保存单轮
node scripts/memory.mjs save "我默认使用 UTC+8" "收到"

# 批量保存
echo '[{"role":"user","content":"你好"},{"role":"assistant","content":"你好！"}]' | \
  node scripts/memory.mjs save-batch
```

## 配置项

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `HUMAN_LIKE_MEM_API_KEY` | secret | - | Human-Like Memory API Key |
| `HUMAN_LIKE_MEM_BASE_URL` | string | `https://plugin.human-like.me` | 服务地址 |
| `HUMAN_LIKE_MEM_USER_ID` | string | `default-user` | 用户隔离标识 |
| `HUMAN_LIKE_MEM_AGENT_ID` | string | `main` | Agent 隔离标识 |
| `HUMAN_LIKE_MEM_LIMIT_NUMBER` | number | `6` | 单次召回数量 |
| `HUMAN_LIKE_MEM_MIN_SCORE` | number | `0.1` | 最低相关度 |
| `HUMAN_LIKE_MEM_RECALL_ENABLED` | boolean | `true` | 是否允许 recall / search |
| `HUMAN_LIKE_MEM_ADD_ENABLED` | boolean | `true` | 是否允许 save / save-batch |
| `HUMAN_LIKE_MEM_AUTO_SAVE_ENABLED` | boolean | `true` | 是否允许自动批量保存 |
| `HUMAN_LIKE_MEM_SAVE_TRIGGER_TURNS` | number | `5` | 建议的批量保存触发轮数 |
| `HUMAN_LIKE_MEM_SAVE_MAX_MESSAGES` | number | `20` | `save-batch` 单次最多保存消息数 |

## 适配说明

- Hermes 中，secret 放 `~/.hermes/.env`
- Hermes 中，非敏感配置放 `~/.hermes/config.yaml` 的 `skills.config.human-like-memory.*`
- 其他平台直接用环境变量或调用脚本时显式传参

## 安全说明

详见 [SECURITY.md](./SECURITY.md)。

## License

Apache-2.0

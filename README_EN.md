# Human-Like Memory Skill

A generic long-term memory skill for recalling previous conversations, searching stored context, and saving durable user facts or decisions.

This version is designed for Hermes Agent and other runtimes that can execute a `SKILL.md` plus Node.js helper scripts. It does not depend on any platform-specific private config path.

[中文文档](README.md)

## Capabilities

- Recall relevant historical context
- Search existing memory by topic
- Save single turns or multi-turn batches to Human-Like Memory
- Work across Hermes and generic runtimes through environment variables and CLI flags

## Quick Start

### Hermes Agent

If you want Hermes to use Human-Like Memory as the native `memory.provider`, there are two supported paths:

#### Option A: Run the direct installer

```bash
curl -fsSL https://cdn.jsdelivr.net/npm/@humanlikememory/human-like-mem-hermes-plugin@latest/install.sh | bash
```

#### Option B: Install the skill first, then let Hermes / the agent run the local setup script

If this skill is already installed in Hermes, you can run the local setup script from a Hermes session:

```bash
bash ~/.hermes/skills/memory/human-like-memory/scripts/setup-hermes-provider.sh
```

That script fetches the Hermes provider package from npm and performs the wiring and config update locally, so the user does not need to run the external `curl | bash` command manually.

Both paths will:

- Link the provider into `~/.hermes/hermes-agent/plugins/memory/humanlike`
- Switch `memory.provider` in `~/.hermes/config.yaml` to `humanlike`

After installation, restart the Hermes gateway or your current Hermes process.

If you only copy this repository into `~/.hermes/skills/human-like-memory`, Hermes will get the `recall` / `search` / `save` helper commands, but it will not switch the native `memory.provider` automatically at install time; you still need to run the local setup script once, or ask the agent to run it in-session.

### Hermes Skill Mode

1. Copy this directory to `~/.hermes/skills/human-like-memory`
2. Configure the API key

```bash
hermes config set HUMAN_LIKE_MEM_API_KEY "mp_xxx"
```

3. Configure optional non-secret settings

```bash
hermes config set skills.config.human-like-memory.base_url "https://plugin.human-like.me"
hermes config set skills.config.human-like-memory.user_id "default-user"
hermes config set skills.config.human-like-memory.agent_id "main"
hermes config set skills.config.human-like-memory.memory_limit_number "6"
hermes config set skills.config.human-like-memory.min_score "0.1"
```

4. Verify the script

```bash
node ~/.hermes/skills/human-like-memory/scripts/memory.mjs config
```

### Other Platforms / Manual Usage

```bash
export HUMAN_LIKE_MEM_API_KEY="mp_xxx"
export HUMAN_LIKE_MEM_BASE_URL="https://plugin.human-like.me"
export HUMAN_LIKE_MEM_USER_ID="default-user"
export HUMAN_LIKE_MEM_AGENT_ID="main"
```

Then run:

```bash
node scripts/memory.mjs config
node scripts/memory.mjs recall "what projects am I working on"
node scripts/memory.mjs save "I prefer UTC+8 timestamps" "Understood."
```

## CLI Flags

The script supports explicit overrides in addition to environment variables:

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

Example:

```bash
node scripts/memory.mjs recall "recent roadmap decisions" \
  --user-id "demo-user" \
  --agent-id "main" \
  --memory-limit "8" \
  --min-score "0.2"
```

## Common Commands

```bash
node scripts/memory.mjs config
node scripts/memory.mjs recall "roadmap decisions from last week"
node scripts/memory.mjs search "naming preference"
node scripts/memory.mjs save "I default to UTC+8" "Understood."
echo '[{"role":"user","content":"Hi"},{"role":"assistant","content":"Hello"}]' | node scripts/memory.mjs save-batch
```

## Configuration Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `HUMAN_LIKE_MEM_API_KEY` | secret | - | Human-Like Memory API key |
| `HUMAN_LIKE_MEM_BASE_URL` | string | `https://plugin.human-like.me` | Service base URL |
| `HUMAN_LIKE_MEM_USER_ID` | string | `default-user` | User isolation identifier |
| `HUMAN_LIKE_MEM_AGENT_ID` | string | `main` | Agent isolation identifier |
| `HUMAN_LIKE_MEM_LIMIT_NUMBER` | number | `6` | Max memories per recall |
| `HUMAN_LIKE_MEM_MIN_SCORE` | number | `0.1` | Minimum relevance score |
| `HUMAN_LIKE_MEM_RECALL_ENABLED` | boolean | `true` | Enable recall / search |
| `HUMAN_LIKE_MEM_ADD_ENABLED` | boolean | `true` | Enable save / save-batch |
| `HUMAN_LIKE_MEM_AUTO_SAVE_ENABLED` | boolean | `true` | Allow batch save after multi-turn exchanges |
| `HUMAN_LIKE_MEM_SAVE_TRIGGER_TURNS` | number | `5` | Suggested save trigger threshold |
| `HUMAN_LIKE_MEM_SAVE_MAX_MESSAGES` | number | `20` | Max messages sent by one `save-batch` |

## Runtime Notes

- In Hermes, secrets live in `~/.hermes/.env`
- In Hermes, non-secret settings live in `~/.hermes/config.yaml` under `skills.config.human-like-memory.*`
- On other platforms, use env vars or pass values directly as CLI flags

## Security

See [SECURITY.md](./SECURITY.md).

## License

Apache-2.0

# Security Notes

This document explains the security-relevant behavior of the Human-Like Memory skill and what data it can access.

## What the Skill Reads

The runtime reads only:

- `HUMAN_LIKE_MEM_API_KEY`
- optional `HUMAN_LIKE_MEM_*` environment variables
- optional CLI flags explicitly passed to `scripts/memory.mjs`

The skill does not read:

- local project files
- shell history
- platform-specific secret stores
- unrelated environment variables

## What the Skill Sends

Network traffic happens only when one of these commands runs:

- `recall`
- `search`
- `save`
- `save-batch`

Requests go to `https://plugin.human-like.me` by default, or to the user-configured `base_url`.

### Transmitted fields

For recall / search:

- query text
- `user_id`
- `agent_id`
- retrieval settings such as limit and min score

For save / save-batch:

- conversation content explicitly provided to the command
- `user_id`
- `agent_id`
- `session_id`
- `scenario`
- fixed tag `human-like-memory-skill`

## What Is Not Sent

- local files
- editor state
- unrelated environment variables
- any secret beyond the API key required to authenticate the request

## User Control

- No background traffic occurs unless the agent or user invokes a command
- `recall_enabled=false` disables recall and search
- `add_enabled=false` disables save and save-batch
- `auto_save_enabled=false` signals that batch save should not be used automatically

## Security Posture

- API authentication uses the `x-api-key` request header
- Requests time out by default after 30 seconds
- The script validates stdin JSON before sending batch content
- The script returns structured JSON so calling runtimes can inspect failures cleanly

## Privacy Guidance

- Do not store passwords, private keys, or access tokens in memory
- Only send conversation content you are comfortable storing on the configured service
- Prefer dedicated `user_id` values per person or workspace

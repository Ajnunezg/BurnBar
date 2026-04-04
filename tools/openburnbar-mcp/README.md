# OpenBurnBar local MCP (Codex, Claude, Cursor)

Read-only access to your **OpenBurnBar SQLite** database (`conversations`, `token_usage`, `chat_messages`) so MCP-capable clients can search transcripts and usage without the in-app assistant’s trimmed system prompt.

## Setup

```bash
cd tools/openburnbar-mcp
./setup.sh
```

This helper is an optional developer tool, not part of OpenBurnBar's core runtime or release-critical surface. Its Python dependency is intentionally pinned in `requirements.txt` so the install is reviewable and reproducible.

Optional: `export BURNBAR_DB_PATH="/path/to/openburnbar.sqlite"` if the DB is not under `~/Library/Application Support/OpenBurnBar/`.

## Cursor

1. Open **Cursor Settings → MCP** (or edit your MCP config JSON).
2. Add a server (adjust the absolute paths for wherever you cloned OpenBurnBar):

```json
{
  "mcpServers": {
    "openburnbar-local": {
      "command": "/absolute/path/to/OpenBurnBar/tools/openburnbar-mcp/.venv/bin/python",
      "args": ["/absolute/path/to/OpenBurnBar/tools/openburnbar-mcp/server.py"]
    }
  }
}
```

Restart Cursor. Enable **openburnbar-local** for the chat that should use it.

## Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json` and add the same `mcpServers.openburnbar-local` block under `mcpServers`, then restart Claude Desktop.

## Tools

| Tool | Purpose |
|------|--------|
| `burnbar_resolve_db_path` | Show which DB file is used |
| `burnbar_list_providers` | Distinct `provider` values (e.g. `"Codex"`, `"Claude Code"`) |
| `burnbar_search_conversations` | FTS search over titles + transcripts |
| `burnbar_get_conversation` | Full row + `fullText` for one id |
| `burnbar_recent_usage` | Recent `token_usage` rows |
| `burnbar_chat_messages` | In-app `chat_messages` tail |

## Security

This exposes **local chat transcripts** to any process that can run the MCP server. Use only on your machine and keep MCP config out of shared repos if paths are sensitive.

## Support level

OpenBurnBar treats this as adjacent tooling:

- public and intentionally read-only
- useful for local developer workflows
- not required to build or run the macOS app, daemon, CLI, or editor extension
- best-effort support compared with the core OpenBurnBar surfaces

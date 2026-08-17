# Telaris MCP plugins

Claude Code plugins that connect Claude to a Telaris PCS instance over MCP. Replaces the
`curl | bash` installers previously served from `https://<host>/mcp/`.

This repository is a **plugin marketplace** containing two plugins:

| Plugin | MCP servers | Who it's for |
|---|---|---|
| `telaris-pcs` | `telaris-erp`, `telaris-docs` | Everyone with MCP access |
| `telaris-pcs-admin` | `telaris-admin` | System administrators only |

They are separate plugins on purpose: every MCP server declared by a plugin starts when that
plugin is enabled, and the `admin` toolset rejects non-sysadmins. Bundling it with `telaris-pcs`
would leave most users with one permanently failing server in `/plugin` → Errors.

## Install

```shell
/plugin marketplace add telarisas/pcs-mcp-plugin
/plugin install telaris-pcs@telaris
```

Claude Code prompts for two values on install:

- **PCS hostname** — e.g. `pcs.telaris.no` (default) or `pcs85.telaris.no`
- **MCP auth key** — your personal key, stored in the macOS Keychain rather than `settings.json`

Get the auth key by logging in to your PCS instance and opening **`/mcp`**. It's the long value
in the install command shown there. If `/mcp` redirects you to the dashboard, you don't have MCP
access yet — see [Access](#access) below.

Non-interactively, for scripted setup:

```shell
claude plugin install telaris-pcs@telaris \
  --config host=pcs85.telaris.no \
  --config token=<auth-key>
```

If the install summary says `Run /reload-plugins to activate.`, run it.

## How the token reaches the server

`plugin.json` declares the two values under `userConfig`; `.mcp.json` interpolates them into the
endpoint URL:

```json
{
  "mcpServers": {
    "telaris-erp": {
      "type": "http",
      "url": "https://${user_config.host}/mcp/action/${user_config.token}/erp"
    }
  }
}
```

Nothing secret is committed to this repository. Because `token` is marked `"sensitive": true`,
Claude Code stores it in the macOS Keychain (or `~/.claude/.credentials.json` elsewhere), not in
`~/.claude/settings.json`.

Values are only read from user settings, the `--settings` flag, and managed settings — never from
a project's `.claude/settings.json`. A cloned repo cannot inject a different host or token.

## Access

MCP access is controlled per instance by system settings (`mcp.alloweduserids`,
`mcp.allowadmins`, `mcp.allowprojectleaders`) and writes by `mcp.allowwrite`. System
administrators always have access. See the
[Systeminnstillinger wiki page](https://wiki.telaris.no/index.php/Systeminnstillinger#MCP).

## Known limitations

- **One instance per install.** A plugin can only be installed once, so `host` is a single value.
  Users who work across several instances need the planned `mcp.telaris.no` OAuth gateway, which
  addresses each instance as its own resource URI.
- **The token is in the URL path.** That's what the current endpoint accepts, so it lands in
  access logs. Moving to an `Authorization: Bearer` header is a small endpoint change and would
  let this plugin use `headers` instead of `url`.
- **Claude Code only.** Codex can't handshake with this endpoint natively and still needs the
  `mcp-remote` bridge; Claude Desktop doesn't read Claude Code plugins. Keep the existing
  installers for those clients.

## Updating

Bump `version` in the plugin's `.claude-plugin/plugin.json` and push. Users pick it up with
`/plugin marketplace update`.

## Local development

```shell
claude --plugin-dir ./plugins/telaris-pcs
claude plugin validate ./plugins/telaris-pcs
```

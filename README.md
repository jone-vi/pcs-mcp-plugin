# Telaris MCP plugins

Connect Claude to a Telaris PCS instance over MCP. Replaces the `curl | bash` installers
previously served from `https://<host>/mcp/`.

This repository is a **plugin marketplace** for Claude Code containing two plugins, and the
**skills** in it double as uploadable skills for Claude Desktop and claude.ai.

| Plugin | MCP servers | Who it's for |
|---|---|---|
| `telaris-pcs` | `task`, `tag`, `order`, `customer`, `product`, `report`, `docs` | Everyone with MCP access |
| `telaris-pcs-admin` | `admin` | System administrators only |

They are separate plugins on purpose: every MCP server a plugin declares starts when the plugin
is enabled, and the `admin` server rejects non-sysadmins. Bundling it with `telaris-pcs` would
leave most users with one permanently failing server in `/plugin` → Errors.

> **Requires the MCP2 endpoint.** Version 2.x points at `/mcp2/action/…`. On an instance that has
> not deployed it yet, install `v1.0.0` — the last version that talks to `/mcp/action/…` — or wait
> for the deployment. `whoami` failing on every server right after install is the symptom.

## One server per domain

MCP1 offered two coarse toolsets, `erp` and `docs`. `erp` alone cost about 15.7k tokens of tool
schemas on **every** request, whether or not the conversation was about orders.

MCP2 splits that by domain, so a client pays only for what it loaded. `task` is the largest at
~20 kB of `tools/list`; the rest are 5–16 kB. Disable the servers you do not use — `/mcp` in
Claude Code lists them individually — and the tokens go with them.

The old combined surface is still reachable if you want it: `…/mcp2/action/<token>/erp` serves
every business domain in one server, and an empty segment serves everything your login may use.
Neither is what the plugin ships.

## Install

```shell
/plugin marketplace add jone-vi/pcs-mcp-plugin
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

## Skills

Two skills ship with `telaris-pcs`. They exist because a tool description is paid on every
request while a skill body is loaded only when it's relevant — so the long-form "how this
subsystem actually behaves" material belongs in a skill, not in twenty tool descriptions.

| Skill | Covers |
|---|---|
| `telaris-report-authoring` | The report engine: the one-result-set rule, `${PARAM}` placeholders, `@`-annotation column formatting, output targets, report templates |
| `telaris-search` | The query engine: how filters combine, the `task_search` defaults that silently narrow results, regex and user filters, sorting, paging, `countOnly`/`countBy`, custom fields |

In Claude Code they load automatically with the plugin. Claude picks them up when relevant, or
you can invoke one directly as `/telaris-pcs:telaris-search`.

### Claude Desktop and claude.ai

Neither reads Claude Code plugins, but both take uploaded skills — and the skills are useful
there because they describe the system, not the client. Build the archives:

```shell
./bin/build-skills.sh          # -> dist/telaris-search.zip, dist/telaris-report-authoring.zip
```

Then **Settings → Capabilities → Skills → Upload skill** and pick a ZIP. The script enforces the
uploader's two limits that Claude Code does not (name ≤ 64 characters, description ≤ 200), so a
skill that builds here will upload.

Pair them with the MCP servers as **custom connectors** — Settings → Connectors → Add custom
connector — one per domain you want, using the same URL shape the plugin uses:

```
https://<host>/mcp2/action/<auth-key>/task
https://<host>/mcp2/action/<auth-key>/report
```

Because the auth key is a path segment, no OAuth configuration is needed. Treat those URLs as
credentials.

## How the token reaches the server

`plugin.json` declares the two values under `userConfig`; `.mcp.json` interpolates them into each
endpoint URL:

```json
{
  "mcpServers": {
    "telaris-task": {
      "type": "http",
      "url": "https://${user_config.host}/mcp2/action/${user_config.token}/task"
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
administrators always have access. Authoring reports additionally requires admin rights, and
`kanban_search` requires the TASKBRD licence. See the
[Systeminnstillinger wiki page](https://wiki.telaris.no/index.php/Systeminnstillinger#MCP).

A tool you may not use is not advertised: role and licence gates are applied when the server
registers its tools, so a refused tool is absent from `tools/list` rather than failing when
called.

## Calling the endpoint by hand

MCP2 requires a session, so a raw `curl` takes two calls — `initialize` first, then reuse the
`Mcp-Session-Id` it returns:

```shell
curl -sD- -o/dev/null -X POST "https://$HOST/mcp2/action/$TOKEN/task" \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{
        "protocolVersion":"2025-03-26","capabilities":{},
        "clientInfo":{"name":"curl","version":"1"}}}' | grep -i mcp-session-id

curl -s -X POST "https://$HOST/mcp2/action/$TOKEN/task" \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -H "Mcp-Session-Id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
```

Every failure comes back as JSON with a real status code — 401 for a bad token, 403 for a login
or server you may not use, 400 for a server that does not exist. MCP1 answered those with HTTP
200 and an HTML body, which clients reported as "Unexpected content type" while discarding the
reason.

## Known limitations

- **One instance per install.** A plugin can only be installed once, so `host` is a single value.
  Users who work across several instances need the planned `mcp.telaris.no` OAuth gateway, which
  addresses each instance as its own resource URI.
- **The token is in the URL path.** That's what the endpoint accepts today, so it lands in access
  logs. An `Authorization: Bearer` header is a small endpoint change and would let this plugin
  use `headers` instead of `url`.
- **Codex** can't handshake with this endpoint natively and still needs the `mcp-remote` bridge.

## Updating

Bump `version` in the plugin's `.claude-plugin/plugin.json` and push. Users pick it up with
`/plugin marketplace update`.

## Local development

```shell
claude --plugin-dir ./plugins/telaris-pcs
claude plugin validate ./plugins/telaris-pcs --strict
./bin/build-skills.sh
```

The server side lives in the PCS repository under `application/mcp2/` — `SPEC.md` for the design,
`STEPS.md` for the plan, `tests/` for the verification harnesses.

# Telaris MCP plugins

Connect Claude to a Telaris PCS instance over MCP. Replaces the `curl | bash` installers
previously served from `https://<host>/mcp/`.

This repository is a **plugin marketplace** for Claude Code containing two plugins, and the
**skills** in it double as uploadable skills for Claude Desktop and claude.ai.

| Plugin | MCP server | Tools | Who it's for |
|---|---|---|---|
| `telaris-pcs` | `pcs` | tasks, kanban, tags, orders, customers, products, custom reports, the Telaris docs | Everyone with MCP access |
| `telaris-pcs-admin` | `admin` | `genesis_update` | System administrators only |

They are separate plugins on purpose: every MCP server a plugin declares starts when the plugin
is enabled, and the `admin` server rejects non-sysadmins. Bundling it with `telaris-pcs` would
leave most users with one permanently failing server in `/plugin` → Errors — and it would give
every sysadmin the instance-upgrade tool without their ever asking for it.

> **Requires the MCP2 endpoint.** Version 2.x and 3.x point at `/mcp2/action/…`. On an instance
> that has not deployed it yet, install `v1.0.0` — the last version that talks to `/mcp/action/…`
> — or wait for the deployment. `whoami` failing right after install is the symptom.

## One server, not seven

**3.0.0 is one server where 2.x was seven.** If you are upgrading, that is the whole change: the
tools, their names and their behaviour are identical. `/mcp` will show `telaris-pcs` where it
showed `telaris-task`, `telaris-tag` and five more.

The seven existed to save context. MCP1 offered two coarse toolsets, and `erp` alone cost about
15.7k tokens of tool schemas on **every** request, whether or not the conversation was about
orders — so splitting by domain let a client pay only for the domains it loaded.

That reasoning was correct about the server and wrong about the client. Claude Code **defers tool
definitions**: only tool names and each server's instructions load at session start, and a tool's
full description and schema are fetched when Claude reaches for it. Measured against a live
instance:

| | Tools | Loaded at session start |
|---|--:|--:|
| The seven servers of 2.x | 47 | **3 948 b** |
| `pcs` + `admin` in 3.0.0 | 37 | **2 494 b** |

One server is not merely as cheap as seven, it is **cheaper** — because seven servers meant seven
copies of the `whoami` and `object_read` names and seven instructions blocks, and collapsing them
pays each once. Splitting to save context was costing context.

What you get for it: one connection instead of seven, one handshake at startup instead of seven,
and one sign-in when OAuth arrives instead of seven. What you give up: you can no longer disable
`order` and keep `task` — the granularity is gone, and so are the `erp` bundle and the
everything-you-may-use endpoint that 2.x left reachable by hand. Those URLs now answer 400.

If your client does *not* defer tool definitions, it pays the full ~68 kB of `tools/list` on every
request with nothing narrower to fall back to. Claude Code defers; Claude Desktop and claude.ai
are unmeasured.

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

Five skills ship with `telaris-pcs`. A skill is chosen from its name and one line, and its body
loads only when Claude decides it is relevant — so the long-form "how this subsystem actually
behaves" material belongs in a skill rather than in twenty tool descriptions, where it would be
read only after the tool is already the candidate. They are written for end users, and they encode
the engines' real quirks rather than describing them optimistically.

| Skill | Covers |
|---|---|
| `custom-reports` | The report engine: the one-query/many-`SET` rule, `${PARAM}` and `%USERID%` variables, `@`-annotation column formatting, output targets, and the draft → create → run → refine loop. Five worked SQL examples |
| `pdf-templates` | PDF layouts through Html2Pdf: table-only layout, the `page`/`page_header`/`page_footer` structure, what CSS works and the long list that doesn't, and the report-template variable scope |
| `dashboard-widgets` | Dashboard cards: the query → template → chart pipeline, widget-scoped CSS/JS, fail-soft rendering |
| `phptal` | The shared template syntax — `${...}`, `tal:`, `metal:`, `i18n:` — and the PCS filters. The other template skills defer to it |
| `record-search` | The MCP query engine: how filters combine, the `task_search` defaults that silently narrow results, regex and `"me"` filters, sorting, paging, `countOnly`/`countBy`, and tag-type custom fields |

They cross-reference each other by name — a report PDF pulls in `custom-reports` for the query
and `pdf-templates` for the layout — so installing all of them is better than picking one. See
[`plugins/telaris-pcs/skills/README.md`](plugins/telaris-pcs/skills/README.md) for how they fit
together and where each fact came from.

In Claude Code they load automatically with the plugin. Claude picks them up when relevant, or
you can invoke one directly as `/telaris-pcs:custom-reports`.

### Claude Desktop and claude.ai

Neither reads Claude Code plugins, but both take uploaded skills — and the skills are useful
there because they describe the system, not the client. Build the archives:

```shell
./bin/build-skills.sh          # -> dist/custom-reports.zip, dist/pdf-templates.zip, ...
```

Then **Settings → Capabilities → Skills → Upload skill** and pick a ZIP. Each archive has the
skill's folder as its root, with its `references/` and `examples/` inside, which is the layout the
uploader wants. The script checks that the folder name matches the frontmatter `name` — the
uploader rejects a mismatch — and reports each description's length against the documented
200-character limit, which every skill here exceeds; if an upload is ever refused for that
reason, the descriptions are where to look first.

Pair them with the MCP server as a **custom connector** — Settings → Connectors → Add custom
connector — using the same URL the plugin uses:

```
https://<host>/mcp2/action/<auth-key>/pcs
```

Because the auth key is a path segment, no OAuth configuration is needed. Treat those URLs as
credentials.

## How the token reaches the server

`plugin.json` declares the two values under `userConfig`; `.mcp.json` interpolates them into each
endpoint URL:

```json
{
  "mcpServers": {
    "telaris-pcs": {
      "type": "http",
      "url": "https://${user_config.host}/mcp2/action/${user_config.token}/pcs"
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
curl -sD- -o/dev/null -X POST "https://$HOST/mcp2/action/$TOKEN/pcs" \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{
        "protocolVersion":"2025-03-26","capabilities":{},
        "clientInfo":{"name":"curl","version":"1"}}}' | grep -i mcp-session-id

curl -s -X POST "https://$HOST/mcp2/action/$TOKEN/pcs" \
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
- **No per-domain granularity.** 3.0.0 serves one server, so there is no way to mount tasks
  without also mounting orders. On a deferring client that costs almost nothing; on one that does
  not defer, it costs the full `tools/list`.
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

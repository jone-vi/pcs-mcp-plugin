# Telaris MCP plugins

Connect Claude to a Telaris PCS instance over MCP. Replaces the `curl | bash` installers
previously served from `https://<host>/mcp/`. Claude signs in through your browser — there is
no key to copy and nothing to paste.

This repository is a **plugin marketplace** for Claude Code containing two plugins, and the
**skills** in it double as uploadable skills for Claude Desktop and claude.ai.

| Plugin | MCP server | Tools | Who it's for |
|---|---|---|---|
| `telaris-pcs` | `erp` | tasks, kanban, tags, orders, customers, products, custom reports, the Telaris docs | Everyone with MCP access |
| `telaris-pcs-admin` | `admin` | `genesis_update` | System administrators only |

They are separate plugins on purpose: every MCP server a plugin declares starts when the plugin
is enabled, and the `admin` server rejects non-sysadmins. Bundling it with `telaris-pcs` would
leave most users with one permanently failing server in `/plugin` → Errors — and it would give
every sysadmin the instance-upgrade tool without their ever asking for it.

> **Requires a recent PCS.** `4.0.0` carries no credential at all and expects the instance to
> run the OAuth authorization server from the server-side revisions
> `application/mcp/revisions/100-bearer-then-oauth.md` and `010-mcp-consent.md`. Against an
> instance that predates them the install fails at the first connection with a 401 and no way to
> sign in; the fix is to update the instance, or to stay on `3.2.0` until you can.

## What changed

**4.1.0 writes the hostname into the plugin and drops the `host` setting.** The URL in
`.mcp.json` names `pcs.telaris.no` outright.

The setting existed so that one plugin could serve any instance, and in Claude Code it did:
`${user_config.host}` is interpolated into an `http` server's `url` before the connection is
made. **Claude Desktop does not interpolate it.** Desktop's plugin loader reads `url`, `headers`
and `oauth` from `.mcp.json` and nothing else — there is no `userConfig` layer on that path and
nothing to prompt with — so it took the placeholder literally, offered
`https://${user_config.host}/mcp/action/erp` as a custom connector, and failed on the first
request with *"Couldn't register with telaris-pcs's sign-in service"*. That message names the
step it reached, not the fault: the hostname does not resolve, so discovery, registration and
everything after it fail alike.

So the setting was never portable configuration — it was configuration that worked in one of the
two clients that read this file, and silently produced a broken connector in the other. A literal
URL works in both. What it costs is that this repository now names one instance: pointing it
somewhere else is an edit and a version bump rather than a prompt.

**4.0.0 drops the auth key. Claude signs in with OAuth instead.** There is one setting left —
the hostname — and the first connection opens a browser tab on your instance, where you log in
as yourself and choose whether this connection may write. Claude keeps its own token from there,
scoped to that one decision and revocable from `/mcp` without touching your password.

That is a different credential, not a better-carried one. The auth key was your login: derived
from your password, valid for as long as `login.expiredays` (60 days by default), good for
everything you can do, and impossible to revoke without changing the password. An OAuth token is
issued to one client, records whether writes were granted, and dies when you say so.

**This is a breaking upgrade.** The `token` setting is gone, so `/plugin marketplace update`
followed by a reload will send you through the browser flow once. Nothing on the server side
changed for the old key — it still works, and a `3.2.0` install that you do not update keeps
running.

**The server is named `erp` now, not `pcs`.** `/mcp/action/pcs` is an alias and keeps answering,
so this is invisible unless you wired a URL by hand. The name says which of the instance's two
servers this is; the old one named the instance, which was true of `admin` too.

**3.2.0 moved the auth key out of the URL and into an `Authorization: Bearer` header**, and
**3.1.0 moved the endpoint from `/mcp2/action` to `/mcp/action`.** Both still work.

## One server, not seven

**3.0.0 was one server where 2.x was seven.** If you are upgrading from 2.x, that is the change
that matters: the tools, their names and their behaviour are identical. `/mcp` will show
`telaris-pcs` where it showed `telaris-task`, `telaris-tag` and five more.

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
request with nothing narrower to fall back to. **Claude Code and Claude Desktop both defer**, at
the same 2 231 bytes — measured 2026-08-24, which is what makes one server the right answer for
both. claude.ai is still unmeasured, and so is `mcp-remote`, which no longer sits in front of Desktop
now that the script route it bridged for is gone.

## Install

```shell
/plugin marketplace add jone-vi/pcs-mcp-plugin
/plugin install telaris-pcs@telaris
```

There is nothing to fill in. The instance is `pcs.telaris.no`, written into the plugin.

The first time Claude connects it opens a browser tab there. Log in, decide whether this
connection may make changes, and approve. If the sign-in page redirects you to the dashboard
instead, you don't have MCP access yet — see [Access](#access) below.

If the install summary says `Run /reload-plugins to activate.`, run it. The browser flow still
happens on the first connection — it is a sign-in, not a setting.

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

Pair them with the MCP server. Desktop does read this repository's plugins now, and from `4.1.0`
the connector it offers works unedited: installing `telaris-pcs` prefills *Add custom connector*
with the endpoint URL and you press Add. On `4.0.0` that same dialog was prefilled with an
uninterpolated `${user_config.host}` and could not connect — if you hit that, update the
marketplace and add the connector again.

By hand is the same thing — Settings → Connectors → Add custom connector:

```
https://pcs.telaris.no/mcp/action/erp
```

No key in it. Desktop runs the same OAuth flow the plugin does, in the same browser, against the
same consent screen.

*"Add custom connector"* is a permission a managed or Team/Enterprise account can withhold, and
there is no user-side workaround. There used to be one — a `curl | bash` one-liner from the
instance's `/mcp` page that wrote `claude_desktop_config.json` and bridged through `mcp-remote` —
and it is gone, because what it wrote was your auth key inside a URL. An account without the menu
item has no Desktop route.

## How the plugin reaches the server

`.mcp.json` names the endpoint outright, and that is the whole configuration:

```json
{
  "mcpServers": {
    "telaris-pcs": {
      "type": "http",
      "url": "https://pcs.telaris.no/mcp/action/erp"
    }
  }
}
```

There is no `headers` block and, since `4.1.0`, no `userConfig`. Claude Code sees a `401` with a `WWW-Authenticate` challenge on the
first request, follows it to the instance's protected-resource metadata, registers itself with
the authorization server, and runs the browser flow. The token it gets back is its own; it is
stored the way Claude Code stores OAuth credentials for any MCP server, and neither this
repository nor `~/.claude/settings.json` ever holds a secret.

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
`Mcp-Session-Id` it returns. `$TOKEN` here is your MCP auth key: the plugin stopped using it in
`4.0.0`, but the endpoint still accepts it in a `Bearer` header, which is what makes calling by
hand practical at all — an OAuth access token is not something you can conveniently produce in a
shell.

```shell
curl -sD- -o/dev/null -X POST "https://$HOST/mcp/action/erp" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{
        "protocolVersion":"2025-03-26","capabilities":{},
        "clientInfo":{"name":"curl","version":"1"}}}' | grep -i mcp-session-id

curl -s -X POST "https://$HOST/mcp/action/erp" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -H "Mcp-Session-Id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
```

The path form still works and is what an older instance needs — drop the `Authorization` line and
put the key back in the URL as `/mcp/action/$TOKEN/erp`. `pcs` works in place of `erp` everywhere
above; it is the old name of the same server.

Every failure comes back as JSON with a real status code — 401 for a bad token, 403 for a login
or server you may not use, 400 for a server that does not exist. MCP1 answered those with HTTP
200 and an HTML body, which clients reported as "Unexpected content type" while discarding the
reason.

A 401 also carries a `WWW-Authenticate` challenge naming which of the two it was:

```
Bearer realm="Telaris MCP", error="invalid_token", error_description="Invalid or missing access token"
Bearer realm="Telaris MCP", error="invalid_request", error_description="Malformed Authorization header"
```

`invalid_request` means the header was sent and could not be read — a missing `Bearer` prefix is
the usual cause. `invalid_token` means it was read and rejected.

## Known limitations

- **One instance, named in the file.** The endpoint URL is literal since `4.1.0`, so this
  marketplace points at `pcs.telaris.no` and nowhere else; moving it is an edit to `.mcp.json`
  and a version bump. Users who work across several instances need the planned `mcp.telaris.no` OAuth gateway, which
  addresses each instance as its own resource URI.
- **No org-wide deployment.** Every user signs in as themselves, so an administrator still cannot
  add this once for a whole organisation. OAuth removed the shared *secret*, not the per-user
  sign-in.
- **No per-domain granularity.** 3.x serves one server, so there is no way to mount tasks
  without also mounting orders. On a deferring client that costs almost nothing; on one that does
  not defer, it costs the full `tools/list`.
- **Read-only is decided once, at sign-in.** The consent screen asks whether the connection may
  make changes, and the answer is recorded on the token. Changing your mind means revoking the
  connection at `/mcp` and signing in again — a read-only connection's symptom is a missing write
  tool, which does not announce its cause.
- **A password change does not affect an OAuth connection**, which is a change from `3.2.0` and
  worth knowing in both directions: an install that stops working after a password change is one
  still using the auth key.
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

The server side lives in the PCS repository under `application/mcp/` — `SPEC.md` for the server
design, `TOOLS.md` for the tool layer, `STEPS.md` for the plan, `revisions/` for the decisions and
`tests/` for the verification harnesses. It was split across `application/mcp/` and
`application/mcp2/` until 2026-08-24 folded the two together.

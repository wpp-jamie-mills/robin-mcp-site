# robin-mcp

**Book Robin meeting rooms from your chat. robin-mcp is a local MCP server for Claude Desktop and Claude Code that acts as you, with a self-contained Robin sign-in — it needs no other app, and your token lives only in the macOS Keychain.**

Version **0.1.5** · macOS · MCP server for Claude Desktop and Claude Code

- [Install: for people](#install-for-people)
- [Install: for AI agents](#install-for-ai-agents)
- [What you can do](#what-you-can-do)
- [Usage](#usage)
- [Security and privacy](#security-and-privacy)
- [Troubleshooting](#troubleshooting)

---

## Install: for people

Open Terminal and run:

```bash
curl -fsSL https://wpp-jamie-mills.github.io/robin-mcp-site/install.sh | bash
```

Then:

1. The installer downloads robin-mcp, runs `uv sync`, and adds a **robin** entry to Claude Desktop's config (it asks first in a terminal; piped without one, it adds the entry and keeps a backup). Quit and reopen Claude Desktop.
2. In a chat, ask it anything about Robin (e.g. "find a free room"). When sign-in is needed, a card appears — click **Open sign-in page**, then **Allow** on Robin's page.
3. Booking is on by default. Turn it off any time with the settings card ("Enable booking tools"), or `ROBIN_MCP_ALLOW_WRITES=false`.

To update later, run the same command again.

## Install: for AI agents

Use these steps if you are an AI agent installing this for a user.

1. **Check the machine.** macOS and uv (the installer offers to install uv if it is missing).
2. **Run the installer** with this one command. It downloads the release, checks its SHA-256 (nothing runs before the check passes) and installs it. With no terminal it never prompts and answers no to every question. It exits non-zero, with the reason on stderr, if anything fails.

```bash
curl -fsSL https://wpp-jamie-mills.github.io/robin-mcp-site/install.sh | ROBIN_INSTALL_TTY=/dev/null bash -s -- --yes
```

3. **Verify.** Run the installer again with `--status` (after `bash -s --`). It prints the install folder, the version, and whether the “robin” entry is in Claude Desktop.

## Usage

Read tools are always available; booking/room tools are on by default.

- **Rooms:** `robin_find_rooms` (free, bookable rooms for a time window, by building/floor/capacity — or set a default building/floor and omit them, see Configuration), `robin_room_details`, `robin_room_schedule`, `robin_my_bookings`.
- **Book a room:** `robin_book_room` books a room directly — the one thing Robin's official MCP can't do.
- **Cancel a booking:** `robin_cancel_booking` cancels a whole booking you made and **frees the room** — use it to undo a standalone `robin_book_room` booking (give it the `event_id` from `robin_my_bookings`).
- **Add a room to a meeting:** `robin_add_room` attaches a room to an existing calendar meeting; `robin_cancel_room` removes a room from a meeting — **frees the room, keeps the meeting.**
- **People & schedule:** `robin_whoami`, `robin_find_people`, `robin_person`, `robin_working_hours`, `robin_weekly_schedule`, `robin_calendar`, `robin_suggest_rooms`, `robin_notification_settings`.

`robin_add_room`, `robin_cancel_room`, `robin_calendar` and `robin_suggest_rooms` run through **Robin's own hosted MCP** using your token — robin-mcp calls it for you, so you don't add it to your client. (It requests the `bot` scope so your token can drive Robin's MCP for the parts the REST API won't do.)

A room booked **standalone** via `robin_book_room` *is* its own meeting, so `robin_cancel_room` can't remove it — cancel the whole booking with `robin_cancel_booking` instead (that frees the room).

## Configuration

Resolved env → `~/.config/robin-mcp/config.env` → default (or change them on the settings card in Claude Desktop).

| Setting | Key | Default |
|---|---|---|
| Robin organisation (id or slug) | `ROBIN_MCP_ORG` | from your account |
| Enable booking tools | `ROBIN_MCP_ALLOW_WRITES` | on |
| Default building (id) | `ROBIN_MCP_DEFAULT_LOCATION` | — |
| Default floor (level id) | `ROBIN_MCP_DEFAULT_LEVEL` | — |
| Approve bookings | `ROBIN_MCP_APPROVALS` | `chat` |
| Check for updates | `ROBIN_MCP_CHECK_UPDATES` | on |
| Keychain service | `ROBIN_MCP_SERVICE` | `robin-mcp` |

Set a **default building** (and optionally a **default floor**) and a room search that names neither — e.g. *"find a room at 12:00"* — searches there (say Rose Court London, floor 8). Naming a building or floor in the request overrides the defaults. In **Claude Desktop** the settings card shows these as **live dropdowns** — pick your building and floor by name (it fetches them from your account), no ids to look up. Elsewhere, get the ids from `robin_locations` (buildings) and `robin_levels` (floors).

## Tools

| Tool | What it does |
|---|---|
| `robin_auth_status` | Whether you're signed in; org, scopes, token expiry. No secrets. |
| `robin_whoami` | You, your organisations and timezone. |
| `robin_locations` | Your buildings (id, name, timezone, address). |
| `robin_levels` | A building's floors (level id + name, e.g. 8, Ground Floor). |
| `robin_find_rooms` | Free, bookable rooms for a time window. |
| `robin_room_details` | One room: capacity, type, amenities, floor, policies. |
| `robin_room_schedule` | A room's bookings for a period. |
| `robin_my_bookings` | Your room bookings between two times. |
| `robin_find_people` | Search colleagues by name or email. |
| `robin_person` | A colleague's profile and working hours. |
| `robin_working_hours` | Your configured working hours. |
| `robin_weekly_schedule` | Your weekly in-office plan for a building. |
| `robin_notification_settings` | Your Robin notification settings. |
| `robin_book_room` | Book a meeting room directly (standalone). |
| `robin_cancel_booking` | Cancel a whole booking you made and free the room (e.g. a standalone booking). |
| `robin_add_room` | Add a room onto an existing calendar meeting. |
| `robin_cancel_room` | Remove a room from a meeting (frees the room, keeps the meeting). |
| `robin_calendar` | List your calendar meetings (optionally only those with a room). |
| `robin_suggest_rooms` | Suggest bookable rooms for a meeting or by capacity. |

## Security and privacy

- The OAuth token (access + refresh) lives only in the macOS login Keychain; it is never returned by a tool, logged, or written elsewhere. The first Keychain read prompts (Allow / Always Allow).
- Requests go only to `api.robinpowered.com`, `federation-gateway.robinpowered.com` and (for the proxied tools) `mcp.robinpowered.com`, over HTTPS.
- Only pinned REST paths and GraphQL operation documents are sent — no free-form passthrough.
- Sign-in is Robin's own OAuth (auth-code + PKCE, loopback redirect); it never touches another app's session or cookies.
- In Claude Desktop, each booking or cancellation waits for your approval — in the chat, or on an approval card (`ROBIN_MCP_APPROVALS=auto`).

## Troubleshooting

- **A tool says "sign-in needed":** run `robin_sign_in` (or just retry) and approve the Robin page; the card updates when you're done.
- **"missing scope" or org errors:** your sign-in may predate a scope change — run `robin_sign_out` then sign in again.
- **macOS asks to allow Keychain access:** choose Always Allow once; later runs won't ask.
- **Cancelling a standalone booking:** use `robin_cancel_booking` with its `event_id` (from `robin_my_bookings`); `robin_cancel_room` only removes a room from a meeting that stays, so it won't touch a standalone booking.

## Update and remove

- **Update:** run the install command again. It downloads the latest release, verifies its SHA-256, runs `uv sync`, and keeps your settings and your sign-in. robin-mcp also warns you in the chat, once a day, when a newer version is out.
- **Remove:** `curl -fsSL https://wpp-jamie-mills.github.io/robin-mcp-site/install.sh | bash -s -- --uninstall` removes the `robin` entry from Claude Desktop and the install folder (add `--yes` when there is no terminal). Your saved sign-in stays in the Keychain; clear it with `robin_sign_out`, or run the installer again later.
- **Check the install:** `curl -fsSL https://wpp-jamie-mills.github.io/robin-mcp-site/install.sh | bash -s -- --status` prints the version, the launcher and whether the Claude Desktop entry is in place.

---

<sub>Generated from the project README for version 0.1.5. It is rebuilt automatically with each release.</sub>

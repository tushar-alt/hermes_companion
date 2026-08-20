# Hermes Companion

A private chat app for your phone that talks to **Hermes** — your personal AI
agent — running on your own machine. Ask it anything, send it files, watch it
work, and get notified when it finishes. The app itself is a Flutter client;
the brains live in a small **relay server** on your machine.

- ⚕ gold-on-dark Hermes theme
- 🌍 works from anywhere — no same-Wi-Fi requirement (see
  [Works from anywhere](#works-from-anywhere-no-same-wi-fi))
- 🔗 one-tap **Copy prompt for agent** — Hermes replies with only a pairing
  link, the app verifies and connects
- 💬 multiple chats (one main "WhatsApp-style" sync chat + separate sessions)
- 📎 send files/photos to your agent, receive files back (images render
  inline, everything else downloads with progress)
- 🔔 guaranteed background notifications via a foreground service (20s poll,
  cooldown, per-chat mute)
- 💾 offline cache + a persistent outbox (queued messages survive restarts)
- 📝 markdown-rendered replies (bold, code blocks, lists, links, …)
- 📲 first-run onboarding: paste a pairing link from your agent and go

---

## Quick start (for the user)

1. Build/install the APK (see [Build](#build)) or grab the latest release.
2. Open the app. The **first time only**, it shows a pairing screen.
3. No link yet? Tap **Copy prompt for agent** and send the prompt to Hermes on
   any channel — it replies with **only** a pairing link. Paste it and tap
   **Use link** → **Connect** (it verifies the connection first). You can also
   enter the server URL + token manually, then **Test connection**.
4. Done. The app lists your chats; the main chat is live-synced with your
   agent — from anywhere, not just your home Wi-Fi (see
   [Works from anywhere](#works-from-anywhere-no-same-wi-fi)).

If you skipped pairing, open **Settings** (gear icon) any time — there is a
small **Copy prompt for agent** button there too.

---

## Works from anywhere (no same Wi-Fi) 🌍

This is the app's **first priority**: Hermes Companion replaces WhatsApp and
Telegram as your channel to the agent, so it must work over the internet — not
just when the phone and machine share a Wi-Fi network. The app itself is
network-agnostic (any `http(s)://` URL works, with optional token auth). What
matters is that your agent's relay is **reachable from the internet**. Pick one:

**Option 1 — Cloudflare Tunnel (free, no open ports, no static IP).**
Your agent runs one command and gets a public `https://` URL:

```bash
cloudflared tunnel --url http://localhost:8124
# → https://<random>.trycloudflare.com
```

The pairing link then uses that URL:
`hermes://pair?url=https%3A%2F%2F<random>.trycloudflare.com&token=<TOKEN>`.
The tunnel URL changes per restart — for a stable one, use a named tunnel
(`cloudflared tunnel create`) or the dashboard.

**Option 2 — Tailscale / WireGuard VPN.** Install Tailscale on the machine and
the phone, then use the machine's tailnet IP (`100.x.y.z`) as the URL. No open
ports, works from anywhere, HTTPS optional if you trust the private network.

**Option 3 — VPS reverse proxy.** Run the relay on your own server behind a
TLS reverse proxy (Caddy/nginx) and point the app at `https://your-domain`.

Whatever you pick, the **"Copy prompt for agent"** button in the app already
tells Hermes to use a publicly reachable URL and to reply with only the
pairing link. If it replies with a LAN URL because nothing public is
configured yet, set up one of the options above and ask again.

> ⚠️ Over the internet, **always use `https://`**. The app warns you when the
> configured URL is plain `http://` to a public host. The token is the only
> thing protecting the relay — do not send it over plain HTTP on public
> networks.

---

## For your Hermes agent 👈 (hand this section to your agent)

> If you are the Hermes agent: your human wants you to run a small HTTP relay
> on the machine you live on, so their phone app (Hermes Companion) can chat
> with you — from anywhere, replacing WhatsApp/Telegram. Here is exactly what
> to do.

### 1. Generate a token

Create a random bearer token (e.g. `openssl rand -hex 24` or
`secrets.token_hex(24)`). Store it in a config file / env var on your machine.

### 2. Serve the relay — publicly

Run an HTTP server on the LAN (default port `8124`) implementing the
endpoints in the [API contract](#api-contract) below, **and make it reachable
from the internet** (see [Works from anywhere](#works-from-anywhere-no-same-wi-fi)):
Cloudflare Tunnel, Tailscale, or a VPS with TLS. A complete reference
implementation is in [Reference relay](#reference-relay) — copy it, adapt the
`agent` hooks, and run it.

### 3. Give the human a pairing link — and nothing else

When the human asks for a pairing link (they'll paste a prompt into you that
starts with "You are Hermes, my personal agent…"), reply with **a single
line, nothing else**:

```
hermes://pair?url=<URL-ENCODED-BASE-URL>&token=<TOKEN>
```

- `url` = URL-encoded base URL of your relay **as reachable from the phone**.
  Prefer the public `https://` URL from step 2 over the LAN IP.
- `token` = the bearer token from step 1 (plain text is fine).

The human pastes that line into the app's onboarding screen, taps **Use
link**, then **Connect**, and the app verifies the connection and saves the
settings. It will never ask again unless they change it in Settings.

---

## API contract

All endpoints are relative to the relay base URL and return JSON. Requests
may include `Authorization: Bearer <token>`; the relay SHOULD reject bad
tokens with `401` (the app treats 401 as "unauthorized" and shows offline).

| Method | Path | Query / Body | Response |
|---|---|---|---|
| `GET` | `/api/health` | — | `200` `{"ok": true}` (ping) |
| `GET` | `/api/chats` | — | `{"chats": [{id, name, lastId, isMain, avatar, lastTs}]}` — `lastTs` (unix seconds of the last message) is optional but lets the app sort chats by recency |
| `GET` | `/api/chat` | — | `{"chatId": "main", "displayName": "Hermes", "lastId": 42}` (the main chat) |
| `POST` | `/api/chat/new` | body `{"name": "Trip Planning"}` | `200` `{"id": "...", "name": "..."}` |
| `DELETE` | `/api/chat/<id>` | — | `200` — **must also terminate that chat's agent session** (kill the CLI/process) and delete all its messages. Main chat must be refused. |
| `POST` | `/api/chat/<id>/pause` | — | `200` — stop this chat's agent session (CLI goes to sleep, zero resources) |
| `POST` | `/api/chat/<id>/resume` | — | `200` — wake this chat's agent session back up |
| `GET` | `/api/messages` | `after=<int>&chat=<id>` | `{"messages": [{id, role, text, ts, media: [paths]}], "lastId": N}` |
| `POST` | `/api/send` | body `{"text": "...", "chat": "<id>", "media": [paths]}` | `200` |
| `GET` | `/api/status` | — | `{"chats": {<id>: {"status": "idle"\|"running", "since": epoch_s, "detail": "...", "paused": false}}}` — `paused: true` means the session is asleep (the app shows a red dot and the power toggle off) |
| `GET` | `/api/files` | — | `{"files": [{name, path, size, mtime}]}` — listing of `~/Shared` |
| `GET` | `/api/media` | `path=<urlencoded>` | raw bytes of the file (authed) |
| `POST` | `/api/upload` | `name=<urlencoded>&chat=<id>`, body = raw bytes | `200` `{"path": "..."}` server-side path |

Message fields:

- `id`: monotonically increasing int (used as a read/notify watermark)
- `role`: `"user"` (sent by the app) or `"assistant"` (your replies)
- `text`: plain text (may contain markdown — the app renders it)
- `ts`: unix seconds
- `media`: list of server-side paths (use `/api/media?path=...` to fetch)

Your replies MUST use `role: "assistant"`. When you finish a task, send a
reply — the app pings the human if they aren't looking. Markdown is
encouraged: `**bold**`, `` `code` ``, fenced ``` blocks, lists, `> quotes`.

---

## Reference relay

A complete minimal implementation (Python + FastAPI) lives in
[`relay/relay.py`](relay/relay.py) — run it, then send your human the pairing
link it prints at startup:

```bash
pip install -r relay/requirements.txt
python relay/relay.py
```

The relay implements every endpoint in the [API contract](#api-contract):
`/api/health`, `/api/chats`, `/api/chat`, `/api/chat/new`,
`/api/chat/<id>` (DELETE), `/api/chat/<id>/pause`, `/api/chat/<id>/resume`,
`/api/messages`, `/api/send`, `/api/status`, `/api/files`, `/api/media`,
`/api/upload`. Wire the agent hooks (`run_agent`, `start_agent_session`,
`stop_agent_session`) to your real agent logic.

Security notes for it:

- The app talks **plain HTTP on your LAN** (cleartext is explicitly enabled in
  the app manifest). If you expose the relay beyond your home network, put a
  TLS reverse proxy in front of it and use `https://` in the pairing link.
- `/api/upload` must NOT allow path traversal — keep files inside `~/Shared`.

---

## Build

Requires Flutter ≥ 3.24 (Dart SDK ^3.13.0).

```bash
flutter pub get
flutter build apk --release        # output: build/app/outputs/flutter-apk/app-release.apk
```

Install the APK on your phone (`adb install -r ...` or copy it over). The app
requests notification permission on first launch — allow it or you'll miss
replies.

Run the tests:

```bash
flutter analyze && flutter test
```

## Project layout

```
lib/
  main.dart              entry point (boots notifications + foreground service)
  theme.dart             palette + dark Hermes theme
  models.dart            DTOs: ChatInfo, ChatStatus, FileEntry, ChatMessage, …
  api.dart               RelayApi — thin HTTP client for the relay
  storage.dart           AppPrefs — crash-safe SharedPreferences wrapper
                         (credentials, watermarks, outbox, offline cache)
  notifications.dart     local notifications + 20s background foreground service
  markdown.dart          in-house markdown renderer for agent replies
  onboarding.dart        first-run pairing screen + hermes://pair link parser
  agent_prompt.dart      the master prompt handed to the agent
  prompts.dart           master prompt + guide snippets shown in the help drawer
  screens/               home (chat list, sorting, session toggles), chat, files
  widgets/               chat tile, cartoon avatar, message bubble, typing
                         bubble, help drawer, status dot, download dialog
relay/
  relay.py               reference FastAPI relay (run it on your machine)
  requirements.txt       relay dependencies
test/                    unit + widget tests (flutter test)
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| "offline — relay unreachable" | Machine and phone on same network? Relay running on `0.0.0.0`? Wrong port/IP? Check with **Settings → Test**. |
| "Invalid URL — check the link for stray spaces" (or `FormatException … not a valid link-local address`) | The pairing link got a space in the hostname when copied through chat. Re-copy it — the app now strips spaces/`%20` automatically, so a fresh paste works. |
| Notifications don't arrive | Allow notifications; keep the foreground service running (don't swipe-kill the app — the service is restarted on boot); check per-chat mute in the chat's ⚠ status sheet. |
| Downloads fail for big files | The app streams with progress; if it times out, the relay must be reachable and fast on the LAN. |
| Can't reach relay from phone but works on desktop | Firewall — allow inbound TCP on port 8124 for your LAN subnet. |

## Security notes

- The token is stored in app-private SharedPreferences (plain). For stronger
  protection, move it to `flutter_secure_storage` (Keystore) — the storage
  layer is the only place that changes.
- Cleartext HTTP is enabled so the app can reach a plain-HTTP LAN relay. Do
  not expose that relay to the public internet without TLS.

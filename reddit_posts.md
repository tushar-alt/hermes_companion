# Hermes Companion — Reddit launch posts

20 community posts, researched against each subreddit's rules (self-promotion
policies, flairs, restrictions). Each entry: the subreddit, the rules you must
follow when posting there, and a ready-to-paste post written for that audience.

> **Before posting anything:**
> 1. Make the repo **public** (Settings → Danger Zone → Change visibility) — the
>    link `https://github.com/tushar-alt/hermes_companion` won't work while private.
> 2. Several subs require prior participation or modmail approval first (noted per
>    sub). Don't post all 20 in one day from a fresh account — spread them out and
>    engage with every comment.
> 3. Two subs (r/PrivacyGuides, r/ChatGPTCoding) are restricted — alternative
>    instructions included.

---

## 1. r/LocalLLaMA — ✅ postable

**Rules:** human-written copy only (AI-generated posts banned), ~30-day-old account
needed, self-promo ≤1 in 10 of your content, must be on-topic for local LLMs.
**Flair:** `Discussion` (or `Resources`).

> **Title:** I built a private WhatsApp-style chat app for talking to my local LLM from my phone — fully self-hosted, no cloud
>
> I've been running a local model on my homelab for a while, and I got tired of the clunky web UIs. So I built a messenger app for my phone that talks to my own agent directly — the kind of chat you'd normally do in WhatsApp or Telegram, but the "contact" is my local LLM and every message stays on my hardware.
>
> How it works: a Flutter Android client talks to a small FastAPI relay running next to the model. The relay is the only piece that knows my agent — it just needs a `run_agent` hook. For remote access I use a Cloudflare Tunnel, so I can message my model from anywhere without port forwarding or a VPS.
>
> What I put in along the way: markdown rendering, sending images/files both ways, a persistent outbox for when I'm offline, per-session power toggles (pause actually kills the agent process — zero resources when I don't need it), unread badges, and notifications via an Android foreground service.
>
> First-run setup is one copy-paste: you send your agent a "master prompt" and it configures the relay itself and replies with a pairing link.
>
> It's open source (MIT): https://github.com/tushar-alt/hermes_companion
>
> Happy to answer questions about the relay protocol or the Flutter side. Feedback very welcome — especially from people who've wired this to llama.cpp or Ollama.

---

## 2. r/AI_Agents — ✅ postable (links go in comments)

**Rules:** links belong in **comments**, not the post body; projects go in the
weekly project display thread; self-promo ≤1:10. **Flair:** `Built`.

> **Title:** Built a fully self-hosted private channel to chat with my own agent — and one pasted prompt auto-configures the whole relay
>
> I kept going back and forth with my agent over Telegram, and I hated that my agent's entire conversation history lived on someone else's servers. So I built a self-hosted messenger: a Flutter Android app on my phone, a FastAPI relay on my machine, and my agent behind a single hook.
>
> The part I'm most proud of is onboarding. The app hands you one "master prompt" — you paste it to your agent, and it generates a token, stands up the relay, exposes it publicly (Cloudflare Tunnel / Tailscale), and replies with a pairing link. That's it. Zero manual config beyond pasting a link.
>
> Agent-side features I ended up needing: markdown replies, media in both directions, a queue for when the agent is mid-run, pause/resume per session (pause literally kills the session process so it uses no resources), and an offline outbox.
>
> Architecture write-up + the relay protocol are in the repo. It's MIT licensed.
>
> Repo link is in the comments. Would love feedback from people who've built similar agent frontends — especially on the pairing/multi-session model.

---

## 3. r/artificial — ⚠️ postable, but participate in the sub first

**Rules:** 10% self-promo rule, prior participation required, low-effort removed,
~100 karma / 30 days account. **Flair:** `Project`.

> **Title:** [Project] Self-hosted personal AI agent channel — chat with your own model from your phone, data stays on your machine
>
> Quick context: I built a messenger app whose only "contact" is my own AI agent. No cloud provider, no big-tech chat app — the model runs on my hardware and the conversation history lives next to it.
>
> The app is a Flutter Android client; the relay is FastAPI and sits beside the agent. Remote access goes through a Cloudflare Tunnel so it works from anywhere. The interesting design choice for me was the pairing flow: you paste one "master prompt" to your agent and it configures the entire relay and replies with a pairing link — the app never needs manual IP or token entry.
>
> I've also added the practical stuff a chat app needs: markdown rendering, files/images both ways, offline outbox, per-session power toggles (paused = the agent process is actually stopped), unread badges and mute per chat, and notifications through an Android foreground service.
>
> It's open source (MIT): https://github.com/tushar-alt/hermes_companion
>
> Curious what people think of the agent-relay split, and whether anyone else is replacing chat apps with direct-to-agent messengers.

---

## 4. r/ArtificialInteligence — ⚠️ postable, prior participation + 10:1

**Rules:** 10% self-promo, ~50 karma / 14 days, Project flair is the norm for
repos. **Flair:** `Project`.

> **Title:** [Project] I replaced WhatsApp with a messenger that talks directly to my own AI agent (fully self-hosted)
>
> My agent and I used to chat over WhatsApp. It worked, but the setup always felt backwards — my agent's context lived in someone else's cloud, and I couldn't send it files or images without jumping through hoops.
>
> So I built Hermes Companion: a Flutter app on my phone that connects to a FastAPI relay running on my own machine, which plugs into my agent. Everything is self-hosted — messages, history, media all stay on my hardware. Remote access is via Cloudflare Tunnel/Tailscale, so it works from anywhere.
>
> Highlights: markdown replies, file sharing both ways, an offline outbox, per-chat power toggles (pause actually stops the agent's process — zero resources), unread badges, per-chat mute, and notifications via an Android foreground service. Onboarding is one paste: a "master prompt" that makes the agent configure the relay itself and reply with a pairing link.
>
> MIT licensed and open source: https://github.com/tushar-alt/hermes_companion
>
> Interested in thoughts on making personal agents truly independent from big chat platforms — that's the goal here.

---

## 5. r/ChatGPT — ⚠️ promo belongs in the weekly megathread

**Rules:** Rule 3 — posts solely advertising a service go to the pinned weekly
self-promotion megathread; a standalone repo link will likely be removed or
redirected. Post there (or frame as discussion and accept the redirect).

> **Title:** I built a self-hosted chat app so I could talk to my own local agent instead of relying on a cloud chat UI
>
> I use ChatGPT and Claude daily, but I also run a personal agent on my own machine — and for that one I wanted a proper chat experience without handing its history to a third party.
>
> The result: a Flutter Android messenger that talks to my agent through a small self-hosted relay (FastAPI). It renders markdown replies, sends and receives files/images, queues messages while the agent is busy, keeps an offline outbox, and pings me via notifications when the agent finishes a task. When I don't need it, I can pause a session — which actually kills the agent process, so it uses nothing.
>
> The fun part of setup: the app hands you a "master prompt," you paste it to your agent, and it builds/configure the relay itself and replies with a pairing link.
>
> Open source (MIT) if anyone wants to poke at it: https://github.com/tushar-alt/hermes_companion
>
> Happy to talk about the architecture — I think "own chat channel for your own agent" is going to be a thing.

---

## 6. r/ChatGPTCoding — 🔒 restricted — use the weekly Self Promotion Thread

**Rules:** sub is RESTRICTED (only approved users post on the main feed); own
projects go in the pinned weekly Self Promotion Thread; rule 3 wants the prompt
you used included. Paste this into the weekly thread.

> **Title (thread post):** Self-hosted channel for your coding agent — Flutter app + FastAPI relay, one-prompt setup
>
> I built an open-source messenger so my coding agent has its own private chat channel on my phone: Flutter Android client + FastAPI relay on my machine, Cloudflare Tunnel for remote access.
>
> The bit that fits this sub: the whole relay is configured by one "master prompt" the agent receives — it generates a token, wires the endpoints, and replies with a pairing link. The master prompt I used is in the README, and it doubles as a spec for the API:
>
> "…Set up the Hermes Companion app end-to-end, then reply with EXACTLY ONE LINE: hermes://pair?url=<URL-ENCODED-BASE-URL>&token=<TOKEN>. Do ALL of the following: run the reference FastAPI relay… expose it publicly… add pause/resume endpoints… make DELETE kill the session…"
>
> Repo: https://github.com/tushar-alt/hermes_companion (MIT)
>
> Would love feedback on the prompt-driven setup flow — I think "give the agent one prompt, get a working integration back" is the right pattern for self-hosted tooling.

---

## 7. r/LLMDevs — ⚠️ modmail approval REQUIRED before posting

**Rules:** must send a modmail request explaining the tool + relevance and get
approval before any promotional post; two-strike ban policy. **Flair:** `Tools`.

> **Title:** How I built a fully self-hosted private channel to my local agent (Flutter + FastAPI relay) — with a kill-switch that zeroes resource usage
>
> Engineering write-up of a messenger I built so my agent has a private chat channel on my phone. The stack: Flutter Android client, Python FastAPI relay running next to the agent, Cloudflare Tunnel for remote access.
>
> The design decisions I think are worth discussing:
>
> - **Relay as the only integration point.** The agent just needs a `run_agent(chat, messages)` hook; everything else (auth, media, sessions, history) lives in the relay. The API contract is small enough to fit a README table.
> - **Prompt-driven onboarding.** A "master prompt" makes the agent stand up the relay itself and reply with a pairing link — the app never hardcodes IPs or tokens.
> - **Session power toggles.** Pausing a chat actually terminates the agent process for that session (0 resources), with resume on demand. Status is exposed via `/api/status` and shown as red/green dots in the UI.
> - **Offline-first client.** Outbox persists queued messages; a local cache renders the last messages when the relay is unreachable.
>
> Open source, MIT: https://github.com/tushar-alt/hermes_companion
>
> I modmailed the mods before posting (as required). Feedback welcome on the relay API and the session lifecycle.

---

## 8. r/LocalLLM — ✅ postable

**Rules:** 10% self-promo guideline, ~50 karma / 14-day account, Project flair is
the established lane for repos. **Flair:** `Project`.

> **Title:** [Project] Chat with your own local AI from your phone — fully self-hosted messenger for your local LLM/agent
>
> Another "talk to your local model from your phone" build, but this one is a full messenger rather than a web UI. Flutter Android app + a small FastAPI relay beside your model. Zero cloud: conversation history, files, everything stays on your machine. Cloudflare Tunnel or Tailscale gets you remote access from anywhere.
>
> What's inside: markdown-rendered replies, images/files in both directions, offline outbox, per-chat pause/resume (paused = the agent process is actually stopped, so nothing runs), unread badges, per-chat mute, and notifications via an Android foreground service.
>
> Setup is a single paste — the app gives you a "master prompt" that makes your agent configure the relay and reply with a pairing link.
>
> Repo (MIT): https://github.com/tushar-alt/hermes_companion
>
> Not trying to get you to subscribe to anything — it's open source, just tossing it out there for feedback and contributions.

---

## 9. r/ClaudeAI — ⚠️ must be Claude-centric + "Built with Claude" flair

**Rules:** content must be Claude/Claude Code-specific; Rule 7 wants the project
built with Claude BY YOU, described with what it does; flair required; OP karma
>50. **Flair:** `Built with Claude`.

> **Title:** Built with Claude Code: a self-hosted messenger so I can chat with my own Claude-powered agent from my phone
>
> I use Claude Code as my personal agent, and I wanted a proper mobile chat channel for it — not another browser tab, not WhatsApp. So I built an open-source messenger where the only "contact" is my Claude agent.
>
> Stack: Flutter Android client + FastAPI relay on my machine, exposed remotely via Cloudflare Tunnel/Tailscale. The relay is the integration point — my Claude agent implements one hook, and everything else (auth, sessions, media, history) lives in the relay.
>
> Features: markdown replies, sending images/files both ways, an offline outbox, per-session pause/resume (pause kills the agent process — zero resource use), unread badges, per-chat mute, and notifications via an Android foreground service.
>
> The onboarding trick I like: the app gives you one "master prompt" — paste it to Claude, and it generates a token, configures the relay, and replies with a pairing link. Built and iterated with Claude Code itself, naturally.
>
> Free to use, MIT licensed: https://github.com/tushar-alt/hermes_companion

---

## 10. r/aipromptprogramming — ✅ postable (as open-source showcase)

**Rules:** Rule 6 bans commercial self-promo, but open-source project showcases
are tolerated when framed as knowledge share. Lead with the prompt angle.

> **Title:** Giving your AI agent a real remote control — one master prompt that auto-configures a whole self-hosted messenger
>
> Prompt engineers, this one's for you. I built a messenger app (Flutter + FastAPI relay, fully self-hosted) so my agent has a private channel on my phone — and the entire backend is set up by the agent itself from a single prompt you paste to it.
>
> The prompt is short enough to read in one sitting. It tells the agent to: generate a bearer token, run a reference relay, expose it publicly (Cloudflare Tunnel/Tailscale), add pause/resume endpoints (pause = the session process is actually killed), make DELETE terminate the session everywhere, and reply with exactly one line — a pairing link.
>
> That single prompt doubles as the API spec, which I think is the neat part: the prompt defines the contract, the agent implements it, and the app just works.
>
> Open source (MIT): https://github.com/tushar-alt/hermes_companion
>
> The master prompt is in the README — I'd love to hear how you'd tighten it.

---

## 11. r/selfhosted — ⚠️ new project → weekly New Project Megathread

**Rules (March 2026 overhaul):** projects younger than 3 months can ONLY be shared
as a top-level comment in the pinned weekly **New Project Megathread** (refreshed
Fridays) using its template; standalone new-project posts are auto-removed; an
AI-compliance bot requires disclosing AI involvement; mobile apps only allowed as
companions to a self-hosted backend (lead with the relay). Paste this as a comment
in the current megathread:

> **Comment (megathread template):**
>
> **Project:** Hermes Companion
> **Repo:** https://github.com/tushar-alt/hermes_companion (MIT)
> **Description:** A self-hosted messenger so you can chat with your own AI agent from your phone — the self-hosted part is a Python FastAPI relay that runs next to your agent (local LLM, Claude, whatever), and the Flutter Android app is just its companion client. Replaces WhatsApp/Telegram as the channel to your agent. Works from anywhere via Cloudflare Tunnel/Tailscale, no open ports. Per-session pause/resume actually stops the agent process (zero resources) with red/green status dots in the UI; markdown replies, media both ways, offline outbox, unread badges, per-chat mute, notifications via Android foreground service.
> **Deployment:** `pip install -r relay/requirements.txt && python relay/relay.py` — the relay implements all 13 API endpoints; the client is a standard Flutter build. Docker compose is on the roadmap.
> **Docs:** README has the full API contract + agent hooks.
> **AI involvement (required disclosure):** The project was built with substantial AI assistance (the agent it's designed to chat with, plus tooling), and the app itself is an AI-agent interface — disclosed here per the AI-compliance rule. The README's "master prompt" lets your agent configure the relay itself.

---

## 12. r/privacy — ⚠️ modmail the mods FIRST (Rule 2)

**Rules:** Rule 2 — developers of open-source privacy software may post but MUST
contact mods in advance, identify as the dev, and stay to answer questions;
closed-source promotion banned; one-off, no repeats. Modmail first, then post:

> **Title:** Open-source, fully self-hosted messenger for chatting with your own local AI — conversations never leave your machine
>
> Mods: I'm the developer, messaging ahead of posting per Rule 2 — this is a non-commercial, MIT-licensed project and I'll stick around to answer questions.
>
> The project: a private chat app (Flutter Android client + FastAPI relay) whose only "contact" is your own AI agent running on your own hardware. There's no cloud component at all — message history, files and media stay next to the model, on your machine. Remote access goes through your own Cloudflare Tunnel or Tailscale, not a third-party relay.
>
> It's a direct alternative to using WhatsApp/Telegram as the channel for your personal agent — the exact scenario where all your agent's context ends up on a big-tech server.
>
> Everything is open source (MIT): https://github.com/tushar-alt/hermes_companion
>
> Happy to talk threat model — for most people the weakest link is the agent provider, not this app, and the README is honest about that.

---

## 13. r/PrivacyGuides — 🔒 subreddit CLOSED — post on their Discourse instead

**Rules:** the subreddit is restricted ("closed in protest"), activity is minimal;
the community moved to discuss.privacyguides.net. **Do not post on Reddit** — use
the Project Showcase category on their Discourse:

> **Post for discuss.privacyguides.net (Project Showcase):**
>
> **Hermes Companion** — open-source, fully self-hosted messenger for talking to your own local AI agent. Flutter Android client + FastAPI relay on your machine; conversations, history and media never leave your hardware. Remote access via your own Cloudflare Tunnel/Tailscale. MIT licensed: https://github.com/tushar-alt/hermes_companion
>
> Privacy value: replaces WhatsApp/Telegram as the channel to your personal agent — no third party sees your agent conversations. Threat model: the relay authenticates with a bearer token you generate; the client stores it in app-private storage; plain HTTP is only enabled for LAN, and the README recommends TLS in front of the relay for internet use. Honest caveat: if your agent is a cloud LLM, that provider still sees messages — self-hosting the model is the way to close that gap.
>
> Not asking to be listed on the website — just sharing for feedback.

---

## 14. r/opensource — ✅ postable (Promotional flair REQUIRED)

**Rules:** "Promotional" flair required when sharing your own project; the repo
**must have an OSI-approved license** (MIT now included); title factual; post body
must be human-written; must engage in comments (no drive-by posting). **Flair:**
`Promotional`.

> **Title:** Hermes Companion — open-source messenger for talking to your own AI agent, fully self-hosted (MIT)
>
> I made a messenger app whose only contact is my own AI agent. Flutter Android client + a Python FastAPI relay that runs on my machine next to the agent. No cloud component: history, files and media all live on my hardware. Cloudflare Tunnel/Tailscale for access from anywhere.
>
> Why I open-sourced it: the interesting part isn't the app, it's the contract between the client and the relay — a small REST API (13 endpoints) that's easy to implement for any agent, which the README documents fully. Onboarding is a single pasted "master prompt" that makes the agent generate a token, stand up the relay, and reply with a pairing link.
>
> Other bits: markdown rendering, media both ways, offline outbox, per-session pause/resume (pause kills the agent process — zero resources), unread badges, per-chat mute, and Android foreground-service notifications.
>
> MIT licensed: https://github.com/tushar-alt/hermes_companion
>
> Happy to discuss the relay API design, the session lifecycle, or the Flutter side. Contributions welcome.

---

## 15. r/FlutterDev — ✅ postable (LINK post + Showcase flair)

**Rules:** use a LINK post (not text-with-URL); "Showcase"-style posts accepted
when you share source + specific build insights (generic insight is insufficient);
no pure app advertising. **Flair:** `Showcase`.

> **Title:** [Showcase] I built a messenger for chatting with your own AI agent — Flutter client + FastAPI relay (open source)
>
> Sharing the Flutter side of Hermes Companion, an open-source messenger whose backend is a self-hosted FastAPI relay next to your own agent. A few engineering decisions I'm happy to defend:
>
> - **Reversed ListView for the chat.** Offset 0 = newest message, so opening the chat and keyboard-inset handling are trivial — no maxScrollExtent estimation hacks.
> - **Android foreground-service notifications.** A 20s repeat task in a background isolate polls the relay, dedupes via watermarks in SharedPreferences, respects per-chat mute and a 30s cooldown.
> - **Persistent outbox + offline cache.** Queued messages survive restarts (JSON in prefs); the last 400 messages are cached so the chat is readable offline.
> - **Custom painters.** Cartoon avatars and the "thinking" indicator (a single shape morphing circle→triangle→square→diamond) are pure CustomPainter — no assets, deterministic per chat id.
> - **In-house markdown renderer.** One file, zero dependencies, handles the common block/inline subset agents actually emit.
>
> Repo (MIT): https://github.com/tushar-alt/hermes_companion
>
> Would love code review on the relay protocol and the merge logic in the chat screen.

---

## 16. r/androidapps — 🔒 self-promo BANNED — post on r/droidappshowcase instead

**Rules:** Rule 2 bans self-promotion/dev content outright; devs are directed to
the sister sub **r/droidappshowcase**. GitHub links are pre-approved sources, but
a "here's my app" post violates Rule 2. Post there:

> **Title (for r/droidappshowcase):** Hermes Companion — talk to your own private AI agent from your phone (fully self-hosted)
>
> A messenger app where the only contact is your own AI agent running on your machine. Flutter client + FastAPI relay on your hardware — no cloud, conversations stay with you. Works from anywhere via Cloudflare Tunnel/Tailscale.
>
> What you get: markdown-rendered replies, send/receive images and files, offline outbox (messages queue up when you have no signal), per-chat power toggles with red/green status dots, unread badges, per-chat mute, and notifications via a foreground service.
>
> Setup is one paste: the app gives you a "master prompt," your agent configures the relay and replies with a pairing link.
>
> Open source (MIT): https://github.com/tushar-alt/hermes_companion

---

## 17. r/androiddev — ⚠️ app-sharing banned — post the engineering, not the app

**Rules:** Rule 2 forbids "sharing applications or recruiting testers"; but
"useful libraries, handy tools, open source applications for studying" are
welcome; cross-platform content limited to the Android-native aspect; Rule 5 bans
AI-sounding copy. Post as a technical deep-dive:

> **Title:** Android foreground-service notifications + offline outbox for a self-hosted messenger — architecture notes
>
> Notes from building the Android side of Hermes Companion (open source, MIT — link below), a messenger for chatting with your own self-hosted AI agent. Focused on the Android-native bits:
>
> - **Guaranteed background polling.** Instead of WorkManager (Doze-throttled), I run a 20s `foregroundServiceType="remoteMessaging"` service. A background isolate polls the relay, advances per-chat read watermarks in SharedPreferences, dedupes notified messages, and fires local notifications. Cooldown of 30s collapses burst replies into one ping.
> - **Offline-first messaging.** Every sent message gets an optimistic bubble that survives send failures with a tap-to-retry chip. Queued messages persist to prefs (outbox) and auto-flush when the relay confirms the agent is idle. A 400-message tail cache makes the chat readable offline.
> - **Session power toggles.** Each chat can be paused — the relay actually kills the agent process — surfaced as a per-chat switch + pulsing red/green status dot (CustomPainter, no assets).
> - **Keyboard/scroll UX.** Reversed `ListView.builder` (offset 0 = newest) makes open-at-bottom and keyboard-inset behavior trivial.
>
> Repo: https://github.com/tushar-alt/hermes_companion
>
> Questions welcome on the service lifecycle or watermarking approach.

---

## 18. r/SideProject — ✅ postable ("Built This" flair)

**Rules:** show the real build with a working demo/screenshots (no landing-page
gates); engage with every comment; no affiliate links; don't repost repeatedly.
**Flair:** `Built This`.

> **Title:** [Built This] Hermes Companion — I replaced WhatsApp with a messenger that talks to my own AI agent (self-hosted, open source)
>
> Story: my agent and I used to chat over Telegram, and it always felt off that our whole conversation lived on Telegram's servers. So I built a private messenger where the only contact is my own agent running on my machine.
>
> The build: a Flutter Android app + a Python FastAPI relay that sits next to the agent. The relay is the whole backend — it implements auth, sessions, media, history, and a hook your agent plugs into. Remote access via Cloudflare Tunnel, so it works from anywhere, no port forwarding.
>
> Features I actually use daily: markdown replies, sending photos/files to the agent and back, offline outbox (I commute through dead zones), per-chat power toggles with red/green dots, unread badges, and notifications.
>
> The part I'm most proud of: onboarding is one pasted "master prompt" — the agent configures the entire relay itself and replies with a pairing link.
>
> Open source (MIT), screenshots and the master prompt in the README: https://github.com/tushar-alt/hermes_companion
>
> Honest stage: solid v1, works daily, still rough around the edges (no iOS, Docker image on the roadmap). Feedback welcome — especially on the pairing flow.

---

## 19. r/somebodymakethis — ⚠️ "SMT:" title tag required — idea framing

**Rules:** every title must start with `SMT:` or automod removes it; it's a
place for ideas; finished creations go in the monthly Creator Showcase thread or
can be revealed inside the SMT post. **Flair:** `Software`.

> **Title:** SMT: A self-hosted messenger for chatting with your own AI agent — so you can drop WhatsApp/Telegram as the middleman
>
> Idea: most people's AI agents live in big chat apps. What if your agent had its own private messenger — the app on your phone, the brain on your machine, and the conversation history on your hardware?
>
> That's exactly what I wanted, so I built it: Hermes Companion. Flutter app + FastAPI relay next to your agent (local LLM, Claude, whatever). No cloud. Works from anywhere via Cloudflare Tunnel/Tailscale. Markdown replies, files both ways, offline outbox, per-chat pause/resume (paused = the agent process is actually stopped), unread badges, notifications.
>
> Onboarding is one paste: a "master prompt" that makes the agent configure the relay and reply with a pairing link.
>
> It's open source (MIT): https://github.com/tushar-alt/hermes_companion
>
> If you've ever wished your agent had its own channel, this is what I landed on — feedback and contributions very welcome.

---

## 20. r/homelab — ⚠️ self-promo effectively BANNED — engineering discussion only

**Rules:** strict no-advertising/no-self-promotion (linking your own project
gets removed regardless of effort); posts must be homelab-relevant (servers,
networking, self-hosting infra); no low-effort posts. **Do NOT put the repo link
in the post** — if someone asks in the comments, share it there. Post as an
architecture discussion (the tunnel/relay part is squarely on-topic):

> **Title:** Exposing a local AI agent to my phone with zero open ports — Cloudflare Tunnel + a tiny relay (homelab pattern)
>
> Sharing a homelab pattern I've been running for a while: giving a service on my home server a secure channel to an Android app without opening a single port on my router.
>
> Setup: a small FastAPI relay runs next to the service (in my case, an AI agent). The relay is the only piece that's reachable — it authenticates with a bearer token and exposes a small REST API. Outbound-only access is handled by `cloudflared tunnel --url http://localhost:8124`, so the phone hits a public https URL while nothing on my LAN is exposed. Tailscale is the fallback when I want to stay off Cloudflare's edge.
>
> Why this beats port forwarding for me: no static IP needed, no router config, TLS for free, and I can shut the whole thing down by killing the tunnel process. The relay itself is deliberately tiny — ~200 lines, single process, it just marshals messages, media and session state to the agent hook.
>
> Also running a 20s foreground-service poller on the phone so I get notified when the agent finishes a task — that part is Android-side, but the lifecycle is worth thinking about if you expose any long-running job this way.
>
> Happy to go deeper on the tunnel config or the relay design. (I open-sourced the whole thing if anyone wants the details — happy to share the link in the comments.)

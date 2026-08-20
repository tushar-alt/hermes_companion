# Mission

Post about the open-source project **Hermes Companion** (a self-hosted messenger
for chatting with your own AI agent — https://github.com/tushar-alt/hermes_companion)
to the **21 Reddit communities** listed in the plan below. The post text for
every community already exists in the repo file `reddit_posts.md` — read it
first (see Pre-flight) and post using the EXACT titles and bodies from that
file. Follow each community's rules exactly as documented there and here.

You are a browser automation agent. The user is logged into Reddit in this
browser session. Act as the user, posting genuinely — never spam, never
astroturf. Disclose in every post that it is the user's own open-source
project (the posts already do this).

---

## Pre-flight — do these FIRST; stop and report if any fail

1. **Repo must be public.** Open https://github.com/tushar-alt/hermes_companion .
   If it returns 404 or shows "Private", STOP and report: the repo needs to be
   made public in GitHub → Settings → General → Danger Zone → Change visibility.
2. **Read the post content.** Open
   https://raw.githubusercontent.com/tushar-alt/hermes_companion/main/reddit_posts.md
   and read the ENTIRE file. Each entry has: the subreddit, a status line
   (✅ postable / ⚠️ special handling / 🔒 redirect), the rules checklist, and
   the ready post (title + body). If the raw URL fails, ask the user to paste
   the file contents instead — do not improvise post text.
3. **Check the account.** The user's Reddit account must be signed in. Note its
   account age and karma. Subs with account gates: r/LocalLLaMA (~30 days),
   r/artificial (~100 karma/30 days), r/ChatGPT (~100 karma/30 days),
   r/ClaudeAI (karma >50), r/ArtificialInteligence (~50 karma/14 days),
   r/LocalLLM (~50 karma/14 days), r/opensource (prior participation),
   r/selfhosted (participation history). If the account doesn't meet a gate,
   skip that sub for now and report it — do not post from a fresh account.
4. **Check pinned threads.** Before posting anywhere, open the subreddit and
   check the current pinned posts and sidebar: required flairs, megathreads,
   and rule changes override anything written here. Specifically confirm which
   week's "New Project Megathread" is pinned in r/selfhosted (refreshed each
   Friday).

---

## Posting plan — 21 entries

Post in the order below. Spread posts out: **max 5 per day, at least 1 hour
apart**, to avoid spam filters. Never post the same content to the same sub
twice. Never delete-and-repost.

### Priority 1 — no gates, post first (these give the account history for the stricter subs)

1. **r/SideProject** — flair `Built This`. Post the entry text. Include 2–3
   screenshots of the app (open the repo README for images; if none are
   available, skip images). Reply to every comment.
2. **r/opensource** — flair `Promotional` (required by rule 8). Post the entry
   text. The repo has an MIT LICENSE file — the sub requires it.
3. **r/FlutterDev** — this must be a **LINK post**: the link URL is the GitHub
   repo, the title is from the file, the flair is `Showcase`. Rule 3 requires
   link posts for this.
4. **r/LocalLLaMA** — flair `Discussion`. Human-written copy (it is). Be ready
   to answer technical questions about the relay.
5. **r/LocalLLM** — flair `Project`.
6. **r/aipromptprogramming** — no flair required; post the entry text as an
   open-source showcase (lead with the master prompt angle).
7. **r/somebodymakethis** — the title MUST start with `SMT:` or automod removes
   it instantly (the entry title in the file already does). Post the idea, then
   reveal the open-source implementation + link in the body.
8. **r/HermesAgent** — open the sub first, check pinned threads and any required
   flair. Disclose it's your own project. If there's a pinned megathread for
   announcements or self-promo, post there instead of the main feed.

### Priority 2 — special handling, post after Priority 1

9. **r/AI_Agents** — do NOT put the GitHub link in the post body (rule 3: links
   go in comments). Use flair `Built`, or post in the weekly project display
   thread if that's where projects go. Put the repo link in a comment.
10. **r/artificial** — participate in the sub first: read and leave genuine
    comments/upvotes on 5+ posts, spaced out, before posting. Then post with
    flair `Project`.
11. **r/ArtificialInteligence** — same prior participation (comment on 5+ posts
    first). Then post with flair `Project`.
12. **r/ClaudeAI** — flair `Built with Claude` (required). The post must stay
    Claude/Claude-Code-centric (the entry text is written that way).
13. **r/selfhosted** — do NOT make a standalone post (the sub auto-removes new
    projects <3 months old). Instead, paste the entry text as a **top-level
    comment** in the pinned weekly **New Project Megathread**, following its
    template (name, repo link, description, deployment, docs, AI-involvement
    disclosure — the entry text includes all of these). If the AI-compliance
    bot replies asking about AI involvement, answer it with the disclosure from
    the entry text.
14. **r/ChatGPT** — do NOT post to the main feed. Post the entry text in the
    pinned weekly self-promotion megathread.
15. **r/ChatGPTCoding** — the sub is RESTRICTED (only approved users post on the
    main feed). Post the entry text in the weekly Self Promotion Thread only.
    The entry includes the master prompt, which satisfies rule 3.
16. **r/androiddev** — post as a technical text post (the entry is written as an
    engineering deep-dive). No app pitch, no "star my repo" — the repo link
    appears at the end as the reference implementation. Use a fitting flair
    (e.g. Discussion) if required.

### Priority 3 — REQUIRES MODMAIL FIRST

17. **r/privacy** — before posting, send a modmail to r/privacy stating: you are
    the developer of a non-commercial, MIT-licensed, open-source privacy
    project, you're contacting per Rule 2 (developer submission), and you'll
    stay in the thread to answer questions. Post the entry text ONLY after a
    mod approves. If no reply within 72h, skip and report.
18. **r/LLMDevs** — same: modmail first explaining the tool, its value and
    relevance to LLM development (two-strike policy — never post without
    approval). Only post after approval. Flair `Tools` if applicable.

### Redirects — do NOT post on the named sub

19. **r/androidapps** — self-promotion is banned there (rule 2). Post the entry
    text on **r/droidappshowcase** instead.
20. **r/PrivacyGuides** — the subreddit is closed (restricted; the community
    moved). Do NOT post on Reddit. Post the entry text in the **Project
    Showcase** category of **discuss.privacyguides.net** (create an account
    there if needed).
21. **r/homelab** — self-promotion is effectively banned. Do NOT post the repo
    link. You may post the engineering-discussion entry text WITHOUT any link,
    and only share the repo link in comments **if someone explicitly asks**.

---

## After each successful post

- Stick around: reply to **every** comment on your post for at least 30 minutes
  (longer for the priority-1 subs). Engagement is a rule in nearly every sub.
- If a post is removed, do NOT repost it. Note the reason (removal message,
  bot reply, or absence) and move on.

## Hard guardrails — stop and report immediately if any of these happen

- The repo is private/404 (fix visibility first).
- The Reddit account is suspended, rate-limited, or the sub bans you — stop
  all posting until the user says otherwise.
- A sub's current rules contradict this plan (e.g., new flair required, new
  megathread) — follow the CURRENT rules, note the difference in the report.
- You cannot verify a required action (e.g., modmail approval) — skip that sub
  rather than guess.

## Report back (after the session)

Return a table: **subreddit → status** (posted OK with link / removed with
reason / skipped with reason / awaiting modmail approval), plus any warnings
(e.g., account gates not met, rules that changed). Keep it concise.

# Mission

Prepare launch posts for the open-source project **Hermes Companion**
(a self-hosted messenger for chatting with your own AI agent —
https://github.com/tushar-alt/hermes_companion) in **21 Reddit communities**,
and prepare **everything except the final click** so the user can review each
post before it goes live.

**Hard rule: you NEVER click the post/submit/send button. Never publish, never
send, never comment.** Your job is to open tabs, navigate to the exact place,
fill in the title, body, flair and attachments exactly as specified, and leave
every form filled and unsent. The user reviews each tab and clicks post
themselves.

You are a browser automation agent. The user is logged into Reddit in this
browser session. Act as the user, preparing genuine posts — never spam, never
astroturf. Every post already discloses it is the user's own open-source
project.

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
   do NOT prepare that sub — report it as blocked (do not let the user waste a
   submission on an account that will be filtered).
4. **Check pinned threads.** For every sub, open it and check the current
   pinned posts and sidebar: required flairs, megathreads, and rule changes
   override anything written here. Confirm which week's "New Project
   Megathread" is pinned in r/selfhosted (refreshed each Friday) and which
   weekly self-promotion threads are pinned in r/ChatGPT and r/ChatGPTCoding.

---

## Workflow

Work in **multiple tabs simultaneously** (as many as the browser comfortably
allows; group by priority). For each entry below:

1. Open a **new tab**.
2. Navigate to the exact destination (subreddit, megathread, reply box, or
   off-site category) listed for that entry.
3. **Prepare the post exactly as specified**: paste the exact title into the
   title field, paste the exact body into the body field, select the required
   flair, attach screenshots where instructed.
4. **Do NOT click post/submit/send.** Leave the form completely filled and
   unsent. If Reddit shows a warning that leaving will lose the draft, keep the
   tab open.
5. Move to the next tab.

If a tab is accidentally closed, reopen it and redo the preparation. If a form
cannot be filled (e.g., flair missing, composer won't open), report it in the
final table instead of improvising.

### Priority 1 — prepare first (these also give the account posting history)

1. **r/SideProject** — flair `Built This`. Fill the post. Attach 2–3 screenshots
   of the app (open the repo README for images; skip if none are available).
2. **r/opensource** — flair `Promotional` (required). Fill the post.
3. **r/FlutterDev** — this must be a **LINK post**: the link URL is the GitHub
   repo, the title is from the file, the flair is `Showcase`.
4. **r/LocalLLaMA** — flair `Discussion`. Fill the post.
5. **r/LocalLLM** — flair `Project`. Fill the post.
6. **r/aipromptprogramming** — no flair required. Fill the post.
7. **r/somebodymakethis** — the title MUST start with `SMT:` (the entry title
   already does). Fill the post (idea + repo reveal in body).
8. **r/HermesAgent** — check pinned threads and any required flair first. If a
   pinned megathread for announcements/self-promo exists, open it and fill a
   reply there instead of a new post. Fill the post/reply, do not submit.

### Priority 2 — prepare after Priority 1

9. **r/AI_Agents** — do NOT put the GitHub link in the post body (links go in
   comments). Use flair `Built`, or if projects go in the weekly project
   display thread, fill the post in that thread instead. Fill the body, and
   ALSO prepare the comment containing the repo link (leave it unsent).
10. **r/artificial** — before preparing, leave 5+ genuine comments/upvotes on
    existing posts (this is allowed — commenting is part of preparation). Then
    fill the post with flair `Project`.
11. **r/ArtificialInteligence** — same: 5+ genuine comments first, then fill
    the post with flair `Project`.
12. **r/ClaudeAI** — flair `Built with Claude` (required). Fill the post.
13. **r/selfhosted** — do NOT prepare a standalone post. Open the pinned weekly
    **New Project Megathread**, open the reply box, and paste the entry text
    (name, repo, description, deployment, docs, AI-involvement disclosure).
    Leave the reply filled and unsent. If the AI-compliance bot asks about AI
    involvement, prepare the reply with the disclosure from the entry text and
    leave it unsent too.
14. **r/ChatGPT** — do NOT prepare a main-feed post. Open the pinned weekly
    self-promotion megathread, open the reply box, paste the entry text. Leave
    unsent.
15. **r/ChatGPTCoding** — sub is RESTRICTED; only the weekly Self Promotion
    Thread is open. Open that thread, fill the reply with the entry text. Leave
    unsent.
16. **r/androiddev** — fill the technical text post (entry is an engineering
    deep-dive), with the repo link at the end. Use a fitting flair (e.g.
    Discussion) if required.

### Priority 3 — prepare the modmail FIRST (do not send)

17. **r/privacy** — draft a modmail to r/privacy (Rule 2 developer submission):
    you are the developer of a non-commercial, MIT-licensed, open-source
    privacy project, you're contacting before posting per Rule 2, and you'll
    stay in the thread to answer questions. Fill the modmail form, leave
    UNSENT. Do not prepare the actual post until the mods approve (report as
    "awaiting approval").
18. **r/LLMDevs** — same: draft the modmail explaining the tool, its value and
    relevance to LLM development. Leave UNSENT. Do not prepare the post until
    approval.

### Redirects — prepare in the OTHER place, not the named sub

19. **r/androidapps** — self-promo is banned there. Prepare the post on
    **r/droidappshowcase** instead (fill and leave unsent).
20. **r/PrivacyGuides** — the subreddit is closed. Prepare the post in the
    **Project Showcase** category of **discuss.privacyguides.net** (create an
    account there if needed; fill and leave unsent).
21. **r/homelab** — self-promo is effectively banned. Prepare the
    engineering-discussion entry text WITHOUT any link as a text post (fill and
    leave unsent). Do not include the repo link; it may only be shared in
    comments if someone explicitly asks after posting.

---

## Guardrails

- **Never** click post/submit/send/comment. Preparation only.
- Do not post the same content twice anywhere.
- If a sub's current rules contradict this plan (new flair, new megathread),
  follow the CURRENT rules and note the difference in the report.
- If the account doesn't meet a sub's karma/age gate, skip it (blocked) — do
  not prepare a doomed submission.
- If you cannot verify a required action (e.g., modmail approval), prepare only
  what is safe and mark the rest "awaiting approval".

## Report back (for the user to review)

Return a table the user can walk through tab by tab:

| # | Subreddit | Tab status | What to check before posting |
|---|---|---|---|
| 1 | r/SideProject | Draft ready | Screenshots attached? Flair `Built This`? |
| ... | ... | ... | ... |

Status values: **Draft ready** (tab open, form filled, nothing submitted),
**Blocked** (account gate / sub closed / restriction), **Awaiting approval**
(modmail drafted but not sent), **Skipped** (rule prevents posting). For every
"Blocked"/"Awaiting approval" row, give the one-line reason.

End with the list of tab numbers the user should review first (Priority 1), and
remind them that NOTHING has been posted yet.

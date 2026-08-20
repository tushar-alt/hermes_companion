/// Copyable "scripts" shown in the help drawer, grouped into folders.
library;

/// A single copyable script (e.g. a prompt to send the agent).
class PromptScript {
  const PromptScript(this.name, this.body);

  final String name;
  final String body;
}

/// A folder grouping scripts in the help drawer.
class PromptFolder {
  const PromptFolder(this.name, this.items);

  final String name;
  final List<PromptScript> items;
}

/// ONE prompt that sets up everything — relay, public reachability,
/// pause/resume, delete-termination and pairing. The agent replies with only
/// the pairing link, nothing else.
const masterPrompt = PromptScript('Master prompt', '''
You are Hermes, my personal agent. Set up the Hermes Companion app end-to-end, then reply with EXACTLY ONE LINE and nothing else: a pairing link in this format:

hermes://pair?url=<URL-ENCODED-BASE-URL>&token=<TOKEN>

Do ALL of the following:
1. RELAY: run the reference FastAPI relay from the project README on port 8124 bound to 0.0.0.0. It implements /api/health, /api/chats, /api/chat, /api/chat/new, /api/chat/<id> (DELETE), /api/chat/<id>/pause, /api/chat/<id>/resume, /api/messages, /api/send, /api/status, /api/files, /api/media, /api/upload. Wire the agent hooks (run_agent, start_agent_session, stop_agent_session) to your real agent logic.
2. PUBLIC: make the relay reachable from anywhere — Cloudflare Tunnel (cloudflared tunnel --url http://localhost:8124), Tailscale, or a VPS reverse proxy with TLS. Prefer a public https:// URL.
3. PAUSE/RESUME: POST /api/chat/<id>/pause must stop that chat's session/CLI (zero system resources); /resume must start it again. While paused, do not run the agent — keep messages queued.
4. DELETE: DELETE /api/chat/<id> must kill the session, remove the chat and all its messages, and refuse deleting the main chat (400).
5. TOKEN: generate a random bearer token (e.g. openssl rand -hex 24).
6. Build the pairing link: url = the full base URL the phone can reach, URL-encoded (e.g. http%3A%2F%2F192.168.0.56%3A8124); token = the token from step 5, plain text.

No explanations, no markdown, no extra words. Just the single line starting with hermes://pair?
''');

/// Step-by-step pairing instructions for the human.
const pairingSteps = PromptScript('Pairing steps (for you)', '''
How to pair the app:
1. Open the app → you'll see the pairing screen (first run only).
2. Tap "Copy master prompt" and send that prompt to Hermes on any channel.
3. Hermes sets everything up and replies with ONE line: hermes://pair?url=...&token=...
4. Paste it into the app → Use link → Connect.
No link yet? You can also enter the server URL + token manually and tap "Test connection".
''');

/// Instructions for using the app away from home Wi-Fi.
const anywhereSteps = PromptScript('Works from anywhere (for you)', '''
How to use the app from anywhere (not just home Wi-Fi):
1. The master prompt already tells Hermes to expose the relay publicly.
2. Re-pair with the new public https:// URL it replies with.
3. Keep the relay running. The app, chat, files and notifications then work over mobile data.
''');

/// Folders shown in the help drawer.
const promptFolders = <PromptFolder>[
  PromptFolder('Prompts', [masterPrompt]),
  PromptFolder('Guide', [
    pairingSteps,
    anywhereSteps,
  ]),
];

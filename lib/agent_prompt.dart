import 'prompts.dart';

/// A ready-to-send prompt the user can copy and give to their Hermes agent.
///
/// One master prompt: Hermes sets up the whole relay (public reachability,
/// pause/resume, delete-termination, token) and replies with EXACTLY one
/// line — a pairing link — which the user pastes into the app's onboarding.
String agentPairingPrompt() => masterPrompt.body;

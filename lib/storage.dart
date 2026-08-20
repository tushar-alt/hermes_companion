import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Default relay the app tries when nothing is configured yet.
const String defaultServerUrl = 'http://192.168.0.56:8124';

/// Thin, crash-safe wrapper around [SharedPreferences].
///
/// The old code used `late SharedPreferences _prefs` and touched it from
/// `didChangeAppLifecycleState`, which can fire *before* `getInstance()`
/// resolves → `LateInitializationError` on cold start. Here every access is
/// null-safe: before [load] completes the wrapper simply returns defaults and
/// drops writes, so lifecycle callbacks can never crash the app.
class AppPrefs {
  AppPrefs._(this._prefs);

  final SharedPreferences? _prefs;

  static Future<AppPrefs> load() async {
    final p = await SharedPreferences.getInstance();
    return AppPrefs._(p);
  }

  bool get ready => _prefs != null;

  // ── raw access (null-safe) ───────────────────────────────────────────
  String getString(String key, [String fallback = '']) =>
      _prefs?.getString(key) ?? fallback;
  bool getBool(String key, [bool fallback = false]) =>
      _prefs?.getBool(key) ?? fallback;
  int getInt(String key, [int fallback = 0]) => _prefs?.getInt(key) ?? fallback;

  Future<void> setString(String key, String value) async {
    final p = _prefs;
    if (p != null) await p.setString(key, value);
  }

  Future<void> setBool(String key, bool value) async {
    final p = _prefs;
    if (p != null) await p.setBool(key, value);
  }

  Future<void> setInt(String key, int value) async {
    final p = _prefs;
    if (p != null) await p.setInt(key, value);
  }

  // ── connection / onboarding ──────────────────────────────────────────
  String get serverUrl => getString('serverUrl', defaultServerUrl);
  String get token => getString('token');
  bool get onboarded => getBool('onboarded');

  Future<void> setCredentials(String url, String token) async {
    await setString('serverUrl', url);
    await setString('token', token);
  }

  Future<void> markOnboarded() => setBool('onboarded', true);

  // ── lifecycle flag shared with the background service ────────────────
  bool get appForeground => getBool('appForeground');
  Future<void> setAppForeground(bool value) => setBool('appForeground', value);

  // ── per-chat watermarks ──────────────────────────────────────────────
  int lastIdFor(String chatId) => getInt('lastId_$chatId');
  Future<void> setLastId(String chatId, int id) => setInt('lastId_$chatId', id);

  /// Highest message id the user has actually *seen* (badges, not notified).
  int seenFor(String chatId) => getInt('seen_$chatId');
  Future<void> setSeen(String chatId, int id) => setInt('seen_$chatId', id);

  /// Highest reply id the background service has already notified about.
  int notifiedFor(String chatId) => getInt('notified_$chatId');
  Future<void> setNotified(String chatId, int id) => setInt('notified_$chatId', id);

  bool mutedFor(String chatId) => getBool('muted_$chatId');
  Future<void> setMuted(String chatId, bool muted) => setBool('muted_$chatId', muted);

  /// Local "last activity" timestamp (ms since epoch) used to sort the chat
  /// list when the relay does not provide `lastTs`.
  int lastActiveFor(String chatId) => getInt('lastActive_$chatId');
  Future<void> setLastActive(String chatId, int ms) =>
      setInt('lastActive_$chatId', ms);

  int get lastNotifiedAt => getInt('lastNotifiedAt');
  Future<void> setLastNotifiedAt(int ms) => setInt('lastNotifiedAt', ms);

  // ── persistent outbox (queued messages survive app restarts) ─────────
  List<QueuedMessage> outboxFor(String chatId) {
    final raw = getString('outbox_$chatId');
    if (raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => QueuedMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> setOutbox(String chatId, List<QueuedMessage> queue) async {
    await setString(
        'outbox_$chatId', jsonEncode(queue.map((m) => m.toJson()).toList()));
  }

  // ── offline cache (last-seen messages per chat) ──────────────────────
  List<ChatMessage>? cachedMessagesFor(String chatId) {
    final raw = getString('cache_$chatId');
    if (raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> setCache(String chatId, List<ChatMessage> messages) async {
    await setString(
        'cache_$chatId', jsonEncode(messages.map((m) => m.toJson()).toList()));
  }

  Future<void> clearCache(String chatId) => setString('cache_$chatId', '');

  /// Remove ALL local state for a deleted chat — cache, outbox, watermarks
  /// and mute flag — so nothing lingers after the session is gone.
  Future<void> clearChat(String chatId) async {
    final p = _prefs;
    if (p == null) return;
    for (final key in [
      'lastId_$chatId',
      'seen_$chatId',
      'notified_$chatId',
      'muted_$chatId',
      'outbox_$chatId',
      'cache_$chatId',
      'lastActive_$chatId',
    ]) {
      await p.remove(key);
    }
  }
}

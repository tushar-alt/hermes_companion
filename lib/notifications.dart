import 'dart:ui' show Color;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Single shared plugin instance (re-initialized per isolate).
final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

const _channelId = 'hermes_updates';
const _channelName = 'Hermes updates';
const _channelDesc = 'New replies and task updates from Hermes';

Future<void> initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);
  await notifications.initialize(settings: settings);

  // Android 13+ runtime permission
  final impl = notifications.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await impl?.requestNotificationsPermission();
}

Future<void> showHermesNotification(String title, String body) async {
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFFC9A24B),
      icon: '@mipmap/ic_launcher',
    ),
  );
  await notifications.show(
    id: DateTime.now().millisecondsSinceEpoch % 100000,
    title: title,
    body: body,
    notificationDetails: details,
  );
}

// ═══════════════════════════════════════════════════════════
//  FOREGROUND SERVICE — guaranteed background notifications
//  Runs every 20s in a background isolate, polls every chat,
//  fires local notifications. Android does NOT throttle this
//  the way it throttles WorkManager (Doze).
// ═══════════════════════════════════════════════════════════

@pragma('vm:entry-point')
Future<void> startCallback() async {
  FlutterForegroundTask.setTaskHandler(CompanionTaskHandler());
}

class CompanionTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      await initNotifications();
    } catch (_) {}
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Hermes Companion connected',
      notificationText: 'Notifications live',
    );
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // The background isolate caches prefs — it can go stale vs the UI
      // isolate, which would re-notify messages the app already showed.
      await prefs.reload();

      final baseUrl = prefs.getString('serverUrl') ?? 'http://192.168.0.56:8124';
      final token = prefs.getString('token') ?? '';
      final api = RelayApi(baseUrl, token: token);

      // Cooldown: at most one notification per 30s — bursts of turns from a
      // single agent run collapse into a single ping instead of spam.
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - (prefs.getInt('lastNotifiedAt') ?? 0) < 30000) return;

      final chats = await api.fetchChats();
      for (final chat in chats) {
        final readKey = 'lastId_${chat.id}';
        final notifiedKey = 'notified_${chat.id}';
        final lastId = prefs.getInt(readKey) ?? 0;
        final notified = prefs.getInt(notifiedKey) ?? 0;

        final page = await api.fetchMessages(lastId, chatId: chat.id);
        if (page.messages.isEmpty) continue;
        // Advance the read watermark even when we don't notify, so a message
        // that was seen (UI) or skipped is never re-processed.
        await prefs.setInt(readKey, page.lastId);
        // Record activity so the home list sorts this chat to the top.
        await prefs.setInt('lastActive_${chat.id}', nowMs);

        // Per-chat mute: still mark as read, but never ping this chat.
        if (prefs.getBool('muted_${chat.id}') ?? false) continue;

        final replies = page.messages
            .where((m) => !m.isUser && m.text.isNotEmpty)
            .toList();
        if (replies.isEmpty) continue;

        final last = replies.last;
        if (last.id <= notified) continue; // already notified for this one
        if (prefs.getBool('appForeground') ?? false) continue;

        await prefs.setInt(notifiedKey, last.id);
        await prefs.setInt('lastNotifiedAt', nowMs);
        await showHermesNotification('${chat.name} 💬', _cleanPreview(last.text));
        break; // one notification per tick
      }
    } catch (_) {
      // silent — the next 20s tick retries
    }
  }

  String _cleanPreview(String text) {
    var t = text
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll('`', '')
        .replaceAll(RegExp(r'[#>]'), '')
        .trim();
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t.length > 180 ? '${t.substring(0, 180)}…' : t;
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Start (or restart) the foreground service.
Future<void> initForegroundService() async {
  FlutterForegroundTask.initCommunicationPort();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'hermes_foreground',
      channelName: 'Hermes Companion service',
      channelDescription:
          'Keeps Hermes Companion connected so notifications always arrive.',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      // poll every 20 seconds while the service runs
      eventAction: ForegroundTaskEventAction.repeat(20000),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  await FlutterForegroundTask.requestNotificationPermission();

  if (await FlutterForegroundTask.isRunningService) {
    await FlutterForegroundTask.restartService();
  } else {
    await FlutterForegroundTask.startService(
      // remoteMessaging type: no 6h/day cap (dataSync has one on Android 15+)
      serviceTypes: [ForegroundServiceTypes.remoteMessaging],
      serviceId: 256,
      notificationTitle: 'Hermes Companion connected',
      notificationText: 'Notifications live',
      notificationIcon: null,
      callback: startCallback,
    );
  }
}

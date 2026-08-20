/// Web stub for `notifications.dart`.
///
/// Browsers have no foreground service and no local notification channel the
/// way Android does, so every call is a no-op. The web app still shows new
/// replies live while the tab is open (the chat screen polls the relay).
library;

Future<void> initNotifications() async {}

Future<void> initForegroundService() async {}

Future<void> showHermesNotification(String title, String body) async {}

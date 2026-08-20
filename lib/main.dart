import 'package:flutter/material.dart';

import 'notifications.dart'
    if (dart.library.html) 'notifications_web.dart' as notifications;
import 'onboarding.dart';
import 'screens/home_screen.dart';
import 'storage.dart';
import 'theme.dart';
import 'version_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await notifications.initNotifications();
  await notifications.initForegroundService();
  final prefs = await AppPrefs.load();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  runApp(VersionCheck(
    messengerKey: messengerKey,
    child: CompanionApp(
      showOnboarding: !prefs.onboarded,
      messengerKey: messengerKey,
    ),
  ));
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key, this.showOnboarding = false, this.messengerKey});

  /// True on the very first launch: route to the pairing screen instead of
  /// the chat list. Persisted via `AppPrefs.onboarded`, so it only shows once.
  final bool showOnboarding;

  /// Lets [VersionCheck] show the "new version" banner through the app's
  /// ScaffoldMessenger.
  final GlobalKey<ScaffoldMessengerState>? messengerKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hermes Companion',
      debugShowCheckedModeBanner: false,
      theme: buildCompanionTheme(),
      scaffoldMessengerKey: messengerKey,
      home: showOnboarding ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}

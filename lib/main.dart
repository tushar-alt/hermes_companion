import 'package:flutter/material.dart';

import 'notifications.dart';
import 'onboarding.dart';
import 'screens/home_screen.dart';
import 'storage.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  await initForegroundService();
  final prefs = await AppPrefs.load();
  runApp(CompanionApp(showOnboarding: !prefs.onboarded));
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key, this.showOnboarding = false});

  /// True on the very first launch: route to the pairing screen instead of
  /// the chat list. Persisted via `AppPrefs.onboarded`, so it only shows once.
  final bool showOnboarding;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hermes Companion',
      debugShowCheckedModeBanner: false,
      theme: buildCompanionTheme(),
      home: showOnboarding ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}

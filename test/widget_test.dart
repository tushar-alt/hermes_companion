import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hermes_companion/main.dart';

void main() {
  testWidgets('first run shows onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CompanionApp(showOnboarding: true));
    expect(find.textContaining('Welcome to Hermes Companion'), findsOneWidget);
  });

  testWidgets('onboarded app boots to chat list', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    await tester.pumpWidget(const CompanionApp());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(FloatingActionButton), findsOneWidget);
    // Unmount so the home screen's poll timer is disposed.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('info button opens the help drawer', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    await tester.pumpWidget(const CompanionApp());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Help & prompts'));
    await tester.pumpAndSettle();
    expect(find.text('Prompts'), findsOneWidget);
    expect(find.text('Help & prompts'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}

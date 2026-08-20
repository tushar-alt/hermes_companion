import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_companion/models.dart';
import 'package:hermes_companion/widgets/message_bubble.dart';

void main() {
  testWidgets('short message bubble is compact, not full width', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            child: MessageBubble(
              message: ChatMessage(
                  id: 1, role: 'assistant', text: 'hi', ts: 0),
              baseUrl: 'http://x',
              token: '',
            ),
          ),
        ),
      ),
    ));
    // The bubble content (IntrinsicWidth) must hug the text; the wrapping
    // row is intentionally full-width so user bubbles align right.
    final inner = tester.getSize(find.byType(IntrinsicWidth));
    expect(inner.width, lessThan(200),
        reason: 'bubble should hug its text, got ${inner.width}');
  });

  testWidgets('markdown bubble with a code block stays compact', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            child: MessageBubble(
              message: ChatMessage(
                  id: 2, role: 'assistant', text: 'short\n```\nprint(1)\n```', ts: 0),
              baseUrl: 'http://x',
              token: '',
            ),
          ),
        ),
      ),
    ));
    final inner = tester.getSize(find.byType(IntrinsicWidth));
    expect(inner.width, lessThan(400),
        reason: 'bubble should not fill the width, got ${inner.width}');
  });
}

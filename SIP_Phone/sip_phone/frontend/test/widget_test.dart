// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sip_phone/main.dart';

void main() {
  testWidgets('dialer starts a call', (WidgetTester tester) async {
    await tester.pumpWidget(const SipPhoneApp());

    expect(find.text('Softphone'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Dial a number'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Dial a number'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '123');
    await tester.pump();

    final callButton = find.text('Call');
    await tester.scrollUntilVisible(callButton, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(callButton);
    await tester.pump();

    expect(find.text('Calling...'), findsOneWidget);
    expect(find.text('End call'), findsOneWidget);
  });
}

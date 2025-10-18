// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:zego_test/main.dart';

void main() {
  testWidgets('Shows live start UI', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('البث المباشر'), findsOneWidget);
    expect(find.text('معرّف الغرفة (Room ID)'), findsOneWidget);
    expect(find.text('معرّف المستخدم (User ID)'), findsOneWidget);
  });
}

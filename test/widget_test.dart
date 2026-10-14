import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sw2627_flutter_revo_1/features/auth/role_based_router.dart';
import 'package:sw2627_flutter_revo_1/main.dart';

void main() {
  testWidgets('Revo app builds its role-based router shell',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RevoApp());

    expect(find.byType(RevoApp), findsOneWidget);
    expect(find.byType(RoleBasedRouter), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

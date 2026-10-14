import 'package:flutter_test/flutter_test.dart';
import 'package:sw2627_flutter_revo_1/features/auth/login_screen.dart';
import 'package:sw2627_flutter_revo_1/features/auth/role_based_router.dart';
import 'package:sw2627_flutter_revo_1/main.dart';

void main() {
  testWidgets('Revo app builds and boots to RoleBasedRouter shell and LoginScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RevoApp());

    expect(find.byType(RevoApp), findsOneWidget);
    expect(find.byType(RoleBasedRouter), findsOneWidget);

    // Pump to settle the auth stream
    await tester.pumpAndSettle();

    // Since mock auth starts unauthenticated, LoginScreen is displayed
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}

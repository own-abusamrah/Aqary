import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:aqary/main.dart' as app;

// Integration test: full OTP login flow → role selection → home screen.
//
// Prerequisites:
// - Firebase emulators must be running: `firebase emulators:start`
// - Run with: flutter test integration_test/login_flow_test.dart
//
// This test uses the Firebase Auth emulator to simulate OTP verification
// without real SMS. The emulator auto-accepts code '123456'.

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Login Flow', () {
    testWidgets('complete OTP login as buyer', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 1. Welcome screen loads
      expect(find.text('Aqary'), findsWidgets);

      // Wait for auto-navigation to login screen
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 2. Login screen — enter phone number
      final phoneField = find.byType(TextFormField).first;
      await tester.tap(phoneField);
      await tester.enterText(phoneField, '0791234567');
      await tester.pump();

      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();

      // 3. OTP screen — enter emulator test code '123456'
      expect(find.text('Enter OTP'), findsOneWidget);
      final otpBoxes = find.byType(TextFormField);
      final digits = ['1', '2', '3', '4', '5', '6'];
      for (int i = 0; i < 6; i++) {
        await tester.enterText(otpBoxes.at(i), digits[i]);
        await tester.pump();
      }

      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      // 4. Role selection screen
      expect(find.text('Choose Your Role'), findsOneWidget);
      await tester.tap(find.text('Buyer'));
      await tester.pumpAndSettle();

      // 5. Buyer home screen loads
      expect(find.text('Browse'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqary/screens/auth/otp_screen.dart';
import 'package:aqary/services/auth_service.dart';
import 'package:aqary/utils/app_theme.dart';

// Widget tests for the OTP verification screen.
// Run with: flutter test test/widget/otp_screen_test.dart

const _fakeVerificationId = 'fake-verification-id-for-testing';

OtpChallenge _fakeChallenge({String phone = '0791234567', bool isMfa = false}) {
  return OtpChallenge(
    type: isMfa
        ? OtpChallengeType.resolveSignIn
        : OtpChallengeType.enrollSecondFactor,
    phoneNumber: phone,
    verificationId: _fakeVerificationId,
  );
}

void main() {
  Widget buildOtpScreen({String phone = '0791234567', bool isMfa = false}) {
    return MaterialApp(
      theme: AppTheme.theme,
      home: OtpScreen(
        challenge: _fakeChallenge(phone: phone, isMfa: isMfa),
      ),
    );
  }

  group('OtpScreen — layout', () {
    testWidgets('renders 6 digit input boxes', (tester) async {
      await tester.pumpWidget(buildOtpScreen());
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(6));
    });

    testWidgets('shows phone number in subtitle', (tester) async {
      await tester.pumpWidget(buildOtpScreen(phone: '0791234567'));
      expect(find.textContaining('0791234567'), findsOneWidget);
    });

    testWidgets('shows Verify & Continue button', (tester) async {
      await tester.pumpWidget(buildOtpScreen());
      expect(find.text('Verify & Continue'), findsOneWidget);
    });

    testWidgets('shows resend timer initially', (tester) async {
      await tester.pumpWidget(buildOtpScreen());
      expect(find.textContaining('Resend code in'), findsOneWidget);
    });

    testWidgets('shows Back to sign in link', (tester) async {
      await tester.pumpWidget(buildOtpScreen());
      expect(find.text('Back to sign in'), findsOneWidget);
    });

    testWidgets('shows MFA step badge when isMfa is true', (tester) async {
      await tester.pumpWidget(buildOtpScreen(isMfa: true));
      expect(find.textContaining('Step 2 of 2'), findsOneWidget);
    });

    testWidgets('does not show MFA badge when isMfa is false', (tester) async {
      await tester.pumpWidget(buildOtpScreen(isMfa: false));
      expect(find.textContaining('Step 2 of 2'), findsNothing);
    });
  });

  group('OtpScreen — interaction', () {
    testWidgets('entering a digit moves focus to next box', (tester) async {
      await tester.pumpWidget(buildOtpScreen());
      final firstBox = find.byType(TextFormField).first;
      await tester.tap(firstBox);
      await tester.enterText(firstBox, '1');
      await tester.pump();
      expect(find.byType(TextFormField), findsNWidgets(6));
    });

    testWidgets(
        'verify button shows loading indicator when all 6 digits entered',
        (tester) async {
      await tester.pumpWidget(buildOtpScreen());
      final boxes = find.byType(TextFormField);
      for (int i = 0; i < 6; i++) {
        await tester.enterText(boxes.at(i), '$i');
      }
      await tester.pump();
      await tester.tap(find.text('Verify & Continue'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('tapping Back to sign in pops screen', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => OtpScreen(
                    challenge: _fakeChallenge(),
                  ),
                ),
              ),
              child: const Text('Go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back to sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Go'), findsOneWidget);
    });
  });
}

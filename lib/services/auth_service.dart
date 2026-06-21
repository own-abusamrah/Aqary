import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firebase.dart';
import 'recaptcha_cleanup.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  int? _resendToken;
  String _pendingPhone = '';
  String _pendingRole = 'buyer';

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
    required void Function(OtpChallenge challenge) onOtpSent,
    required void Function(String message) onError,
  }) async {
    try {
      final credential = await Firebase.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      await Firebase.call('savePendingRegistration', {
        'name': name,
        'email': email,
        'phone': '+962$phone',
        'role': role,
      });
      await credential.user?.sendEmailVerification();

      _pendingPhone = phone;
      _pendingRole = role;
      
      onError(
        'We sent a verification email to $email. '
        'Please verify your email first, then sign in to complete phone verification.',
      );
      return;
    } on FirebaseAuthException catch (e) {
      _clearPending();
      onError(_friendlyAuthError(e.code));
    } catch (e, st) {
      _clearPending();
      debugPrint('[AuthService.register] unexpected error: $e\n$st');
      onError('Registration failed. Please try again.');
    }
  }

  Future<void> login({
    required String email,
    required String phone,
    required String password,
    required void Function(OtpChallenge challenge) onOtpSent,
    required void Function(String message) onError,
  }) async {
    _pendingPhone = phone;
    _pendingRole = 'buyer';

    try {
      await Firebase.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = Firebase.auth.currentUser;
      if (user == null) {
        throw AuthException('Session expired. Please sign in again.');
      }

      await user.reload();
      final refreshedUser = Firebase.auth.currentUser;
      if (refreshedUser == null) {
        throw AuthException('Session expired. Please sign in again.');
      }

      if (!refreshedUser.emailVerified) {
        await refreshedUser.sendEmailVerification();
        await Firebase.auth.signOut();
        _clearPending();
        onError(
          'Please verify your email first. '
          'We sent a verification email to ${refreshedUser.email ?? email}.',
        );
        return;
      }

      final enrolledFactors =
          await refreshedUser.multiFactor.getEnrolledFactors();
      final hasPhoneFactor = enrolledFactors.whereType<PhoneMultiFactorInfo>().isNotEmpty;

      if (!hasPhoneFactor) {
        await _startEnrollmentChallenge(
          phoneNumber: '+962$phone',
          onOtpSent: onOtpSent,
          onError: onError,
        );
        return;
      }

      // If MFA is enabled correctly, signInWithEmailAndPassword should throw
      // before this point for enrolled accounts. Surface a clear message instead
      // of leaving the UI waiting forever.
      await Firebase.auth.signOut();
      _clearPending();
      onError(
        'Phone verification is not fully enabled for this account yet. '
        'Please try again after MFA is enabled in Firebase Console.',
      );
      return;
    } on FirebaseAuthMultiFactorException catch (e) {
      await _startLoginMfaChallenge(
        exception: e,
        fallbackPhone: '+962$phone',
        onOtpSent: onOtpSent,
        onError: onError,
      );
    } on FirebaseAuthException catch (e) {
      _clearPending();
      onError(_friendlyAuthError(e.code));
    } on AuthException {
      _clearPending();
      onError('Login failed. Please try again.');
    } catch (e, st) {
      _clearPending();
      debugPrint('[AuthService.login] unexpected error: $e\n$st');
      onError('Login failed. Please try again.');
    }
  }

  Future<({bool isNewUser, String role})> verifyOtp({
    required String otpCode,
    required OtpChallenge challenge,
    required String? fcmToken,
  }) async {
    try {
      if (challenge.verificationId == null || challenge.verificationId!.isEmpty) {
        throw AuthException('Verification session invalid. Please resend OTP.');
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: challenge.verificationId!,
        smsCode: otpCode,
      );

      switch (challenge.type) {
        case OtpChallengeType.enrollSecondFactor:
          final user = Firebase.auth.currentUser;
          if (user == null) {
            throw AuthException('Session expired. Please sign in again.');
          }

          await user.multiFactor.enroll(
            PhoneMultiFactorGenerator.getAssertion(credential),
            displayName: challenge.factorDisplayName ?? challenge.phoneNumber,
          );
          debugPrint('[AuthService.verifyOtp] second factor enrolled');

          await Firebase.auth.currentUser?.reload();
          await Firebase.auth.currentUser?.getIdToken(true);
          final freshUser = Firebase.auth.currentUser;
          if (freshUser == null) {
            throw AuthException(
              'Session expired after verification. Please log in again.',
            );
          }

          final result = await _completeRegisterOrLoginUser(
            freshUser: freshUser,
            fcmToken: fcmToken,
            resolvedPhone: challenge.phoneNumber,
          );
          if (kIsWeb) {
            cleanupRecaptchaArtifacts();
          }
          _clearPending();
          return result;

        case OtpChallengeType.resolveSignIn:
          final resolver = challenge.resolver;
          if (resolver == null) {
            throw AuthException('Verification session invalid. Please resend OTP.');
          }

          await resolver.resolveSignIn(
            PhoneMultiFactorGenerator.getAssertion(credential),
          );
          debugPrint('[AuthService.verifyOtp] MFA sign-in resolved');

          await Firebase.auth.currentUser?.reload();
          await Firebase.auth.currentUser?.getIdToken(true);
          final freshUser = Firebase.auth.currentUser;
          if (freshUser == null) {
            throw AuthException(
              'Session expired after verification. Please log in again.',
            );
          }

          final result = await _completeRegisterOrLoginUser(
            freshUser: freshUser,
            fcmToken: fcmToken,
            resolvedPhone: challenge.phoneNumber,
          );
          if (kIsWeb) {
            cleanupRecaptchaArtifacts();
          }
          _clearPending();
          return result;
      }
    } on AuthException {
      _clearPending();
      rethrow;
    } on FirebaseAuthException catch (e) {
      _clearPending();
      debugPrint('[AuthService.verifyOtp] FirebaseAuthException: '
          'code=${e.code} message=${e.message}');
      throw AuthException(_friendlyAuthError(e.code));
    } catch (e, st) {
      _clearPending();
      debugPrint('[AuthService.verifyOtp] unexpected error: $e\n$st');
      throw AuthException(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _startEnrollmentChallenge({
    required String phoneNumber,
    required void Function(OtpChallenge challenge) onOtpSent,
    required void Function(String message) onError,
  }) async {
    final user = Firebase.auth.currentUser;
    if (user == null) {
      onError('Session expired. Please sign in again.');
      return;
    }

    final session = await user.multiFactor.getSession();
    if (kIsWeb) {
      cleanupRecaptchaArtifacts();
    }
    await Firebase.auth.verifyPhoneNumber(
      multiFactorSession: session,
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (_) {},
      verificationFailed: (FirebaseAuthException e) {
        debugPrint('[AuthService._startEnrollmentChallenge] verificationFailed: '
            'code=${e.code} message=${e.message}');
        onError(_friendlyAuthError(e.code));
      },
      codeSent: (String verificationId, int? resendToken) {
        _resendToken = resendToken;
        onOtpSent(
          OtpChallenge(
            type: OtpChallengeType.enrollSecondFactor,
            phoneNumber: phoneNumber,
            verificationId: verificationId,
            factorDisplayName: _pendingPhone,
          ),
        );
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> _startLoginMfaChallenge({
    required FirebaseAuthMultiFactorException exception,
    required String fallbackPhone,
    required void Function(OtpChallenge challenge) onOtpSent,
    required void Function(String message) onError,
  }) async {
    final phoneHints = exception.resolver.hints.whereType<PhoneMultiFactorInfo>();
    final phoneHint = phoneHints.isEmpty ? null : phoneHints.first;
    if (phoneHint == null) {
      onError('No phone factor is enrolled for this account.');
      return;
    }

    if (kIsWeb) {
      cleanupRecaptchaArtifacts();
    }
    await Firebase.auth.verifyPhoneNumber(
      multiFactorSession: exception.resolver.session,
      multiFactorInfo: phoneHint,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (_) {},
      verificationFailed: (FirebaseAuthException e) {
        debugPrint('[AuthService._startLoginMfaChallenge] verificationFailed: '
            'code=${e.code} message=${e.message}');
        onError(_friendlyAuthError(e.code));
      },
      codeSent: (String verificationId, int? resendToken) {
        _resendToken = resendToken;
        onOtpSent(
          OtpChallenge(
            type: OtpChallengeType.resolveSignIn,
            phoneNumber: fallbackPhone,
            verificationId: verificationId,
            resolver: exception.resolver,
            factorDisplayName: _pendingPhone,
          ),
        );
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<({bool isNewUser, String role})> _completeRegisterOrLoginUser({
    required User freshUser,
    required String? fcmToken,
    required String resolvedPhone,
  }) async {
    debugPrint('[AuthService] calling registerOrLoginUser '
        'uid=${freshUser.uid} phone=$resolvedPhone');

    final Map<String, dynamic> result;
    try {
      result = await Firebase.call('registerOrLoginUser', {
        'name': freshUser.displayName ?? '',
        'phone': resolvedPhone,
        'email': freshUser.email ?? '',
        'role': _pendingRole,
        'fcmToken': fcmToken,
      });
    } catch (e, st) {
      debugPrint('[AuthService] registerOrLoginUser failed: $e\n$st');
      throw AuthException(
        'Account setup failed: ${e.toString().replaceAll("Exception: ", "")}',
      );
    }

    return (
      isNewUser: result['isNewUser'] as bool,
      role: result['role'] as String,
    );
  }

  void _clearPending() {
    _pendingPhone = '';
    _pendingRole = 'buyer';
  }

  Future<void> logout() async {
    _clearPending();
    try {
      await Firebase.call('onLogout');
    } catch (_) {}
    await Firebase.auth.signOut();
  }

  User? get currentUser => Firebase.auth.currentUser;
  Stream<User?> get authStateChanges => Firebase.auth.authStateChanges();

  String _friendlyAuthError(String code) {
    return switch (code) {
      'email-already-in-use' => 'An account with this email already exists.',
      'invalid-email' => 'Please enter a valid email address.',
      'weak-password' => 'Password must be at least 6 characters.',
      'user-not-found' => 'No account found with this email.',
      'wrong-password' => 'Incorrect password. Please try again.',
      'invalid-credential' => 'Incorrect email or password.',
      'multi-factor-auth-required' => 'Please complete phone verification.',
      'unverified-email' =>
        'Please verify your email first, then try phone verification again.',
      'second-factor-already-in-use' =>
        'This phone number is already enrolled on another account.',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      'invalid-verification-code' => 'Incorrect OTP code. Please try again.',
      'invalid-verification-id' =>
        'Verification session invalid. Please resend OTP.',
      'session-expired' => 'OTP expired. Please request a new one.',
      'invalid-phone-number' => 'Invalid phone number format.',
      'quota-exceeded' => 'SMS quota exceeded. Please try again later.',
      'network-request-failed' =>
        'Phone verification could not start. Please refresh the page and try again.',
      'captcha-check-failed' =>
        'Phone verification failed. Please refresh and try again.',
      'user-disabled' => 'This account has been disabled.',
      _ => 'Something went wrong ($code). Please try again.',
    };
  }
}

enum OtpChallengeType {
  enrollSecondFactor,
  resolveSignIn,
}

class OtpChallenge {
  final OtpChallengeType type;
  final String phoneNumber;
  final String? verificationId;
  final MultiFactorResolver? resolver;
  final String? factorDisplayName;

  const OtpChallenge({
    required this.type,
    required this.phoneNumber,
    this.verificationId,
    this.resolver,
    this.factorDisplayName,
  });
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

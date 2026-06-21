import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../utils/app_theme.dart';
import '../../services/services.dart';
import '../buyer/buyer_home_screen.dart';
import '../seller/seller_home_screen.dart';
import '../provider/provider_profile_screen.dart';
import '../admin/admin_dashboard_screen.dart';

class OtpScreen extends StatefulWidget {
  final OtpChallenge challenge;
  final bool isMfa;

  const OtpScreen({
    super.key,
    required this.challenge,
    this.isMfa = false,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String _debugStatus = '';
  int _resendSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _onDigitEntered(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otpCode.length == 6) _verifyOtp();
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the complete 6-digit code')),
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _debugStatus = 'Getting FCM token...';
    });

    try {
      final fcmToken = await FcmService.instance.getToken();

      // verifyOtp returns the resolved role:
      // - New user (register): role equals what was selected on RegisterScreen.
      // - Existing user (login): role comes from Firestore via Cloud Function.
      if (mounted) setState(() => _debugStatus = 'Verifying OTP...');
      final result = await AuthService.instance.verifyOtp(
        otpCode: _otpCode,
        challenge: widget.challenge,
        fcmToken: fcmToken,
      );

      if (mounted) {
        _navigateToHome(result.role);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  /// Navigate to the correct home screen based on the resolved role.
  /// Replaces the entire auth stack so the user cannot press back.
  void _navigateToHome(String role) {
    final Widget home = switch (role) {
      'seller' => const SellerHomeScreen(),
      'provider' => const ProviderProfileScreen(isEditing: false),
      'admin' => const AdminDashboardScreen(),
      _ => const BuyerHomeScreen(), // 'buyer' and any unknown role
    };

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => home),
      (route) => false, // remove entire back stack
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Verification'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textDark,
      ),
      body: SafeArea(
        // تم إضافة SingleChildScrollView هنا
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step badge
                if (widget.isMfa)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 14, color: AppTheme.primary),
                        SizedBox(width: 6),
                        Text(
                          'Step 2 of 2 — Two-Factor Verification',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                const Text('Enter OTP',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark)),
                const SizedBox(height: 8),
                Text(
                  'A 6-digit verification code was sent to\n${widget.challenge.phoneNumber}',
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textMuted, height: 1.5),
                ),
                const SizedBox(height: 40),

                // 6 digit input boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: 48,
                      height: 56,
                      child: TextFormField(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppTheme.primary, width: 2),
                          ),
                        ),
                        onChanged: (v) => _onDigitEntered(i, v),
                        onEditingComplete: () {
                          if (_controllers[i].text.isEmpty) _onBackspace(i);
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                // Debug status — only visible in debug builds
                if (kDebugMode && _debugStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFD0FF)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline,
                            size: 14, color: Color(0xFF3B5BDB)),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(_debugStatus,
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF3B5BDB)))),
                      ]),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Verify & Continue'),
                ),
                const SizedBox(height: 24),

                Center(
                  child: _resendSeconds > 0
                      ? Text('Resend code in ${_resendSeconds}s',
                          style: const TextStyle(color: AppTheme.textMuted))
                      : TextButton(
                          // Going back re-triggers sendOtp in login/register screen
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Resend OTP',
                              style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () {
                      // Pop back to step 1 (register or login)
                      Navigator.of(context)
                        ..pop()
                        ..pop();
                    },
                    child: const Text('Back to sign in',
                        style: TextStyle(color: AppTheme.textMuted)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

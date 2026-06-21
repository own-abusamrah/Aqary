import 'package:firebase_core/firebase_core.dart' as firebasecore;
//import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'services/services.dart';
import 'utils/app_theme.dart';
import 'screens/auth/welcome_screen.dart';
import 'firebase_options.dart';

/// ─── Emulator configuration ──────────────────────────────────────────────────
///
/// Set [_useEmulators] to true when running against local Firebase emulators.
/// Set [_deviceHost] when testing on a REAL DEVICE (not an emulator/simulator):
///   - Run `ifconfig` / `ipconfig` on your dev machine to find its LAN IP.
///   - Set _deviceHost to that IP, e.g. '192.168.1.42'.
///   - Leave null when running on an Android emulator or iOS simulator.
///
/// Android emulator → host is automatically set to 10.0.2.2 (handled in firebase.dart)
/// iOS simulator   → host is automatically set to localhost
/// Real device     → set _deviceHost to your machine's LAN IP
///
const bool _useEmulators = false;
const String? _deviceHost = null; // e.g. '192.168.1.42' for real device testing

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase core
  await firebasecore.Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);

  // 2. Point ALL services to emulators BEFORE any other Firebase call.
  //    Must come before runApp() and before FcmService.initialize().
  if (_useEmulators) {
    Firebase.useEmulators(deviceHost: _deviceHost);
  }

  // 3. Initialize FCM (notification channels, background handler)
  await FcmService.instance.initialize();

  // 4. Request notification permission from the user (iOS + Android 13+)
  await FcmService.instance.requestPermission();

  runApp(const AqaryApp());
}

class AqaryApp extends StatelessWidget {
  const AqaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aqary',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return const WelcomeScreen();
      },
    );
  }
}

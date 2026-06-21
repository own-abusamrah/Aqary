import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Central access point for all Firebase service instances.
/// Always use these getters — never use FirebaseAuth.instance,
/// FirebaseFirestore.instance, etc. directly in screens or services,
/// because this class is the single point where emulator routing is applied.
class Firebase {
  Firebase._();

  static FirebaseAuth     get auth      => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseStorage  get storage   => FirebaseStorage.instance;
  static FirebaseMessaging get messaging => FirebaseMessaging.instance;
  static FirebaseFunctions get functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Convenience: call a named Cloud Function and return its data.
  static Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic>? params,
  ]) async {
    final result = await functions.httpsCallable(name).call(params ?? {});
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// The correct host to use for emulators depending on platform:
  ///   - Android emulator : 10.0.2.2  (emulator's alias for host loopback)
  ///   - iOS simulator    : localhost  (shares host network)
  ///   - Real device      : LAN IP of your dev machine (e.g. 192.168.1.x)
  ///                        Set [deviceHost] in main.dart when testing on device.
  static String get _emulatorHost {
    if (kIsWeb) return 'localhost';
    if (Platform.isAndroid) return '10.0.2.2';
    return 'localhost'; // iOS simulator
  }

  /// Switch all Firebase services to local emulators.
  ///
  /// Call immediately after Firebase.initializeApp() in main(), before
  /// any other Firebase access, and BEFORE runApp().
  ///
  /// For a real device on the same LAN, override [deviceHost] with the
  /// IP of your development machine:
  ///   Firebase.useEmulators(deviceHost: '192.168.1.42');
  static void useEmulators({String? deviceHost}) {
    final host = deviceHost ?? _emulatorHost;
    debugPrint('[Firebase] Using emulators on $host');

    auth.useAuthEmulator(host, 9099);
    firestore.useFirestoreEmulator(host, 8080);
    storage.useStorageEmulator(host, 9199);
    functions.useFunctionsEmulator(host, 5001);
  }
}

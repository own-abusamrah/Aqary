import 'dart:async';
//import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _listingsChannel = AndroidNotificationChannel(
    'listings',
    'New Listings',
    description: 'Alerts for new land listings near you',
    importance: Importance.high,
  );
  static const _contactChannel = AndroidNotificationChannel(
    'contact_requests',
    'Contact Requests',
    description: 'Seller and buyer contact request updates',
    importance: Importance.high,
  );
  static const _broadcastChannel = AndroidNotificationChannel(
    'broadcasts',
    'Announcements',
    description: 'Platform announcements from Aqary',
    importance: Importance.defaultImportance,
  );

  void Function(RemoteMessage message)? onNotificationTap;

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_listingsChannel);
    await androidPlugin?.createNotificationChannel(_contactChannel);
    await androidPlugin?.createNotificationChannel(_broadcastChannel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Notification tapped while app is in foreground
        // Payload contains the FCM data encoded as JSON
      },
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp
        .listen((msg) => onNotificationTap?.call(msg));

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) onNotificationTap?.call(initial);

    // Listen for token refreshes and update Firestore.
    // Only updates the fcmToken field — does not touch name, email, or role.
    Firebase.messaging.onTokenRefresh.listen((newToken) async {
      final uid = Firebase.auth.currentUser?.uid;
      if (uid == null) return;
      try {
        await Firebase.firestore
            .collection('users')
            .doc(uid)
            .update({'fcmToken': newToken});
      } catch (_) {}
    });
  }

  Future<bool> requestPermission() async {
    final settings = await Firebase.messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<String?> getToken() async => Firebase.messaging.getToken();

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] ?? 'broadcast';
    final channelId = switch (type) {
      'new_listing' => _listingsChannel.id,
      'premium_new_listing' => _listingsChannel.id,
      'listing_updated' => _listingsChannel.id,
      'premium_listing_updated' => _listingsChannel.id,
      'contact_request' ||
      'contact_approved' ||
      'contact_rejected' =>
        _contactChannel.id,
      _ => _broadcastChannel.id,
    };

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId,
          icon:
              message.notification?.android?.smallIcon ?? '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}

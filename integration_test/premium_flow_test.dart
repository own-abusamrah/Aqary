//import 'dart:async';

import 'package:aqary/firebase_options.dart';
import 'package:aqary/models/models.dart';
import 'package:aqary/services/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' as firebasecore;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String adminEmail;
  late String buyerEmail;
  late String sellerEmail;
  const password = 'Password123!';
  const adminPhone = '+962790100001';
  const buyerPhone = '+962790100002';
  const sellerPhone = '+962790100003';
  String? buyerUid;
  String? sellerUid;

  Future<void> ensureInitialized() async {
    if (firebasecore.Firebase.apps.isEmpty) {
      await firebasecore.Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      Firebase.useEmulators();
    }
  }

  Future<void> signInOrCreate({
    required String email,
    required String password,
    required String role,
    required String phone,
  }) async {
    try {
      await Firebase.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        await Firebase.auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        rethrow;
      }
    }

    await Firebase.call('registerOrLoginUser', {
      'phone': phone,
      'role': role,
      'fcmToken': null,
    });
  }

  Future<void> signOut() => Firebase.auth.signOut();

  Future<void> waitForNotification({
    required String userId,
    required String type,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      final snap = await Firebase.firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: type)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    fail('Timed out waiting for notification type=$type for user=$userId');
  }

  setUpAll(() async {
    await ensureInitialized();
    final suffix = DateTime.now().millisecondsSinceEpoch;
    adminEmail = 'admin_$suffix@aqary.test';
    buyerEmail = 'buyer_$suffix@aqary.test';
    sellerEmail = 'seller_$suffix@aqary.test';

    await signInOrCreate(
      email: adminEmail,
      password: password,
      role: 'admin',
      phone: adminPhone,
    );
    await signOut();

    await signInOrCreate(
      email: buyerEmail,
      password: password,
      role: 'buyer',
      phone: buyerPhone,
    );
    buyerUid = Firebase.auth.currentUser!.uid;
    await signOut();

    await signInOrCreate(
      email: sellerEmail,
      password: password,
      role: 'seller',
      phone: sellerPhone,
    );
    sellerUid = Firebase.auth.currentUser!.uid;
    await signOut();
  });

  tearDown(() async {
    if (Firebase.auth.currentUser != null) {
      await signOut();
    }
  });

  group('Premium buyer flow', () {
    testWidgets('buyer becomes premium only after admin approval and can save 5 pins', (_) async {
      await signInOrCreate(
        email: buyerEmail,
        password: password,
        role: 'buyer',
        phone: buyerPhone,
      );

      await PremiumService.instance.requestPremiumSubscription();

      var buyerDoc =
          await Firebase.firestore.collection('users').doc(buyerUid).get();
      expect(buyerDoc.data()?['subscriptionPlan'], equals('free'));
      expect(buyerDoc.data()?['subscriptionStatus'], equals('pending'));

      await signOut();
      await signInOrCreate(
        email: adminEmail,
        password: password,
        role: 'admin',
        phone: adminPhone,
      );

      final requests = await PremiumService.instance.getPremiumRequests();
      expect(requests.any((u) => u.uid == buyerUid), isTrue);

      await PremiumService.instance.adminSetPremiumSubscription(
        targetUid: buyerUid!,
        action: 'approve',
      );

      buyerDoc =
          await Firebase.firestore.collection('users').doc(buyerUid).get();
      expect(buyerDoc.data()?['subscriptionPlan'], equals('premium'));
      expect(buyerDoc.data()?['subscriptionStatus'], equals('active'));

      await signOut();
      await signInOrCreate(
        email: buyerEmail,
        password: password,
        role: 'buyer',
        phone: buyerPhone,
      );

      for (var i = 0; i < 5; i++) {
        await PremiumService.instance.upsertPremiumPin(
          latitude: 31.95 + (i * 0.001),
          longitude: 35.91 + (i * 0.001),
          radiusKm: 5,
          label: 'Pin ${i + 1}',
        );
      }

      final pins = await PremiumService.instance.getMyPremiumPins();
      expect(pins.length, equals(5));

      await expectLater(
        PremiumService.instance.upsertPremiumPin(
          latitude: 31.97,
          longitude: 35.93,
          radiusKm: 5,
          label: 'Pin 6',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Premium seller flow', () {
    testWidgets('seller becomes premium after admin approval, can broadcast, and triggers premium listing alerts', (_) async {
      await signInOrCreate(
        email: sellerEmail,
        password: password,
        role: 'seller',
        phone: sellerPhone,
      );

      await PremiumService.instance.requestPremiumSubscription();
      await signOut();

      await signInOrCreate(
        email: adminEmail,
        password: password,
        role: 'admin',
        phone: adminPhone,
      );
      await PremiumService.instance.adminSetPremiumSubscription(
        targetUid: sellerUid!,
        action: 'approve',
      );
      await signOut();

      await signInOrCreate(
        email: sellerEmail,
        password: password,
        role: 'seller',
        phone: sellerPhone,
      );

      await PremiumService.instance.sellerSendBroadcast(
        title: 'Premium Seller Update',
        body: 'A new premium seller message for all buyers.',
      );

      await waitForNotification(
        userId: buyerUid!,
        type: 'seller_broadcast',
      );

      final listingId = await ListingService.instance.createListing(
        LandListing(
          id: '',
          sellerId: sellerUid!,
          plotNumber: 'A-101',
          landType: 'Residential',
          size: 600,
          price: 120000,
          area: 'Abdoun',
          description: 'Premium test listing',
          photoUrls: const ['https://example.com/fake.jpg'],
          latitude: 31.95,
          longitude: 35.91,
          status: 'active',
          createdAt: DateTime.now(),
        ),
      );

      expect(listingId.isNotEmpty, isTrue);

      await waitForNotification(
        userId: buyerUid!,
        type: 'premium_new_listing',
      );
    });
  });
}

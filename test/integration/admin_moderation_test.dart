import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:aqary/services/services.dart';

// Integration test: admin moderation actions against emulators.
// Tests block/unblock user, hide/show listing, hide/show provider.
//
// Prerequisites:
// - Firebase emulators running
// - An admin account must be signed in before running these tests
// Run with: flutter test integration_test/admin_moderation_test.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Admin — User Moderation', () {
    setUp(() => Firebase.useEmulators());

    test('getUsers returns list of users', () async {
      final users = await AdminService.instance.getUsers();
      // Emulator should have at least the seeded test users
      expect(users, isA<List>());
    });

    test('getUsers filtered by role returns only matching users', () async {
      final buyers = await AdminService.instance.getUsers(role: 'buyer');
      for (final user in buyers) {
        expect(user.role, equals('buyer'));
      }
    });

    test('blockUser sets isBlocked to true', () async {
      const targetUid = 'buyer-uid-emulator';
      await AdminService.instance.blockUser(targetUid);

      // Verify via Firestore read
      final doc = await Firebase.firestore.collection('users').doc(targetUid).get();
      expect(doc.data()?['isBlocked'], isTrue);
    });

    test('unblockUser sets isBlocked to false', () async {
      const targetUid = 'buyer-uid-emulator';
      await AdminService.instance.unblockUser(targetUid);

      final doc = await Firebase.firestore.collection('users').doc(targetUid).get();
      expect(doc.data()?['isBlocked'], isFalse);
    });
  });

  group('Admin — Listing Moderation', () {
    setUp(() => Firebase.useEmulators());

    test('hideListing sets status to hidden', () async {
      const listingId = 'test-listing-emulator';
      await AdminService.instance.hideListing(listingId);

      final doc = await Firebase.firestore.collection('listings').doc(listingId).get();
      expect(doc.data()?['status'], equals('hidden'));
    });

    test('showListing sets status back to active', () async {
      const listingId = 'test-listing-emulator';
      await AdminService.instance.showListing(listingId);

      final doc = await Firebase.firestore.collection('listings').doc(listingId).get();
      expect(doc.data()?['status'], equals('active'));
    });
  });

  group('Admin — Provider Moderation', () {
    setUp(() => Firebase.useEmulators());

    test('hideProvider sets isHidden to true', () async {
      const providerId = 'provider-uid-emulator';
      await AdminService.instance.hideProvider(providerId);

      final doc = await Firebase.firestore.collection('providers').doc(providerId).get();
      expect(doc.data()?['isHidden'], isTrue);
    });

    test('showProvider sets isHidden to false', () async {
      const providerId = 'provider-uid-emulator';
      await AdminService.instance.showProvider(providerId);

      final doc = await Firebase.firestore.collection('providers').doc(providerId).get();
      expect(doc.data()?['isHidden'], isFalse);
    });
  });
}

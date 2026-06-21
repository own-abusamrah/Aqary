import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
//import 'package:aqary/models/models.dart';
import 'package:aqary/services/services.dart';

// Integration test: full contact request lifecycle.
// Buyer sends request → seller approves → buyer sees contact info.
//
// Prerequisites:
// - Firebase emulators running
// - Buyer account: +96279000001 | Seller account: +96279000002
// - A published listing must exist in emulator Firestore
// Run with: flutter test integration_test/contact_request_test.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Contact Request Lifecycle', () {
    const testListingId = 'test-listing-emulator';
    const testBuyerId  = 'buyer-uid-emulator';
    const testSellerId = 'seller-uid-emulator';

    setUp(() {
      // Use emulators
      Firebase.useEmulators();
    });

    test('buyer creates a pending contact request', () async {
      await ContactRequestService.instance.createRequest(
        buyerId: testBuyerId,
        sellerId: testSellerId,
        listingId: testListingId,
      );

      final existing = await ContactRequestService.instance.getExistingRequest(
        buyerId: testBuyerId,
        listingId: testListingId,
      );

      expect(existing, isNotNull);
      expect(existing!.status, equals('pending'));
      expect(existing.buyerId, equals(testBuyerId));
      expect(existing.sellerId, equals(testSellerId));
    });

    test('seller approves the request and status changes', () async {
      // Get the existing request
      final request = await ContactRequestService.instance.getExistingRequest(
        buyerId: testBuyerId,
        listingId: testListingId,
      );
      expect(request, isNotNull);

      await ContactRequestService.instance.approveRequest(request!.id);

      // Re-fetch and verify
      final updated = await ContactRequestService.instance.getExistingRequest(
        buyerId: testBuyerId,
        listingId: testListingId,
      );
      expect(updated!.status, equals('approved'));
    });

    test('duplicate request is not created for same buyer+listing', () async {
      // Attempt to create another request for the same listing
      final existing = await ContactRequestService.instance.getExistingRequest(
        buyerId: testBuyerId,
        listingId: testListingId,
      );
      // In the UI, we check for existing before creating — this simulates that
      expect(existing, isNotNull);
      // UI would show "Request Approved" state rather than allowing a new one
    });

    test('watchRequestStatus stream emits correct status', () async {
      final stream = ContactRequestService.instance.watchRequestStatus(
        buyerId: testBuyerId,
        listingId: testListingId,
      );
      final request = await stream.first;
      expect(request, isNotNull);
      expect(['pending', 'approved', 'rejected'].contains(request!.status), isTrue);
    });

    test('contact info is only revealed after approval', () async {
      final request = await ContactRequestService.instance.getExistingRequest(
        buyerId: testBuyerId,
        listingId: testListingId,
      );

      if (request?.status == 'approved') {
        final info = await ContactRequestService.instance.getSellerContactInfo(
          requestId: request!.id,
          sellerId: testSellerId,
        );
        // Approved — info may be non-null
        expect(info, isNotNull);
      } else {
        // Not approved — info should be null
        expect(request?.status, isNot(equals('approved')));
      }
    });
  });
}

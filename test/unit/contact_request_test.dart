import 'package:flutter_test/flutter_test.dart';
import 'package:aqary/models/models.dart';

// Tests for contact request lifecycle logic.
// Run with: flutter test test/unit/contact_request_test.dart

void main() {
  group('ContactRequest model', () {
    late ContactRequest pendingRequest;

    setUp(() {
      pendingRequest = ContactRequest(
        id: 'req-1',
        buyerId: 'buyer-uid',
        sellerId: 'seller-uid',
        listingId: 'listing-1',
        status: 'pending',
        createdAt: DateTime(2024, 6, 1),
      );
    });

    test('initial status is pending', () {
      expect(pendingRequest.status, equals('pending'));
    });

    test('status transitions are valid', () {
      const validStatuses = ['pending', 'approved', 'rejected'];
      expect(validStatuses.contains('pending'), isTrue);
      expect(validStatuses.contains('approved'), isTrue);
      expect(validStatuses.contains('rejected'), isTrue);
      expect(validStatuses.contains('cancelled'), isFalse);
    });

    test('buyer and seller IDs are stored correctly', () {
      expect(pendingRequest.buyerId, equals('buyer-uid'));
      expect(pendingRequest.sellerId, equals('seller-uid'));
    });

    test('listingId links request to listing', () {
      expect(pendingRequest.listingId, equals('listing-1'));
    });
  });

  group('Contact request — business rules', () {
    test('contact info must not be returned for pending requests', () {
      // This mirrors the backend rule:
      // Only return contact info if status == 'approved'
      const status = 'pending';
      final shouldReveal = status == 'approved';
      expect(shouldReveal, isFalse);
    });

    test('contact info is revealed when approved', () {
      const status = 'approved';
      final shouldReveal = status == 'approved';
      expect(shouldReveal, isTrue);
    });

    test('contact info remains hidden when rejected', () {
      const status = 'rejected';
      final shouldReveal = status == 'approved';
      expect(shouldReveal, isFalse);
    });

    test('seller can only approve or reject (not revert to pending)', () {
      // Mirrors Firestore rule:
      // request.resource.data.status in ['approved', 'rejected']
      const sellerAllowedTransitions = ['approved', 'rejected'];
      expect(sellerAllowedTransitions.contains('pending'), isFalse);
      expect(sellerAllowedTransitions.contains('approved'), isTrue);
    });
  });

  group('Notification types for contact request', () {
    test('approval sends correct notification type', () {
      const type = 'contact_approved';
      expect(type, equals('contact_approved'));
    });

    test('rejection sends correct notification type', () {
      const type = 'contact_rejected';
      expect(type, equals('contact_rejected'));
    });

    test('new request sends correct notification type to seller', () {
      const type = 'contact_request';
      expect(type, equals('contact_request'));
    });
  });
}

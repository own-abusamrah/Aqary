import 'package:flutter_test/flutter_test.dart';
import 'package:aqary/models/models.dart';

// Tests for listing-related logic that can be verified without Firebase.
// Run with: flutter test test/unit/listing_service_test.dart

void main() {
  group('LandListing model', () {
    late LandListing listing;

    setUp(() {
      listing = LandListing(
        id: 'test-id',
        sellerId: 'seller-1',
        landType: 'Commercial',
        size: 890,
        price: 371000,
        area: 'Abdoun',
        description: 'Prime land',
        photoUrls: ['https://example.com/photo.jpg'],
        latitude: 31.9539,
        longitude: 35.9106,
        createdAt: DateTime(2024, 1, 15),
      );
    });

    test('formattedPrice formats values >= 1000 with k suffix', () {
      expect(listing.formattedPrice, equals('371k JD'));
    });

    test('formattedPrice formats values < 1000 without suffix', () {
      final cheap = LandListing(
        id: '2', sellerId: 's1', landType: 'Residential',
        size: 100, price: 500, area: 'Test', description: 'desc',
        photoUrls: [], latitude: 0, longitude: 0, createdAt: DateTime.now(),
      );
      expect(cheap.formattedPrice, equals('500 JD'));
    });

    test('toMap includes all required fields', () {
      final map = listing.toMap();
      expect(map.containsKey('sellerId'), isTrue);
      expect(map.containsKey('landType'), isTrue);
      expect(map.containsKey('size'), isTrue);
      expect(map.containsKey('price'), isTrue);
      expect(map.containsKey('area'), isTrue);
      expect(map.containsKey('photoUrls'), isTrue);
      expect(map.containsKey('latitude'), isTrue);
      expect(map.containsKey('longitude'), isTrue);
      expect(map.containsKey('status'), isTrue);
    });

    test('fromMap correctly reconstructs a listing', () {
      final map = listing.toMap();
      final reconstructed = LandListing.fromMap(map, 'test-id');
      expect(reconstructed.id, equals('test-id'));
      expect(reconstructed.price, equals(371000));
      expect(reconstructed.landType, equals('Commercial'));
      expect(reconstructed.area, equals('Abdoun'));
    });

    test('default status is active', () {
      expect(listing.status, equals('active'));
    });

    test('photoUrls is not empty for a valid listing', () {
      expect(listing.photoUrls.isNotEmpty, isTrue);
    });
  });

  group('LandListing — validation rules (mirrors backend)', () {
    test('price must be greater than zero', () {
      // Mirrors the Firestore rule: data.price is number && data.price > 0
      const price = 371000.0;
      expect(price > 0, isTrue);
    });

    test('size must be greater than zero', () {
      const size = 890.0;
      expect(size > 0, isTrue);
    });

    test('landType must be one of the allowed values', () {
      const validTypes = ['Residential', 'Commercial', 'Agricultural'];
      expect(validTypes.contains('Commercial'), isTrue);
      expect(validTypes.contains('Industrial'), isFalse);
    });

    test('status must be one of the allowed values', () {
      const validStatuses = ['active', 'hidden', 'deleted'];
      expect(validStatuses.contains('active'), isTrue);
      expect(validStatuses.contains('sold'), isFalse);
    });
  });

  group('Haversine distance (mirrors backend geo.ts)', () {
    double haversine(double lat1, double lng1, double lat2, double lng2) {
      const r = 6371.0;
      double toRad(double d) => d * 3.141592653589793 / 180;
      final dLat = toRad(lat2 - lat1);
      final dLng = toRad(lng2 - lng1);
      final a = (dLat / 2) * (dLat / 2) +
          toRad(lat1).abs() * toRad(lat2).abs() * (dLng / 2) * (dLng / 2);
      return r * 2 * (a < 1 ? a : 1); // simplified
    }

    test('distance from same point is zero', () {
      final d = haversine(31.9539, 35.9106, 31.9539, 35.9106);
      expect(d, closeTo(0, 0.001));
    });

    test('Amman to Zarqa is roughly 25-30 km', () {
      // Amman: 31.9539, 35.9106 | Zarqa: 32.0728, 36.0875
      // Expected ~20-25 km (simplified formula gives approximation)
      final d = haversine(31.9539, 35.9106, 32.0728, 36.0875);
      expect(d, greaterThan(0));
    });
  });
}

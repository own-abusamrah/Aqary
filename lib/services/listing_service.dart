import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/models.dart';
import 'firebase.dart';

class ListingService {
  ListingService._();
  static final ListingService instance = ListingService._();

  // ─── Read ────────────────────────────────────────────────

  /// Fetch paginated, filtered listings via Cloud Function.
  /// Pass [lastDocId] for subsequent pages.
  Future<({List<LandListing> listings, String? nextDocId, bool hasMore})>
      getListings({
    String? area,
    String? landType,
    double? minPrice,
    double? maxPrice,
    double? minSize,
    double? maxSize,
    String? lastDocId,
    int pageSize = 20,
  }) async {
    final result = await Firebase.call('getListings', {
      if (area != null) 'area': area,
      if (landType != null) 'landType': landType,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      if (minSize != null) 'minSize': minSize,
      if (maxSize != null) 'maxSize': maxSize,
      if (lastDocId != null) 'lastDocId': lastDocId,
      'pageSize': pageSize,
    });

    final rawList = result['listings'] as List<dynamic>;
    final listings = rawList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return LandListing.fromMap(map, map['id'] as String);
    }).toList();

    return (
      listings: listings,
      nextDocId: result['nextDocId'] as String?,
      hasMore: result['hasMore'] as bool,
    );
  }

  /// Real-time stream of a seller's own listings (My Lands screen).
  Stream<List<LandListing>> watchSellerListings(String sellerId) {
    return Firebase.firestore
        .collection('listings')
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LandListing.fromMap(
                  Map<String, dynamic>.from(doc.data()),
                  doc.id,
                ))
            .toList());
  }

  Stream<List<LandListing>> watchPublicSellerListings(String sellerId) {
    return Firebase.firestore
        .collection('listings')
        .where('sellerId', isEqualTo: sellerId)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LandListing.fromMap(
                  Map<String, dynamic>.from(doc.data()),
                  doc.id,
                ))
            .toList());
  }

  /// Fetch a single listing by ID.
  Future<LandListing?> getListing(String listingId) async {
    final doc =
        await Firebase.firestore.collection('listings').doc(listingId).get();

    if (!doc.exists) return null;

    return LandListing.fromMap(
      Map<String, dynamic>.from(doc.data()!),
      doc.id,
    );
  }

  // ─── Write ───────────────────────────────────────────────

  /// Upload photos to Firebase Storage and return their download URLs.
  /// Upload images to Firebase Storage using bytes (works on all platforms).
  /// [imageBytes] is a list of Uint8List — use XFile.readAsBytes() to get them.
  Future<List<String>> uploadPhotos({
    required String sellerId,
    required String listingId,
    required List<Uint8List> imageBytes,
  }) async {
    final urls = <String>[];

    for (int i = 0; i < imageBytes.length; i++) {
      final ref = Firebase.storage.ref(
        'listings/$sellerId/$listingId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
      );

      await ref.putData(
        imageBytes[i],
        SettableMetadata(contentType: 'image/jpeg'),
      );

      urls.add(await ref.getDownloadURL());
    }

    return urls;
  }

  /// Create a new land listing in Firestore.
  /// Photos should be uploaded first via [uploadPhotos].
  Future<String> createListing(LandListing listing) async {
    final docRef = await Firebase.firestore.collection('listings').add({
      ...listing.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // ملاحظة مهمة:
    // لا ننشئ notifications من Flutter هنا.
    // لأن Firestore Rules تمنع إنشاء notifications من التطبيق:
    // allow create: if false;
    //
    // الإشعارات يجب أن تُنشأ من Cloud Functions باستخدام Admin SDK.
    // لذلك حذفنا:
    // await _notifyBuyersNewListing(docRef.id, listing);

    return docRef.id;
  }

  /// Update an existing listing (seller editing their own).
  Future<void> updateListing(
    String listingId,
    Map<String, dynamic> fields,
  ) async {
    await Firebase.firestore.collection('listings').doc(listingId).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Soft delete — sets status to 'deleted' via Cloud Function (server-side verified).
  Future<void> deleteListing(String listingId) async {
    await Firebase.call('softDeleteListing', {'listingId': listingId});
  }

  /// Hide listing — sets status to 'hidden' so buyers can't see it.
  Future<void> hideListing(String listingId) async {
    await Firebase.firestore
        .collection('listings')
        .doc(listingId)
        .update({'status': 'hidden'});
  }

  /// Unhide listing — sets status back to 'active'.
  Future<void> unhideListing(String listingId) async {
    await Firebase.firestore
        .collection('listings')
        .doc(listingId)
        .update({'status': 'active'});
  }

  // ─── Favorites ───────────────────────────────────────────

  /// Add a listing to the current user's favorites subcollection.
  Future<void> addFavorite(String userId, String listingId) async {
    await Firebase.firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(listingId)
        .set({
      'listingId': listingId,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove from favorites.
  Future<void> removeFavorite(String userId, String listingId) async {
    await Firebase.firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(listingId)
        .delete();
  }

  /// Real-time stream of the user's favorited listing IDs.
  Stream<Set<String>> watchFavoriteIds(String userId) {
    return Firebase.firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  /// Real-time stream of full favorite listings.
  /// Fetches each listing individually so a single permission-denied
  /// (hidden/deleted listing) does not crash the whole query.
  Stream<List<LandListing>> watchFavoriteListings(String userId) async* {
    final favStream = Firebase.firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots();

    await for (final favSnap in favStream) {
      if (favSnap.docs.isEmpty) {
        yield <LandListing>[];
        continue;
      }

      final ids = favSnap.docs.map((d) => d.id).toList();
      final listings = <LandListing>[];

      for (final id in ids) {
        try {
          final doc =
              await Firebase.firestore.collection('listings').doc(id).get();
          if (doc.exists) {
            final listing = LandListing.fromMap(
              Map<String, dynamic>.from(doc.data()!),
              doc.id,
            );
            if (listing.status == 'active') {
              listings.add(listing);
            } else {
              // Silently remove hidden/deleted listings from favorites
              removeFavorite(userId, id);
            }
          } else {
            // Doc gone entirely — clean up
            removeFavorite(userId, id);
          }
        } catch (_) {
          // Permission denied or network error — skip silently
        }
      }

      yield listings;
    }
  }

  /// Fetch full listing documents for all favorited IDs.
  Future<List<LandListing>> getFavoriteListings(String userId) async {
    final favSnap = await Firebase.firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .get();

    if (favSnap.docs.isEmpty) return [];

    final ids = favSnap.docs.map((d) => d.id).toList();

    // Firestore 'whereIn' supports up to 30 items
    final chunks = <List<String>>[];

    for (int i = 0; i < ids.length; i += 30) {
      chunks.add(
        ids.sublist(
          i,
          i + 30 > ids.length ? ids.length : i + 30,
        ),
      );
    }

    final listings = <LandListing>[];

    for (final chunk in chunks) {
      final snap = await Firebase.firestore
          .collection('listings')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      listings.addAll(
        snap.docs
            .map(
              (d) => LandListing.fromMap(
                Map<String, dynamic>.from(d.data()),
                d.id,
              ),
            )
            .where((l) =>
                l.status != 'hidden' &&
                l.status != 'deleted'), // ← إخفاء المخفي والمحذوف فقط
      );
    }

    return listings;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'firebase.dart';

class ContactRequestService {
  ContactRequestService._();
  static final ContactRequestService instance = ContactRequestService._();

  // ─── Buyer side ──────────────────────────────────────────

  /// Check if the current buyer already has a request for this listing.
  /// Returns the existing request or null.
  Future<ContactRequest?> getExistingRequest({
    required String buyerId,
    required String listingId,
  }) async {
    final snap = await Firebase.firestore
        .collection('contact_requests')
        .where('buyerId', isEqualTo: buyerId)
        .where('listingId', isEqualTo: listingId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return ContactRequest.fromMap(
        Map<String, dynamic>.from(doc.data()), doc.id);
  }

  Future<ContactRequest?> getExistingRequestWithSeller({
    required String buyerId,
    required String sellerId,
  }) async {
    final snap = await Firebase.firestore
        .collection('contact_requests')
        .where('buyerId', isEqualTo: buyerId)
        .where('sellerId', isEqualTo: sellerId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    return ContactRequest.fromMap(
      Map<String, dynamic>.from(doc.data()),
      doc.id,
    );
}

  /// Create a new contact request from buyer to seller.
//   Future<void> createRequest({
//     required String buyerId,
//     required String sellerId,
//     required String listingId,
//   }) async {
//   //   await Firebase.firestore.collection('contact_requests').add({
//   //     'buyerId': buyerId,
//   //     'sellerId': sellerId,
//   //     'listingId': listingId,
//   //     'status': 'pending',
//   //     'createdAt': FieldValue.serverTimestamp(),
//   //     'updatedAt': FieldValue.serverTimestamp(),
//   //   });
//   // }
//   final requestId = '${buyerId}_$sellerId';

//   await Firebase.firestore
//       .collection('contact_requests')
//       .doc(requestId)
//       .set({
//     'buyerId': buyerId,
//     'sellerId': sellerId,
//     'listingId': listingId,
//     'status': 'pending',
//     'createdAt': FieldValue.serverTimestamp(),
//     'updatedAt': FieldValue.serverTimestamp(),
//   });
// }
Future<void> createRequest({
  required String buyerId,
  required String sellerId,
  required String listingId,
}) async {
  // 🔒 Check if already exists with this seller
  final existing = await getExistingRequestWithSeller(
    buyerId: buyerId,
    sellerId: sellerId,
  );

  if (existing != null) {
    throw Exception('You already have contact with this seller.');
  }

  final requestId = '${buyerId}_$sellerId';

  await Firebase.firestore
      .collection('contact_requests')
      .doc(requestId)
      .set({
    'buyerId': buyerId,
    'sellerId': sellerId,
    'listingId': listingId,
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
  /// Real-time stream of the request status for a specific listing.
  /// Used by the Land Details screen to update the contact button live.
  Stream<ContactRequest?> watchRequestStatus({
    required String buyerId,
    required String listingId,
  }) {
    return Firebase.firestore
        .collection('contact_requests')
        .where('buyerId', isEqualTo: buyerId)
        .where('listingId', isEqualTo: listingId)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return ContactRequest.fromMap(
          Map<String, dynamic>.from(doc.data()), doc.id);
    });
  }

  // ─── Seller side ─────────────────────────────────────────

  /// Real-time stream of all pending requests for a seller.
  /// Used by the Seller Notifications screen.
  Stream<List<ContactRequest>> watchPendingRequests(String sellerId) {
    return Firebase.firestore
        .collection('contact_requests')
        .where('sellerId', isEqualTo: sellerId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ContactRequest.fromMap(
                Map<String, dynamic>.from(doc.data()), doc.id))
            .toList());
  }

  /// Seller approves a contact request.
  Future<void> approveRequest(String requestId) async {
    await Firebase.firestore
        .collection('contact_requests')
        .doc(requestId)
        .update({
      'status': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // The [onContactRequestUpdated] Cloud Function will automatically
    // notify the buyer via FCM.
  }

  /// Seller rejects a contact request.
  Future<void> rejectRequest(String requestId) async {
    await Firebase.firestore
        .collection('contact_requests')
        .doc(requestId)
        .update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetch seller's contact info for a listing — only returned if
  /// the request is approved. Reads the seller's user document.
  Future<String?> getSellerContactInfo({
    required String requestId,
    required String sellerId,
  }) async {
    // Verify approval status first (defense in depth; rules also block this)
    final reqDoc = await Firebase.firestore
        .collection('contact_requests')
        .doc(requestId)
        .get();

    if (!reqDoc.exists) return null;
    final status = reqDoc.data()!['status'] as String;
    if (status != 'approved') return null;

    // Fetch seller's provider profile for contact info if they are a provider,
    // otherwise the contact info is stored on their user doc.
    final providerDoc = await Firebase.firestore
        .collection('providers')
        .doc(sellerId)
        .get();

    if (providerDoc.exists) {
      return providerDoc.data()!['contactInfo'] as String?;
    }

    // Fall back to phone number from user document
    final userDoc = await Firebase.firestore
        .collection('users')
        .doc(sellerId)
        .get();

    return userDoc.data()?['phone'] as String?;
  }

  // ─── Additional seller-side methods ────────────────────────────────────────

  /// Real-time stream of ALL requests for a seller (all statuses),
  /// ordered newest first. Powers the tabbed contact requests screen.
  Stream<List<ContactRequest>> watchAllSellerRequests(String sellerId) {
    return Firebase.firestore
        .collection('contact_requests')
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ContactRequest.fromMap(
                Map<String, dynamic>.from(doc.data()), doc.id))
            .toList());
  }

  /// Fetch buyer display info (name, phone, email) for a contact request card.
  Future<Map<String, String>> getBuyerInfo(String buyerId) async {
    final doc =
        await Firebase.firestore.collection('users').doc(buyerId).get();
    if (!doc.exists) return {'name': 'Unknown', 'phone': '', 'email': ''};
    final data = doc.data()!;
    return {
      'name':  data['name']  as String? ?? 'Unknown',
      'phone': data['phone'] as String? ?? '',
      'email': data['email'] as String? ?? '',
    };
  }

  /// Fetch listing summary info for display on a contact request card.
  Future<Map<String, String>> getListingInfo(String listingId) async {
    final doc = await Firebase.firestore
        .collection('listings')
        .doc(listingId)
        .get();
    if (!doc.exists) return {'title': 'Unknown listing', 'area': '', 'size': ''};
    final data = doc.data()!;
    return {
      'title': '${data['landType'] ?? ''} — '
               '${(data['price'] as num?)?.toStringAsFixed(0) ?? ''} JD',
      'area':  data['area'] as String? ?? '',
      'size':  '${(data['size'] as num?)?.toStringAsFixed(0) ?? ''} m²',
    };
  }
}

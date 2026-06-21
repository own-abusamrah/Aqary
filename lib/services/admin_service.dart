import '../models/models.dart';
import 'firebase.dart';

class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  // ─── Users ───────────────────────────────────────────────────────────────

  /// Fetches all users for the admin dashboard.
  /// Now returns name and email alongside phone and role.
  Future<List<AppUser>> getUsers({String? role}) async {
    final result = await Firebase.call('adminGetUsers', {
      if (role != null && role != 'all') 'role': role,
    });
    final rawList = result['users'] as List<dynamic>;
    return rawList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return AppUser.fromMap(map, map['uid'] as String);
    }).toList();
  }

  Future<void> blockUser(String targetUid) async {
    await Firebase.call('setUserBlocked', {
      'targetUid': targetUid,
      'blocked': true,
    });
  }

  Future<void> unblockUser(String targetUid) async {
    await Firebase.call('setUserBlocked', {
      'targetUid': targetUid,
      'blocked': false,
    });
  }

  Future<void> deleteUser(String targetUid) async {
    await Firebase.call('deleteUser', {'targetUid': targetUid});
  }

  // ─── Listings ─────────────────────────────────────────────────────────────

  Future<void> hideListing(String listingId) async {
    await Firebase.call('setListingStatus', {
      'listingId': listingId,
      'status': 'hidden',
    });
  }

  Future<void> showListing(String listingId) async {
    await Firebase.call('setListingStatus', {
      'listingId': listingId,
      'status': 'active',
    });
  }

  Future<void> deleteListing(String listingId) async {
    await Firebase.call('adminDeleteListing', {'listingId': listingId});
  }

  // ─── Providers ────────────────────────────────────────────────────────────

  Future<void> hideProvider(String providerId) async {
    await Firebase.call('setProviderHidden', {
      'providerId': providerId,
      'hidden': true,
    });
  }

  Future<void> showProvider(String providerId) async {
    await Firebase.call('setProviderHidden', {
      'providerId': providerId,
      'hidden': false,
    });
  }
}

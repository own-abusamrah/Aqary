import '../models/models.dart';
import 'firebase.dart';

class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  String? get _uid => Firebase.auth.currentUser?.uid;

  Future<void> requestPremiumSubscription() async {
    await Firebase.call('requestPremiumSubscription');
  }

  Stream<AppUser?> watchCurrentUser() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return Firebase.firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromMap(Map<String, dynamic>.from(doc.data()!), doc.id);
    });
  }

  Future<List<AppUser>> getPremiumRequests({List<String>? statuses}) async {
    final result = await Firebase.call('adminGetPremiumRequests', {
      if (statuses != null && statuses.isNotEmpty) 'statuses': statuses,
    });
    final rawList = result['users'] as List<dynamic>;
    return rawList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return AppUser.fromMap(map, map['uid'] as String);
    }).toList();
  }

  Future<void> adminSetPremiumSubscription({
    required String targetUid,
    required String action,
    String? reason,
  }) async {
    await Firebase.call('adminSetPremiumSubscription', {
      'targetUid': targetUid,
      'action': action,
      if (reason != null) 'reason': reason,
    });
  }

  Future<List<PremiumAlertPin>> getMyPremiumPins() async {
    final result = await Firebase.call('getMyPremiumPins');
    final rawList = result['pins'] as List<dynamic>;
    return rawList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return PremiumAlertPin.fromMap(map, map['id'] as String);
    }).toList();
  }

  Future<void> upsertPremiumPin({
    String? pinId,
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? label,
  }) async {
    await Firebase.call('upsertPremiumPin', {
      if (pinId != null) 'pinId': pinId,
      'latitude': latitude,
      'longitude': longitude,
      'radiusKm': radiusKm,
      'label': label,
    });
  }

  Future<void> deletePremiumPin(String pinId) async {
    await Firebase.call('deletePremiumPin', {'pinId': pinId});
  }

  Future<void> sellerSendBroadcast({
    required String title,
    required String body,
  }) async {
    await Firebase.call('sellerSendBroadcast', {
      'title': title,
      'body': body,
    });
  }

  Future<void> providerSendBroadcastNearby({
    required String title,
    required String body,
  }) async {
    await Firebase.call('providerSendBroadcastNearby', {
      'title': title,
      'body': body,
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class LandListing {
  final String id;
  final String sellerId;
  final String? plotNumber;
  final String landType;
  final double size;
  final double price;
  final String area;
  final String description;
  final List<String> photoUrls;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime createdAt;

  LandListing({
    required this.id,
    required this.sellerId,
    this.plotNumber,
    required this.landType,
    required this.size,
    required this.price,
    required this.area,
    required this.description,
    required this.photoUrls,
    required this.latitude,
    required this.longitude,
    this.status = 'active',
    required this.createdAt,
  });

  factory LandListing.fromMap(Map<String, dynamic> map, String id) {
    return LandListing(
      id: id,
      sellerId: map['sellerId'] ?? '',
      plotNumber: map['plotNumber'],
      landType: map['landType'] ?? '',
      size: (map['size'] as num).toDouble(),
      price: (map['price'] as num).toDouble(),
      area: map['area'] ?? '',
      description: map['description'] ?? '',
      photoUrls: List<String>.from(map['photoUrls'] ?? []),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'sellerId': sellerId,
        'plotNumber': plotNumber,
        'landType': landType,
        'size': size,
        'price': price,
        'area': area,
        'description': description,
        'photoUrls': photoUrls,
        'latitude': latitude,
        'longitude': longitude,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  String get formattedPrice {
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}k JD';
    }
    return '${price.toStringAsFixed(0)} JD';
  }
}

class AppUser {
  final String uid;
  final String name;
  final String phone;
  final String email;
  final String role;
  final String? fcmToken;
  final double? lastLat;
  final double? lastLng;
  final bool isBlocked;
  final String subscriptionPlan;
  final String subscriptionStatus;
  final DateTime? subscriptionRequestedAt;
  final DateTime? subscriptionApprovedAt;
  final String? subscriptionApprovedBy;
  final String? subscriptionRejectReason;
  final String? subscriptionDisableReason;

  AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    this.fcmToken,
    this.lastLat,
    this.lastLng,
    this.isBlocked = false,
    this.subscriptionPlan = 'free',
    this.subscriptionStatus = 'none',
    this.subscriptionRequestedAt,
    this.subscriptionApprovedAt,
    this.subscriptionApprovedBy,
    this.subscriptionRejectReason,
    this.subscriptionDisableReason,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'buyer',
      fcmToken: map['fcmToken'],
      lastLat: map['lastLat'] != null
          ? (map['lastLat'] as num).toDouble()
          : null,
      lastLng: map['lastLng'] != null
          ? (map['lastLng'] as num).toDouble()
          : null,
      isBlocked: map['isBlocked'] ?? false,
      subscriptionPlan: map['subscriptionPlan'] ?? 'free',
      subscriptionStatus: map['subscriptionStatus'] ?? 'none',
      subscriptionRequestedAt: map['subscriptionRequestedAt'] is Timestamp
          ? (map['subscriptionRequestedAt'] as Timestamp).toDate()
          : null,
      subscriptionApprovedAt: map['subscriptionApprovedAt'] is Timestamp
          ? (map['subscriptionApprovedAt'] as Timestamp).toDate()
          : null,
      subscriptionApprovedBy: map['subscriptionApprovedBy'],
      subscriptionRejectReason: map['subscriptionRejectReason'],
      subscriptionDisableReason: map['subscriptionDisableReason'],
    );
  }

  bool get isPremiumActive =>
      subscriptionPlan == 'premium' && subscriptionStatus == 'active';

  bool get isPremiumPending => subscriptionStatus == 'pending';
}

class ServiceProvider {
  final String id;
  final String userId;
  final String type;
  final String bio;
  final String services;
  final String contactInfo;
  final double latitude;
  final double longitude;
  final List<String> galleryUrls;
  final bool isHidden;

  ServiceProvider({
    required this.id,
    required this.userId,
    required this.type,
    required this.bio,
    required this.services,
    required this.contactInfo,
    required this.latitude,
    required this.longitude,
    this.galleryUrls = const [],
    this.isHidden = false,
  });
}

class ContactRequest {
  final String id;
  final String buyerId;
  final String sellerId;
  final String listingId;
  final String status;
  final DateTime createdAt;

  ContactRequest({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.listingId,
    required this.status,
    required this.createdAt,
  });

  factory ContactRequest.fromMap(Map<String, dynamic> map, String id) {
    return ContactRequest(
      id: id,
      buyerId: map['buyerId'] ?? '',
      sellerId: map['sellerId'] ?? '',
      listingId: map['listingId'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class PremiumAlertPin {
  final String id;
  final double latitude;
  final double longitude;
  final double radiusKm;
  final String? label;
  final DateTime createdAt;

  PremiumAlertPin({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    this.label,
    required this.createdAt,
  });

  factory PremiumAlertPin.fromMap(Map<String, dynamic> map, String id) {
    return PremiumAlertPin(
      id: id,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radiusKm: (map['radiusKm'] as num).toDouble(),
      label: map['label'] as String?,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

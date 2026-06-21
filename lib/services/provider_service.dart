import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'firebase.dart';

import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';


class ProviderService {
  ProviderService._();
  static final ProviderService instance = ProviderService._();

  /// Fetch nearby providers sorted by distance from a given coordinate.
  /// Uses the [getNearbyProviders] Cloud Function.
  Future<List<ServiceProvider>> getNearbyProviders({
    required double lat,
    required double lng,
    String? type, // 'Engineer' | 'Construction Company' | null (all)
    double radiusKm = 50,
  }) async {
    final result = await Firebase.call('getNearbyProviders', {
      'lat': lat,
      'lng': lng,
      if (type != null) 'type': type,
      'radiusKm': radiusKm,
    });

    final rawList = result['providers'] as List<dynamic>;
    return rawList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return ServiceProvider(
        id: map['id'] as String,
        userId: map['userId'] as String,
        type: map['type'] as String,
        bio: map['bio'] as String? ?? '',
        services: map['services'] as String? ?? '',
        contactInfo: map['contactInfo'] as String? ?? '',
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        galleryUrls: List<String>.from(map['galleryUrls'] as List? ?? []),
        isHidden: map['isHidden'] as bool? ?? false,
      );
    }).toList();
  }

  /// Get a single provider profile by userId.
  Future<ServiceProvider?> getProvider(String userId) async {
    final doc = await Firebase.firestore
        .collection('providers')
        .doc(userId)
        .get();
    if (!doc.exists) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    return ServiceProvider(
      id: doc.id,
      userId: data['userId'] as String,
      type: data['type'] as String,
      bio: data['bio'] as String? ?? '',
      services: data['services'] as String? ?? '',
      contactInfo: data['contactInfo'] as String? ?? '',
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      galleryUrls: List<String>.from(data['galleryUrls'] as List? ?? []),
      isHidden: data['isHidden'] as bool? ?? false,
    );
  }

  /// Create or update a provider profile document.
  Future<void> saveProfile(ServiceProvider provider) async {
    final ref = Firebase.firestore
        .collection('providers')
        .doc(provider.userId);

    final doc = await ref.get();
    final now = FieldValue.serverTimestamp();

    if (doc.exists) {
      await ref.update({
        'type': provider.type,
        'bio': provider.bio,
        'services': provider.services,
        'contactInfo': provider.contactInfo,
        'latitude': provider.latitude,
        'longitude': provider.longitude,
        'galleryUrls': provider.galleryUrls,
        'updatedAt': now,
      });
    } else {
      await ref.set({
        'userId': provider.userId,
        'type': provider.type,
        'bio': provider.bio,
        'services': provider.services,
        'contactInfo': provider.contactInfo,
        'latitude': provider.latitude,
        'longitude': provider.longitude,
        'galleryUrls': provider.galleryUrls,
        'isHidden': false,
        'createdAt': now,
        'updatedAt': now,
      });
    }
  }

  /// Upload a gallery photo and return its download URL.
  /// Upload a gallery photo using bytes (works on all platforms including web).
  Future<String> uploadGalleryPhoto({
    required String providerId,
    required Uint8List imageBytes,
  }) async {
    final ref = Firebase.storage
        .ref('providers/$providerId/gallery/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(
      imageBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  /// Remove a gallery photo URL from Firestore and delete from Storage.
  Future<void> removeGalleryPhoto({
    required String providerId,
    required String photoUrl,
  }) async {
    // Remove from Firestore array
    await Firebase.firestore.collection('providers').doc(providerId).update({
      'galleryUrls': FieldValue.arrayRemove([photoUrl]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Delete from Storage
    try {
      await Firebase.storage.refFromURL(photoUrl).delete();
    } catch (_) {}
  }
}

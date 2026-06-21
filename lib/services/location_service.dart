import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase.dart';

/// Manages device location permissions and periodic GPS updates.
///
/// Per Android location best practices [6]:
/// - Never silently use location; always explain why before requesting.
/// - Support the "deny" case gracefully — location features are optional.
/// - Use "while using" permission for foreground GPS; avoid always-on unless justified.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Timer? _updateTimer;
  StreamSubscription<Position>? _positionStream;

  /// Check current permission status without triggering a dialog.
  Future<LocationPermissionStatus> checkPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionStatus.serviceDisabled;

    final permission = await Geolocator.checkPermission();
    return _mapPermission(permission);
  }

  /// Request location permission from the user.
  /// Returns the resulting status.
  Future<LocationPermissionStatus> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionStatus.serviceDisabled;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionStatus.deniedForever;
    }

    return _mapPermission(permission);
  }

  /// Get the device's current position once.
  /// Returns null if permission is denied or an error occurs.
  Future<Position?> getCurrentPosition() async {
    final status = await checkPermission();
    debugPrint('[Location Servicces] status1:  $status');
    //if (status != LocationPermissionStatus.granted) return null;
    if (status != LocationPermissionStatus.granted) {
      await requestPermission();
      final status = await checkPermission();
      debugPrint('[Location Servicces] status2:  $status');
      if (status != LocationPermissionStatus.granted) return null;
    }

    try {
      debugPrint('[Location Servicces] inside');
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      debugPrint('[Location Servicces] Error');
      return null;
    }
  }

  /// Start sending the buyer's GPS location to the backend periodically.
  /// Updates every [intervalMinutes] minutes while the app is in the foreground.
  /// This populates [lastLat/lastLng] in the user's Firestore doc, which is
  /// used by [onListingCreated] to find nearby buyers.
  void startPeriodicLocationUpdates({int intervalMinutes = 10}) {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => _uploadCurrentLocation(),
    );
    // Also send immediately on start
    _uploadCurrentLocation();
  }

  /// Stop periodic location updates (e.g. when user logs out or is not a buyer).
  void stopPeriodicLocationUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
    _positionStream?.cancel();
    _positionStream = null;
  }

  Future<void> _uploadCurrentLocation() async {
    final position = await getCurrentPosition();
    if (position == null) return;

    try {
      await Firebase.call('updateBuyerLocation', {
        'lat': position.latitude,
        'lng': position.longitude,
      });
    } catch (_) {
      // Silently fail — location update is best-effort
    }
  }

  LocationPermissionStatus _mapPermission(LocationPermission p) {
    return switch (p) {
      LocationPermission.always ||
      LocationPermission.whileInUse =>
        LocationPermissionStatus.granted,
      LocationPermission.deniedForever =>
        LocationPermissionStatus.deniedForever,
      _ => LocationPermissionStatus.denied,
    };
  }

  void dispose() {
    stopPeriodicLocationUpdates();
  }
}

enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

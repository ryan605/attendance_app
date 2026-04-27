// ============================================================
// STEP 3 — GPS GEOFENCING SERVICE
// Uses geolocator for high-accuracy positioning and checks
// whether the student is within the classroom geofence.
// Google Maps is used in the UI (attendance_screen.dart).
//
// Required packages:
//   geolocator: ^12.0.0
//   permission_handler: ^11.0.0
//   google_maps_flutter: ^2.6.0
// ============================================================

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/class_model.dart';

// ── Result types ─────────────────────────────────────────────

enum LocationStatus {
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  ok,
}

class GeofenceResult {
  final bool isInside;
  final double distanceMetres;
  final double? studentLat;
  final double? studentLng;
  final LocationStatus status;
  final String? errorMessage;

  const GeofenceResult._({
    required this.isInside,
    required this.distanceMetres,
    required this.status,
    this.studentLat,
    this.studentLng,
    this.errorMessage,
  });

  factory GeofenceResult.ok({
    required bool isInside,
    required double distance,
    required double lat,
    required double lng,
  }) =>
      GeofenceResult._(
        isInside: isInside,
        distanceMetres: distance,
        status: LocationStatus.ok,
        studentLat: lat,
        studentLng: lng,
      );

  factory GeofenceResult.error(LocationStatus status, String message) =>
      GeofenceResult._(
        isInside: false,
        distanceMetres: -1,
        status: status,
        errorMessage: message,
      );

  bool get hasError => status != LocationStatus.ok;
}

// ── Service ──────────────────────────────────────────────────

class LocationService {
  // ── Permission helpers ──────────────────────────────────────

  /// Checks and requests location permissions.
  /// Returns a [LocationStatus] indicating the outcome.
  Future<LocationStatus> ensurePermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationStatus.serviceDisabled;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationStatus.permissionDenied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationStatus.permissionPermanentlyDenied;
    }

    return LocationStatus.ok;
  }

  // ── Single position fix ─────────────────────────────────────

  /// Returns the current position once, with the highest available accuracy.
  Future<Position?> getCurrentPosition() async {
    final status = await ensurePermissions();
    if (status != LocationStatus.ok) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );
  }

  // ── Geofence check ──────────────────────────────────────────

  /// Checks whether the student is within the [classData] geofence.
  ///
  /// If [knownLat] and [knownLng] are provided (e.g. from the live map stream),
  /// they are used directly to avoid an extra GPS round-trip that can return
  /// a stale or divergent position.
  Future<GeofenceResult> checkGeofence(
    ClassModel classData, {
    double? knownLat,
    double? knownLng,
  }) async {
    // Use the already-obtained live position when available.
    if (knownLat != null && knownLng != null) {
      final distance = Geolocator.distanceBetween(
        knownLat,
        knownLng,
        classData.latitude,
        classData.longitude,
      );
      return GeofenceResult.ok(
        isInside: distance <= classData.geofenceRadius,
        distance: distance,
        lat: knownLat,
        lng: knownLng,
      );
    }

    final status = await ensurePermissions();

    if (status == LocationStatus.serviceDisabled) {
      return GeofenceResult.error(
        status,
        'Location services are turned off. Please enable GPS.',
      );
    }
    if (status == LocationStatus.permissionDenied) {
      return GeofenceResult.error(
        status,
        'Location permission denied. Please allow location access.',
      );
    }
    if (status == LocationStatus.permissionPermanentlyDenied) {
      return GeofenceResult.error(
        status,
        'Location permission permanently denied. Open Settings to allow.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        classData.latitude,
        classData.longitude,
      );

      return GeofenceResult.ok(
        isInside: distance <= classData.geofenceRadius,
        distance: distance,
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (e) {
      return GeofenceResult.error(
        LocationStatus.ok,
        'Could not get location: $e',
      );
    }
  }

  // ── Live position stream ────────────────────────────────────

  /// Emits continuous position updates for the map.
  /// [distanceFilter] = only emit after moving this many metres (saves battery).
  Stream<Position> livePositionStream({double distanceFilter = 5}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter.toInt(),
      ),
    );
  }

  // ── Convenience: compute distance ──────────────────────────

  double distanceBetween({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) =>
      Geolocator.distanceBetween(fromLat, fromLng, toLat, toLng);

  // ── Human-readable distance ─────────────────────────────────

  String formatDistance(double metres) {
    if (metres < 0) return 'unknown';
    if (metres < 1000) return '${metres.toStringAsFixed(0)}m';
    return '${(metres / 1000).toStringAsFixed(1)}km';
  }
}

// ============================================================
// ATTENDANCE SERVICE
// Orchestrates the full attendance marking flow:
//   1. Check device matches stored ID (anti-proxy)
//   2. Verify GPS is within classroom geofence
//   3. Verify the class session is currently active (time window)
//   4. Write the attendance log to Firebase Realtime Database
//   5. Check whether the student already signed for this class
// ============================================================

import 'package:firebase_database/firebase_database.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import 'device_link_service.dart';
import 'location_service.dart';

enum AttendanceError {
  alreadySigned,
  deviceMismatch,
  outsideGeofence,
  classNotActive,
  locationUnavailable,
  firebaseError,
}

class AttendanceResult {
  final bool success;
  final AttendanceError? error;
  final String message;
  final double? distanceFromClass;

  const AttendanceResult._({
    required this.success,
    required this.message,
    this.error,
    this.distanceFromClass,
  });

  factory AttendanceResult.ok(double distance) => AttendanceResult._(
    success: true,
    message: 'Attendance marked successfully.',
    distanceFromClass: distance,
  );

  factory AttendanceResult.fail(AttendanceError error, String message) =>
      AttendanceResult._(success: false, error: error, message: message);
}

class AttendanceService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final LocationService _locationService = LocationService();
  final DeviceLinkService _deviceService = DeviceLinkService();

  // ── Fetch active classes for a student's course ─────────────

  /// Returns all classes that are currently marked isActive = true
  /// and belong to the student's courseCode.
  /// Returns active classes for [courseCode] that target [admissionYear]
  /// or have no year restriction (yearGroup == '').
  Future<List<ClassModel>> getActiveClasses(String courseCode, String admissionYear) async {
    final snapshot = await _db
        .child('classes')
        .orderByChild('courseCode')
        .equalTo(courseCode)
        .get();

    if (!snapshot.exists) return [];

    final map = snapshot.value as Map;
    return map.entries
        .map((e) => ClassModel.fromMap(e.key as String, e.value as Map))
        .where((c) =>
            c.isActive &&
            (c.yearGroup.isEmpty || c.yearGroup == admissionYear))
        .toList();
  }

  // ── Check if student already signed attendance ──────────────

  Future<bool> hasAlreadySigned(String classId, String studentUid) async {
    final snapshot = await _db
        .child('attendance_logs')
        .child(classId)
        .child(studentUid)
        .get();
    return snapshot.exists;
  }

  // ── Full attendance marking flow ────────────────────────────

  Future<AttendanceResult> markAttendance({
    required StudentModel student,
    required ClassModel classData,
    double? knownLat,
    double? knownLng,
  }) async {
    // ── Guard 1: Already signed? ──────────────────────────────
    final alreadySigned = await hasAlreadySigned(classData.classId, student.uid);
    if (alreadySigned) {
      return AttendanceResult.fail(
        AttendanceError.alreadySigned,
        'You have already signed attendance for this class.',
      );
    }

    // ── Guard 2: Class still active? ─────────────────────────
    if (!classData.isActive) {
      return AttendanceResult.fail(
        AttendanceError.classNotActive,
        'The attendance window for this class is not open.',
      );
    }

    // ── Guard 3: Device matches stored ID? ───────────────────
    final deviceResult = await _deviceService.checkAndLinkDevice(student);
    if (deviceResult == DeviceCheckResult.mismatch) {
      return AttendanceResult.fail(
        AttendanceError.deviceMismatch,
        'This account is linked to a different device. '
            'Contact your admin to reset your device binding.',
      );
    }
    if (deviceResult == DeviceCheckResult.unavailable) {
      return AttendanceResult.fail(
        AttendanceError.deviceMismatch,
        'Unable to verify your device. Ensure permissions are granted.',
      );
    }

    // ── Guard 4: Inside geofence? ─────────────────────────────
    final geo = await _locationService.checkGeofence(
      classData,
      knownLat: knownLat,
      knownLng: knownLng,
    );
    if (geo.hasError) {
      return AttendanceResult.fail(
        AttendanceError.locationUnavailable,
        geo.errorMessage ?? 'Location check failed.',
      );
    }
    if (!geo.isInside) {
      return AttendanceResult.fail(
        AttendanceError.outsideGeofence,
        'You are ${_locationService.formatDistance(geo.distanceMetres)} from '
            '${classData.venue}. You must be within '
            '${classData.geofenceRadius.toInt()}m to sign attendance.',
      );
    }

    // ── All checks passed — write to Firebase ─────────────────
    try {
      final currentDeviceId = await _deviceService.getCurrentDeviceId();
      final log = AttendanceLog(
        studentId: student.uid,
        classId: classData.classId,
        regNumber: student.regNumber,
        name: student.name,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        gpsLat: geo.studentLat!,
        gpsLng: geo.studentLng!,
        distanceFromClass: geo.distanceMetres,
        deviceVerified: true,
        status: 'present',
      );

      // Path: attendance_logs/{classId}/{studentUid}
      // Using student UID as key prevents duplicate entries naturally.
      await _db
          .child('attendance_logs')
          .child(classData.classId)
          .child(student.uid)
          .set(log.toMap());

      return AttendanceResult.ok(geo.distanceMetres);
    } catch (e) {
      return AttendanceResult.fail(
        AttendanceError.firebaseError,
        'Failed to save attendance. Please try again.\n$e',
      );
    }
  }
}

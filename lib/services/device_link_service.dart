// ============================================================
// STEP 2 — DEVICE LINKING SERVICE
// Captures the device's unique identifier on first login,
// stores it in Firebase, and verifies it on every subsequent login.
//
// Android  → Wi-Fi MAC address via network_info_plus
// iOS      → identifierForVendor (Apple randomises MAC since iOS 14)
//
// Required packages:
//   network_info_plus: ^5.0.0
//   device_info_plus: ^9.0.0
// ============================================================

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/student_model.dart';

enum DeviceCheckResult {
  /// First login — device ID has been saved to Firebase. Access granted.
  linked,

  /// Returning login — device ID matches the stored one. Access granted.
  verified,

  /// Device ID does not match the stored one. Access denied.
  mismatch,

  /// Could not read the device ID (permissions missing, emulator, etc.).
  unavailable,
}

class DeviceLinkService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ── Get current device ID ───────────────────────────────────

  /// Returns the best available device identifier for this platform.
  /// On Android: Wi-Fi MAC address.
  /// On iOS: identifierForVendor (stable per app install).
  Future<String?> getCurrentDeviceId() async {
    try {
      if (Platform.isAndroid) {
        // Wi-Fi MAC address — works while Wi-Fi is on; null otherwise
        final info = NetworkInfo();
        final mac = await info.getWifiBSSID(); // returns the MAC of connected AP — use device MAC instead

        // Use AndroidDeviceInfo as the primary ID — more reliable than MAC
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        // androidId is stable across reboots and factory resets are the only way to change it
        return androidInfo.id; // hardware serial + build fingerprint hash
      } else if (Platform.isIOS) {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor; // stable until app is uninstalled
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Check / link device on login ───────────────────────────

  /// Call this immediately after successful Firebase Auth sign-in.
  ///
  /// - If the student has no deviceId stored → saves current device ID → returns [linked].
  /// - If stored deviceId matches current → returns [verified].
  /// - If stored deviceId doesn't match → returns [mismatch] (block login).
  /// - If device ID can't be read → returns [unavailable].
  Future<DeviceCheckResult> checkAndLinkDevice(StudentModel student) async {
    final currentId = await getCurrentDeviceId();

    if (currentId == null || currentId.isEmpty) {
      return DeviceCheckResult.unavailable;
    }

    // First-time: no device linked yet
    if (student.deviceId == null || student.deviceId!.isEmpty) {
      await _saveDeviceId(student.uid, currentId);
      return DeviceCheckResult.linked;
    }

    // Returning: verify match
    if (student.deviceId == currentId) {
      return DeviceCheckResult.verified;
    }

    return DeviceCheckResult.mismatch;
  }

  // ── Save device ID to Firebase ──────────────────────────────

  Future<void> _saveDeviceId(String uid, String deviceId) async {
    await _db.child('students').child(uid).update({
      'deviceId': deviceId,
      'deviceLinkedAt': DateTime.now().millisecondsSinceEpoch,
      'deviceResetAllowed': false,
    });
  }

  // ── Admin: reset device binding ─────────────────────────────

  /// Called by an admin when a student gets a new phone.
  /// Sets deviceId to null so the next login will link the new device.
  Future<void> resetDeviceBinding(String studentUid) async {
    await _db.child('students').child(studentUid).update({
      'deviceId': null,
      'deviceLinkedAt': null,
      'deviceResetAllowed': false,
    });
  }

  // ── User-friendly message for each result ──────────────────

  String messageFor(DeviceCheckResult result) {
    switch (result) {
      case DeviceCheckResult.linked:
        return 'Device linked to your account successfully.';
      case DeviceCheckResult.verified:
        return 'Device verified.';
      case DeviceCheckResult.mismatch:
        return 'This account is linked to a different device.\n'
            'If you changed phones, contact your administrator to reset your device binding.';
      case DeviceCheckResult.unavailable:
        return 'Unable to read device identifier.\n'
            'Please ensure the app has the required permissions.';
    }
  }

  bool get isAccessGranted => true; // convenience — see checkAndLinkDevice callers
}

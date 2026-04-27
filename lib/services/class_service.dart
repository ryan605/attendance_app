import 'package:firebase_database/firebase_database.dart';
import '../models/class_model.dart';

class ClassService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Stream<List<ClassModel>> watchLecturerClasses(String lecturerId) {
    return _db
        .child('classes')
        .orderByChild('lecturerId')
        .equalTo(lecturerId)
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <ClassModel>[];
      final map = event.snapshot.value as Map;
      return map.entries
          .map((e) => ClassModel.fromMap(e.key as String, e.value as Map))
          .toList()
        ..sort((a, b) => a.unitName.compareTo(b.unitName));
    });
  }

  Stream<int> watchAttendanceCount(String classId) {
    return _db
        .child('attendance_logs')
        .child(classId)
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return 0;
      return (event.snapshot.value as Map).length;
    });
  }

  Future<void> startClass(String classId, {int durationMinutes = 120}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.child('classes').child(classId).update({
      'isActive': true,
      'scheduledStart': now,
      'scheduledEnd': now + durationMinutes * 60 * 1000,
    });
  }

  Future<void> endClass(String classId) async {
    await _db.child('classes').child(classId).update({
      'isActive': false,
      'scheduledEnd': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> createClass({
    required String lecturerId,
    required String courseCode,
    required String unitCode,
    required String unitName,
    required String venue,
    required double latitude,
    required double longitude,
    required double geofenceRadius,
    required String yearGroup,
  }) async {
    final classId =
        '${unitCode.toUpperCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
    await _db.child('classes').child(classId).set({
      'lecturerId': lecturerId,
      'courseCode': courseCode.toUpperCase(),
      'unitCode': unitCode.toUpperCase(),
      'unitName': unitName,
      'venue': venue,
      'latitude': latitude,
      'longitude': longitude,
      'geofenceRadius': geofenceRadius,
      'yearGroup': yearGroup,
      'isActive': false,
      'scheduledStart': 0,
      'scheduledEnd': 0,
    });
  }
}

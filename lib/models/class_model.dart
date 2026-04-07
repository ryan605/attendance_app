class ClassModel {
  final String classId;
  final String unitCode;
  final String unitName;
  final String courseCode;
  /// Admission year this class targets, e.g. "2021". Empty string means all years.
  final String yearGroup;
  final String lecturerId;
  final String venue;
  final double latitude;
  final double longitude;
  final double geofenceRadius;
  final int scheduledStart;
  final int scheduledEnd;
  final bool isActive;

  ClassModel({
    required this.classId,
    required this.unitCode,
    required this.unitName,
    required this.courseCode,
    required this.yearGroup,
    required this.lecturerId,
    required this.venue,
    required this.latitude,
    required this.longitude,
    required this.geofenceRadius,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.isActive,
  });

  factory ClassModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return ClassModel(
      classId: id,
      unitCode: map['unitCode'] ?? '',
      unitName: map['unitName'] ?? '',
      courseCode: map['courseCode'] ?? '',
      yearGroup: map['yearGroup'] ?? '',
      lecturerId: map['lecturerId'] ?? '',
      venue: map['venue'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      geofenceRadius: (map['geofenceRadius'] ?? 50).toDouble(),
      scheduledStart: map['scheduledStart'] ?? 0,
      scheduledEnd: map['scheduledEnd'] ?? 0,
      isActive: map['isActive'] ?? false,
    );
  }
}

class AttendanceLog {
  final String studentId;
  final String classId;
  final String regNumber;
  final String name;
  final int timestamp;
  final double gpsLat;
  final double gpsLng;
  final double distanceFromClass;
  final bool deviceVerified;
  final String status;

  AttendanceLog({
    required this.studentId,
    required this.classId,
    required this.regNumber,
    required this.name,
    required this.timestamp,
    required this.gpsLat,
    required this.gpsLng,
    required this.distanceFromClass,
    required this.deviceVerified,
    this.status = 'present',
  });

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'classId': classId,
    'regNumber': regNumber,
    'name': name,
    'timestamp': timestamp,
    'gpsLat': gpsLat,
    'gpsLng': gpsLng,
    'distanceFromClass': distanceFromClass,
    'deviceVerified': deviceVerified,
    'status': status,
  };
}

class AttendanceReport {
  final String classId;
  final String unitName;
  final String date;
  final int generatedAt;
  final int totalEnrolled;
  final int presentCount;
  final int absentCount;
  final double attendanceRate;
  final Map<String, String> presentStudents; // uid → regNumber
  final Map<String, String> absentStudents;

  AttendanceReport({
    required this.classId,
    required this.unitName,
    required this.date,
    required this.generatedAt,
    required this.totalEnrolled,
    required this.presentCount,
    required this.absentCount,
    required this.attendanceRate,
    required this.presentStudents,
    required this.absentStudents,
  });

  factory AttendanceReport.fromMap(Map<dynamic, dynamic> map) {
    Map<String, String> toStringMap(dynamic raw) {
      if (raw == null) return {};
      return Map<String, String>.from(
        (raw as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
      );
    }

    return AttendanceReport(
      classId: map['classId'] ?? '',
      unitName: map['unitName'] ?? '',
      date: map['date'] ?? '',
      generatedAt: map['generatedAt'] ?? 0,
      totalEnrolled: map['totalEnrolled'] ?? 0,
      presentCount: map['presentCount'] ?? 0,
      absentCount: map['absentCount'] ?? 0,
      attendanceRate: (map['attendanceRate'] ?? 0).toDouble(),
      presentStudents: toStringMap(map['presentStudents']),
      absentStudents: toStringMap(map['absentStudents']),
    );
  }
}

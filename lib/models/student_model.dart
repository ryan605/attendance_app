class StudentModel {
  final String uid;
  final String regNumber;
  final String name;
  final String courseCode;
  final String admissionSerial;
  final String admissionYear;
  final String? deviceId;
  final int? deviceLinkedAt;
  final bool deviceResetAllowed;
  final String role; // 'student' | 'lecturer' | 'admin'

  StudentModel({
    required this.uid,
    required this.regNumber,
    required this.name,
    required this.courseCode,
    required this.admissionSerial,
    required this.admissionYear,
    this.deviceId,
    this.deviceLinkedAt,
    this.deviceResetAllowed = false,
    this.role = 'student',
  });

  factory StudentModel.fromMap(String uid, Map<dynamic, dynamic> map) {
    return StudentModel(
      uid: uid,
      regNumber: map['regNumber'] ?? '',
      name: map['name'] ?? '',
      courseCode: map['courseCode'] ?? '',
      admissionSerial: map['admissionSerial'] ?? '',
      admissionYear: map['admissionYear'] ?? '',
      deviceId: map['deviceId'],
      deviceLinkedAt: map['deviceLinkedAt'],
      deviceResetAllowed: map['deviceResetAllowed'] ?? false,
      role: map['role'] ?? 'student',
    );
  }

  Map<String, dynamic> toMap() => {
    'regNumber': regNumber,
    'name': name,
    'courseCode': courseCode,
    'admissionSerial': admissionSerial,
    'admissionYear': admissionYear,
    'deviceId': deviceId,
    'deviceLinkedAt': deviceLinkedAt,
    'deviceResetAllowed': deviceResetAllowed,
    'role': role,
  };

  StudentModel copyWith({String? deviceId, int? deviceLinkedAt, bool? deviceResetAllowed}) {
    return StudentModel(
      uid: uid,
      regNumber: regNumber,
      name: name,
      courseCode: courseCode,
      admissionSerial: admissionSerial,
      admissionYear: admissionYear,
      deviceId: deviceId ?? this.deviceId,
      deviceLinkedAt: deviceLinkedAt ?? this.deviceLinkedAt,
      deviceResetAllowed: deviceResetAllowed ?? this.deviceResetAllowed,
      role: role,
    );
  }
}

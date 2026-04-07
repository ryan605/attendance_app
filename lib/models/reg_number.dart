/// Parses and validates university registration numbers.
/// Format: COURSE-SERIAL/YEAR  e.g. SCM211-0234/2021
class RegNumber {
  final String raw;
  final String courseCode;
  final String serial;
  final String year;

  RegNumber._({
    required this.raw,
    required this.courseCode,
    required this.serial,
    required this.year,
  });

  /// Returns null if the format is invalid.
  static RegNumber? parse(String input) {
    final cleaned = input.trim().toUpperCase();
    // Pattern: letters+digits, hyphen, digits, slash, 4-digit year
    final regex = RegExp(r'^([A-Z]+\d+)-(\d+)\/(\d{4})$');
    final match = regex.firstMatch(cleaned);
    if (match == null) return null;
    return RegNumber._(
      raw: cleaned,
      courseCode: match.group(1)!,
      serial: match.group(2)!,
      year: match.group(3)!,
    );
  }

  /// The Firebase Auth "email" used internally — never shown to users.
  /// e.g. SCM211-0234/2021 → scm211_0234_2021@attendance.app
  String get authEmail {
    final safe = raw.toLowerCase().replaceAll('-', '_').replaceAll('/', '_');
    return '$safe@attendance.app';
  }

  /// Display-friendly label.
  @override
  String toString() => raw;
}

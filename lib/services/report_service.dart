// ============================================================
// REPORT SERVICE
// Reads attendance reports from Firebase Realtime Database
// and generates a formatted PDF for download/sharing.
//
// Required packages:
//   pdf: ^3.10.0
//   path_provider: ^2.1.0
//   share_plus: ^7.0.0
// ============================================================

import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/class_model.dart';

class ReportService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ── Fetch all reports ───────────────────────────────────────

  Future<List<AttendanceReport>> fetchReports({String? classId}) async {
    try {
      final snapshot = await _db.child('reports').get();
      if (!snapshot.exists) return [];

      final map = snapshot.value as Map;
      final reports = map.entries
          .map((e) => AttendanceReport.fromMap(e.value as Map))
          .toList();

      if (classId != null) {
        return reports.where((r) => r.classId == classId).toList();
      }

      // Sort by date descending
      reports.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
      return reports;
    } catch (_) {
      return [];
    }
  }

  // ── Fetch single report ─────────────────────────────────────

  Future<AttendanceReport?> fetchReport(String reportId) async {
    try {
      final snapshot = await _db.child('reports').child(reportId).get();
      if (!snapshot.exists) return null;
      return AttendanceReport.fromMap(snapshot.value as Map);
    } catch (_) {
      return null;
    }
  }

  // ── Generate report from live attendance logs ────────────────
  // Called at end of class (can be triggered by lecturer from admin panel).

  Future<void> generateReport({
    required ClassModel classData,
    required List<String> enrolledStudentUids,
  }) async {
    // Read who signed attendance
    final snapshot = await _db
        .child('attendance_logs')
        .child(classData.classId)
        .get();

    final Map<String, String> present = {};
    if (snapshot.exists) {
      final map = snapshot.value as Map;
      map.forEach((uid, data) {
        final d = data as Map;
        present[uid.toString()] = d['regNumber']?.toString() ?? '';
      });
    }

    final absent = <String, String>{};
    for (final uid in enrolledStudentUids) {
      if (!present.containsKey(uid)) {
        // Fetch reg number for absent students
        final s = await _db.child('students').child(uid).get();
        if (s.exists) {
          final sd = s.value as Map;
          absent[uid] = sd['regNumber']?.toString() ?? '';
        }
      }
    }

    final now = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final reportId = '${classData.classId}_$date';
    final total = enrolledStudentUids.length;
    final presentCount = present.length;

    final report = {
      'classId': classData.classId,
      'unitName': classData.unitName,
      'date': date,
      'generatedAt': now.millisecondsSinceEpoch,
      'totalEnrolled': total,
      'presentCount': presentCount,
      'absentCount': total - presentCount,
      'attendanceRate': total > 0 ? (presentCount / total * 100) : 0.0,
      'presentStudents': present,
      'absentStudents': absent,
    };

    await _db.child('reports').child(reportId).set(report);
  }

  // ── Generate PDF ─────────────────────────────────────────────

  Future<File> generatePdf(AttendanceReport report) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ATTENDANCE REPORT',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    report.unitName,
                    style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Text(
                report.date,
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
              ),
            ],
          ),

          pw.Divider(color: PdfColors.blueGrey200, height: 28),

          // Summary boxes
          pw.Row(
            children: [
              _pdfStatBox('Total Enrolled', '${report.totalEnrolled}', PdfColors.blueGrey800),
              pw.SizedBox(width: 12),
              _pdfStatBox('Present', '${report.presentCount}', PdfColors.green700),
              pw.SizedBox(width: 12),
              _pdfStatBox('Absent', '${report.absentCount}', PdfColors.red700),
              pw.SizedBox(width: 12),
              _pdfStatBox(
                'Rate',
                '${report.attendanceRate.toStringAsFixed(1)}%',
                report.attendanceRate >= 75 ? PdfColors.green700 : PdfColors.orange700,
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          // Present students table
          pw.Text(
            'Present Students (${report.presentStudents.length})',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (report.presentStudents.isNotEmpty)
            pw.Table.fromTextArray(
              headers: ['#', 'Registration Number', 'Status'],
              data: report.presentStudents.entries
                  .toList()
                  .asMap()
                  .entries
                  .map((e) => [
                '${e.key + 1}',
                e.value.value,
                'Present',
              ])
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
              cellStyle: const pw.TextStyle(fontSize: 11),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
              },
            ),

          pw.SizedBox(height: 20),

          // Absent students table
          pw.Text(
            'Absent Students (${report.absentStudents.length})',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (report.absentStudents.isNotEmpty)
            pw.Table.fromTextArray(
              headers: ['#', 'Registration Number', 'Status'],
              data: report.absentStudents.entries
                  .toList()
                  .asMap()
                  .entries
                  .map((e) => [
                '${e.key + 1}',
                e.value.value,
                'Absent',
              ])
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.red700),
              cellStyle: const pw.TextStyle(fontSize: 11),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.red50),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
              },
            ),

          // Footer
          pw.SizedBox(height: 32),
          pw.Divider(color: PdfColors.blueGrey200),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated by Attendance App · ${DateTime.now()}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/report_${report.classId}_${report.date}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _pdfStatBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 10, color: PdfColors.white),
            ),
          ],
        ),
      ),
    );
  }
}

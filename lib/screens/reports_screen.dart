// ============================================================
// STEP 5 — REPORTS SCREEN
// Lists all attendance reports from Firebase.
// Each report can be expanded to see present/absent students.
// A "Export PDF" button generates and shares the report PDF.
// ============================================================

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/class_model.dart';
import '../services/report_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _reportService = ReportService();

  late Future<List<AttendanceReport>> _reportsFuture;
  String? _exportingId;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _reportService.fetchReports();
  }

  Future<void> _exportPdf(AttendanceReport report) async {
    setState(() => _exportingId = report.classId + report.date);
    try {
      final file = await _reportService.generatePdf(report);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Attendance Report – ${report.unitName} (${report.date})',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        title: const Text(
          'Attendance Reports',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              _reportsFuture = _reportService.fetchReports();
            }),
          ),
        ],
      ),
      body: FutureBuilder<List<AttendanceReport>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading reports: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart, color: Color(0xFF2A3A4A), size: 64),
                  SizedBox(height: 16),
                  Text(
                    'No reports yet',
                    style: TextStyle(color: Color(0xFF8899AA), fontSize: 16),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Reports are generated after each class session',
                    style: TextStyle(color: Color(0xFF445566), fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ReportCard(
              report: reports[i],
              isExporting: _exportingId == reports[i].classId + reports[i].date,
              onExport: () => _exportPdf(reports[i]),
            ),
          );
        },
      ),
    );
  }
}

// ── Report card (expandable) ──────────────────────────────

class _ReportCard extends StatefulWidget {
  final AttendanceReport report;
  final bool isExporting;
  final VoidCallback onExport;

  const _ReportCard({
    required this.report,
    required this.isExporting,
    required this.onExport,
  });

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _expanded = false;

  Color get _rateColor {
    final r = widget.report.attendanceRate;
    if (r >= 75) return const Color(0xFF00C896);
    if (r >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _expanded
              ? const Color(0xFF00B4D8).withOpacity(0.4)
              : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Rate circle
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: r.attendanceRate / 100,
                          backgroundColor: const Color(0xFF0D1B2A),
                          valueColor: AlwaysStoppedAnimation(_rateColor),
                          strokeWidth: 4,
                        ),
                        Center(
                          child: Text(
                            '${r.attendanceRate.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: _rateColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title / date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.unitName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r.date,
                          style: const TextStyle(
                            color: Color(0xFF8899AA),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _miniChip('${r.presentCount} present', const Color(0xFF00C896)),
                            const SizedBox(width: 6),
                            _miniChip('${r.absentCount} absent', Colors.red),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Expand icon
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF8899AA),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded detail ──────────────────────────────
          if (_expanded) ...[
            const Divider(color: Color(0xFF2A3A4A), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Present
                  if (r.presentStudents.isNotEmpty) ...[
                    _sectionLabel('Present Students', const Color(0xFF00C896)),
                    const SizedBox(height: 6),
                    ...r.presentStudents.values
                        .toList()
                        .asMap()
                        .entries
                        .map((e) => _StudentRow(
                      index: e.key + 1,
                      regNumber: e.value,
                      isPresent: true,
                    )),
                    const SizedBox(height: 12),
                  ],

                  // Absent
                  if (r.absentStudents.isNotEmpty) ...[
                    _sectionLabel('Absent Students', Colors.red),
                    const SizedBox(height: 6),
                    ...r.absentStudents.values
                        .toList()
                        .asMap()
                        .entries
                        .map((e) => _StudentRow(
                      index: e.key + 1,
                      regNumber: e.value,
                      isPresent: false,
                    )),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),

            // Export PDF button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.isExporting ? null : widget.onExport,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00B4D8),
                    side: const BorderSide(color: Color(0xFF00B4D8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: widget.isExporting
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(widget.isExporting ? 'Generating PDF…' : 'Export as PDF'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final int index;
  final String regNumber;
  final bool isPresent;

  const _StudentRow({
    required this.index,
    required this.regNumber,
    required this.isPresent,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPresent ? const Color(0xFF00C896) : Colors.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$index.',
              style: const TextStyle(color: Color(0xFF445566), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              regNumber,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Icon(
            isPresent ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 16,
          ),
        ],
      ),
    );
  }
}

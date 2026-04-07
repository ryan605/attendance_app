// ============================================================
// HOME SCREEN
// Shows the student's active classes and navigation to Reports.
// ============================================================

import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import 'attendance_screen.dart';
import 'reports_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final StudentModel student;
  const HomeScreen({super.key, required this.student});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _attendanceService = AttendanceService();
  final _authService = AuthService();

  late Future<List<ClassModel>> _classesFuture;

  @override
  void initState() {
    super.initState();
    _classesFuture = _attendanceService.getActiveClasses(
      widget.student.courseCode,
      widget.student.admissionYear,
    );
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${widget.student.name.split(' ').first}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.student.regNumber,
              style: const TextStyle(color: Color(0xFF8899AA), fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            tooltip: 'Reports',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF8899AA)),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF00B4D8),
        backgroundColor: const Color(0xFF1A2A3A),
        onRefresh: () async {
          setState(() {
            _classesFuture = _attendanceService.getActiveClasses(
      widget.student.courseCode,
      widget.student.admissionYear,
    );
          });
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Course banner ──────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.school, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.student.courseCode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Year joined: ${widget.student.admissionYear}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Active classes section ─────────────────
                    const Text(
                      'Active Classes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Classes currently open for attendance',
                      style: TextStyle(color: Color(0xFF8899AA), fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Class list ───────────────────────────────────
            FutureBuilder<List<ClassModel>>(
              future: _classesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Error loading classes:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ),
                  );
                }

                final classes = snapshot.data ?? [];
                if (classes.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_available, color: Color(0xFF2A3A4A), size: 56),
                          SizedBox(height: 14),
                          Text(
                            'No active classes right now',
                            style: TextStyle(color: Color(0xFF8899AA), fontSize: 16),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Pull down to refresh',
                            style: TextStyle(color: Color(0xFF445566), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ClassCard(
                          classData: classes[i],
                          student: widget.student,
                          attendanceService: _attendanceService,
                        ),
                      ),
                      childCount: classes.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Class card ────────────────────────────────────────────

class _ClassCard extends StatefulWidget {
  final ClassModel classData;
  final StudentModel student;
  final AttendanceService attendanceService;

  const _ClassCard({
    required this.classData,
    required this.student,
    required this.attendanceService,
  });

  @override
  State<_ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<_ClassCard> {
  bool _alreadySigned = false;

  @override
  void initState() {
    super.initState();
    _checkSigned();
  }

  Future<void> _checkSigned() async {
    final signed = await widget.attendanceService.hasAlreadySigned(
      widget.classData.classId,
      widget.student.uid,
    );
    if (mounted) setState(() => _alreadySigned = signed);
  }

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.classData;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _alreadySigned
              ? const Color(0xFF00C896).withOpacity(0.3)
              : const Color(0xFF2A3A4A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unit name + code
          Row(
            children: [
              Expanded(
                child: Text(
                  c.unitName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_alreadySigned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C896).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Signed',
                    style: TextStyle(color: Color(0xFF00C896), fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Venue + time
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF8899AA)),
              const SizedBox(width: 4),
              Text(c.venue, style: const TextStyle(color: Color(0xFF8899AA), fontSize: 13)),
              const SizedBox(width: 12),
              const Icon(Icons.access_time, size: 14, color: Color(0xFF8899AA)),
              const SizedBox(width: 4),
              Text(
                '${_formatTime(c.scheduledStart)} – ${_formatTime(c.scheduledEnd)}',
                style: const TextStyle(color: Color(0xFF8899AA), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _alreadySigned
                  ? null
                  : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AttendanceScreen(
                    student: widget.student,
                    activeClass: c,
                  ),
                ),
              ).then((_) => _checkSigned()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _alreadySigned
                    ? const Color(0xFF1E2E3E)
                    : const Color(0xFF00B4D8),
                foregroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF445566),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(
                _alreadySigned ? 'Attendance already marked' : 'Sign Attendance',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

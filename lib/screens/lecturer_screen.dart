import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../services/auth_service.dart';
import '../services/class_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';
import 'reports_screen.dart';

class LecturerScreen extends StatelessWidget {
  final StudentModel lecturer;
  const LecturerScreen({super.key, required this.lecturer});

  @override
  Widget build(BuildContext context) {
    final classService = ClassService();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lecturer Dashboard',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            Text(
              lecturer.name,
              style: const TextStyle(color: Color(0xFF8899AA), fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            tooltip: 'Reports',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReportsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF8899AA)),
            tooltip: 'Sign out',
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ClassModel>>(
        stream: classService.watchLecturerClasses(lecturer.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading classes:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            );
          }
          final classes = snapshot.data ?? [];
          if (classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.class_outlined,
                      color: Color(0xFF2A3A4A), size: 64),
                  const SizedBox(height: 16),
                  const Text('No classes yet',
                      style:
                          TextStyle(color: Color(0xFF8899AA), fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Tap + to create your first class',
                      style:
                          TextStyle(color: Color(0xFF445566), fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: classes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _ClassCard(
              classData: classes[i],
              classService: classService,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00B4D8),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Class'),
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _CreateClassSheet(
            lecturer: lecturer,
            classService: classService,
          ),
        ),
      ),
    );
  }
}

// ── Class Card ─────────────────────────────────────────────

class _ClassCard extends StatefulWidget {
  final ClassModel classData;
  final ClassService classService;

  const _ClassCard({required this.classData, required this.classService});

  @override
  State<_ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<_ClassCard> {
  bool _isLoading = false;

  Future<void> _start(int durationMinutes) async {
    setState(() => _isLoading = true);
    try {
      await widget.classService
          .startClass(widget.classData.classId, durationMinutes: durationMinutes);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _end() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A3A),
        title: const Text('End Class?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'This closes attendance for ${widget.classData.unitName}.',
          style: const TextStyle(color: Color(0xFF8899AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF8899AA))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Class',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      await widget.classService.endClass(widget.classData.classId);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDurationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2A3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DurationPickerSheet(
        unitName: widget.classData.unitName,
        onSelected: (minutes) {
          Navigator.pop(context);
          _start(minutes);
        },
      ),
    );
  }

  String _fmt(int ms) {
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
          color: c.isActive
              ? const Color(0xFF00C896).withOpacity(0.4)
              : const Color(0xFF2A3A4A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unit name + status badge
          Row(
            children: [
              Expanded(
                child: Text(c.unitName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (c.isActive
                          ? const Color(0xFF00C896)
                          : const Color(0xFF445566))
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  c.isActive ? 'LIVE' : 'INACTIVE',
                  style: TextStyle(
                    color: c.isActive
                        ? const Color(0xFF00C896)
                        : const Color(0xFF8899AA),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Meta info
          Wrap(
            spacing: 12,
            children: [
              _meta(Icons.tag, c.unitCode),
              _meta(Icons.location_on_outlined, c.venue),
              _meta(Icons.people_outline,
                  c.yearGroup.isEmpty ? 'All years' : 'Year ${c.yearGroup}'),
            ],
          ),

          // Live stats (active only)
          if (c.isActive) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.how_to_reg_outlined,
                    size: 14, color: Color(0xFF00C896)),
                const SizedBox(width: 4),
                StreamBuilder<int>(
                  stream: widget.classService
                      .watchAttendanceCount(c.classId),
                  builder: (_, snap) => Text(
                    '${snap.data ?? 0} signed',
                    style: const TextStyle(
                        color: Color(0xFF00C896),
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.access_time,
                    size: 14, color: Color(0xFF8899AA)),
                const SizedBox(width: 4),
                Text('${_fmt(c.scheduledStart)} – ${_fmt(c.scheduledEnd)}',
                    style: const TextStyle(
                        color: Color(0xFF8899AA), fontSize: 12)),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // Action button
          SizedBox(
            width: double.infinity,
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF00B4D8)),
                    ),
                  )
                : c.isActive
                    ? OutlinedButton.icon(
                        onPressed: _end,
                        icon: const Icon(Icons.stop_circle_outlined,
                            size: 18, color: Colors.redAccent),
                        label: const Text('End Class',
                            style: TextStyle(color: Colors.redAccent)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Colors.redAccent, width: 1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _showDurationPicker,
                        icon: const Icon(Icons.play_circle_outline,
                            size: 18),
                        label: const Text('Start Class'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C896),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF8899AA)),
        const SizedBox(width: 3),
        Text(text,
            style:
                const TextStyle(color: Color(0xFF8899AA), fontSize: 12)),
      ],
    );
  }
}

// ── Duration Picker ────────────────────────────────────────

class _DurationPickerSheet extends StatelessWidget {
  final String unitName;
  final void Function(int minutes) onSelected;

  const _DurationPickerSheet(
      {required this.unitName, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const options = [
      [30, '30 minutes'],
      [60, '1 hour'],
      [90, '1.5 hours'],
      [120, '2 hours'],
      [180, '3 hours'],
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How long is this class?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(unitName,
              style:
                  const TextStyle(color: Color(0xFF8899AA), fontSize: 13)),
          const SizedBox(height: 16),
          ...options.map(
            (opt) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_outlined,
                  color: Color(0xFF00B4D8)),
              title: Text(opt[1] as String,
                  style: const TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right,
                  color: Color(0xFF445566)),
              onTap: () => onSelected(opt[0] as int),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create Class Sheet ─────────────────────────────────────

class _CreateClassSheet extends StatefulWidget {
  final StudentModel lecturer;
  final ClassService classService;

  const _CreateClassSheet(
      {required this.lecturer, required this.classService});

  @override
  State<_CreateClassSheet> createState() => _CreateClassSheetState();
}

class _CreateClassSheetState extends State<_CreateClassSheet> {
  final _formKey = GlobalKey<FormState>();
  final _unitNameCtrl = TextEditingController();
  final _unitCodeCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _courseCodeCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController(text: '50');

  String _yearGroup = '';
  double? _lat;
  double? _lng;
  bool _locating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _courseCodeCtrl.text = widget.lecturer.courseCode;
  }

  @override
  void dispose() {
    _unitNameCtrl.dispose();
    _unitCodeCtrl.dispose();
    _venueCtrl.dispose();
    _courseCodeCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() => _locating = true);
    try {
      final service = LocationService();
      final status = await service.ensurePermissions();
      if (status != LocationStatus.ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Location permission denied')));
        }
        return;
      }
      final pos = await service.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please set the classroom location first')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.classService.createClass(
        lecturerId: widget.lecturer.uid,
        courseCode: _courseCodeCtrl.text.trim(),
        unitCode: _unitCodeCtrl.text.trim(),
        unitName: _unitNameCtrl.text.trim(),
        venue: _venueCtrl.text.trim(),
        latitude: _lat!,
        longitude: _lng!,
        geofenceRadius: double.tryParse(_radiusCtrl.text) ?? 50,
        yearGroup: _yearGroup,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create class: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1A2A3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3A4A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Create New Class',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),

              _field(
                controller: _unitNameCtrl,
                label: 'Unit Name',
                hint: 'e.g. Data Structures & Algorithms',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _unitCodeCtrl,
                      label: 'Unit Code',
                      hint: 'e.g. DSA301',
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _courseCodeCtrl,
                      label: 'Course Code',
                      hint: 'e.g. SCM211',
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _field(
                controller: _venueCtrl,
                label: 'Venue',
                hint: 'e.g. Room 201, Block A',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _yearGroup,
                      dropdownColor: const Color(0xFF0D1B2A),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      decoration: _decoration('Year Group'),
                      items: [
                        const DropdownMenuItem(
                            value: '', child: Text('All Years')),
                        ...['2021', '2022', '2023', '2024'].map((y) =>
                            DropdownMenuItem(value: y, child: Text(y))),
                      ],
                      onChanged: (v) =>
                          setState(() => _yearGroup = v ?? ''),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _radiusCtrl,
                      label: 'Geofence (m)',
                      hint: '50',
                      keyboard: TextInputType.number,
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n < 10) return 'Min 10m';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Location picker
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _lat != null
                        ? const Color(0xFF00C896).withOpacity(0.4)
                        : const Color(0xFF2A3A4A),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _lat != null
                              ? Icons.location_on
                              : Icons.location_off_outlined,
                          color: _lat != null
                              ? const Color(0xFF00C896)
                              : const Color(0xFF8899AA),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _lat != null
                              ? '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                              : 'No classroom location set',
                          style: TextStyle(
                            color: _lat != null
                                ? const Color(0xFF00C896)
                                : const Color(0xFF8899AA),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _locating ? null : _fetchLocation,
                        icon: _locating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00B4D8)),
                              )
                            : const Icon(Icons.my_location,
                                size: 16, color: Color(0xFF00B4D8)),
                        label: Text(
                          _locating
                              ? 'Locating…'
                              : _lat != null
                                  ? 'Update Location'
                                  : 'Use My Current Location',
                          style: const TextStyle(
                              color: Color(0xFF00B4D8), fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF00B4D8)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B4D8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Create Class',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: _decoration(label).copyWith(hintText: hint),
      validator: validator,
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          const TextStyle(color: Color(0xFF8899AA), fontSize: 13),
      hintStyle:
          const TextStyle(color: Color(0xFF445566), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF0D1B2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2A3A4A)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2A3A4A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFF00B4D8), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      errorStyle:
          TextStyle(color: Colors.red.shade300, fontSize: 12),
    );
  }
}

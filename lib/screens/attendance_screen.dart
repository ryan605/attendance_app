// ============================================================
// STEP 4 — ATTENDANCE SCREEN
// Shows a live Google Map with the classroom geofence circle.
// The "Mark Attendance" button only activates when:
//   • The student is inside the geofence
//   • The class session is active
//   • The device matches the stored ID
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../services/attendance_service.dart';
import '../services/location_service.dart';

class AttendanceScreen extends StatefulWidget {
  final StudentModel student;
  final ClassModel activeClass;

  const AttendanceScreen({
    super.key,
    required this.student,
    required this.activeClass,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _locationService = LocationService();
  final _attendanceService = AttendanceService();

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSub;

  LatLng? _studentLatLng;
  double _distanceMetres = double.infinity;
  bool _isInsideGeofence = false;
  bool _attendanceMarked = false;
  bool _isSubmitting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Location tracking ─────────────────────────────────────

  void _startTracking() {
    _positionSub = _locationService.livePositionStream().listen((pos) {
      final dist = _locationService.distanceBetween(
        fromLat: pos.latitude,
        fromLng: pos.longitude,
        toLat: widget.activeClass.latitude,
        toLng: widget.activeClass.longitude,
      );
      setState(() {
        _studentLatLng = LatLng(pos.latitude, pos.longitude);
        _distanceMetres = dist;
        _isInsideGeofence = dist <= widget.activeClass.geofenceRadius;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_studentLatLng!),
      );
    }, onError: (_) {
      setState(() => _statusMessage = 'Location update failed. Check GPS settings.');
    });
  }

  // ── Mark attendance ───────────────────────────────────────

  Future<void> _markAttendance() async {
    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    final result = await _attendanceService.markAttendance(
      student: widget.student,
      classData: widget.activeClass,
    );

    setState(() {
      _isSubmitting = false;
      _statusMessage = result.message;
      if (result.success) _attendanceMarked = true;
    });

    if (result.success) {
      _showSuccessSheet();
    } else {
      _showErrorSnack(result.message);
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessSheet(
        unitName: widget.activeClass.unitName,
        studentName: widget.student.name,
        distance: _distanceMetres,
      ),
    );
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Map geometry ──────────────────────────────────────────

  Set<Circle> get _circles => {
    Circle(
      circleId: const CircleId('geofence'),
      center: LatLng(widget.activeClass.latitude, widget.activeClass.longitude),
      radius: widget.activeClass.geofenceRadius,
      fillColor: (_isInsideGeofence ? Colors.green : Colors.red).withOpacity(0.12),
      strokeColor: _isInsideGeofence ? const Color(0xFF00C896) : Colors.red,
      strokeWidth: 2,
    ),
  };

  Set<Marker> get _markers {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('classroom'),
        position: LatLng(widget.activeClass.latitude, widget.activeClass.longitude),
        infoWindow: InfoWindow(
          title: widget.activeClass.venue,
          snippet: widget.activeClass.unitName,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    };
    if (_studentLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('student'),
        position: _studentLatLng!,
        infoWindow: InfoWindow(title: widget.student.name),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _isInsideGeofence ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
        ),
      ));
    }
    return markers;
  }

  // ── Build ─────────────────────────────────────────────────

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
              widget.activeClass.unitName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.activeClass.venue,
              style: const TextStyle(color: Color(0xFF8899AA), fontSize: 12),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Live map ───────────────────────────────────────
          SizedBox(
            height: 300,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      widget.activeClass.latitude,
                      widget.activeClass.longitude,
                    ),
                    zoom: 18.5,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  circles: _circles,
                  markers: _markers,
                  myLocationEnabled: false,
                  zoomControlsEnabled: false,
                  mapType: MapType.normal,
                ),
                // Map overlay: distance chip
                Positioned(
                  top: 12,
                  right: 12,
                  child: _DistanceChip(
                    distance: _distanceMetres,
                    isInside: _isInsideGeofence,
                    radius: widget.activeClass.geofenceRadius,
                    locationService: _locationService,
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom panel ──────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status row
                  _StatusRow(
                    isInside: _isInsideGeofence,
                    distance: _distanceMetres,
                    radius: widget.activeClass.geofenceRadius,
                    locationService: _locationService,
                  ),
                  const SizedBox(height: 24),

                  // Class info card
                  _ClassInfoCard(classData: widget.activeClass),
                  const Spacer(),

                  // Mark attendance button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _attendanceMarked
                          ? _MarkedButton(key: const ValueKey('marked'))
                          : ElevatedButton(
                        key: const ValueKey('active'),
                        onPressed:
                        (_isInsideGeofence && !_isSubmitting) ? _markAttendance : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isInsideGeofence
                              ? const Color(0xFF00C896)
                              : const Color(0xFF2A3A4A),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF1E2E3E),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isInsideGeofence
                                  ? Icons.check_circle_outline
                                  : Icons.location_off_outlined,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isInsideGeofence
                                  ? 'Mark My Attendance'
                                  : 'Move Into Classroom',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'GPS-verified · Device-locked · One-time per session',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────

class _DistanceChip extends StatelessWidget {
  final double distance;
  final bool isInside;
  final double radius;
  final LocationService locationService;

  const _DistanceChip({
    required this.distance,
    required this.isInside,
    required this.radius,
    required this.locationService,
  });

  @override
  Widget build(BuildContext context) {
    final color = isInside ? const Color(0xFF00C896) : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            distance.isInfinite
                ? 'Locating…'
                : locationService.formatDistance(distance),
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final bool isInside;
  final double distance;
  final double radius;
  final LocationService locationService;

  const _StatusRow({
    required this.isInside,
    required this.distance,
    required this.radius,
    required this.locationService,
  });

  @override
  Widget build(BuildContext context) {
    final color = isInside ? const Color(0xFF00C896) : Colors.red;
    final label = isInside
        ? '✓  Inside classroom'
        : '✕  Outside classroom — move within ${radius.toInt()}m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!distance.isInfinite)
            Text(
              locationService.formatDistance(distance),
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class _ClassInfoCard extends StatelessWidget {
  final ClassModel classData;
  const _ClassInfoCard({required this.classData});

  @override
  Widget build(BuildContext context) {
    final start = DateTime.fromMillisecondsSinceEpoch(classData.scheduledStart);
    final end = DateTime.fromMillisecondsSinceEpoch(classData.scheduledEnd);
    String fmt(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A3A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(Icons.class_outlined, classData.unitCode, classData.unitName),
          const SizedBox(height: 10),
          _row(Icons.location_on_outlined, 'Venue', classData.venue),
          const SizedBox(height: 10),
          _row(Icons.access_time, 'Time', '${fmt(start)} – ${fmt(end)}'),
          const SizedBox(height: 10),
          _row(Icons.gps_fixed, 'Geofence', '${classData.geofenceRadius.toInt()}m radius'),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8899AA)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Color(0xFF8899AA), fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MarkedButton extends StatelessWidget {
  const _MarkedButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00C896).withOpacity(0.5)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Color(0xFF00C896), size: 22),
          SizedBox(width: 10),
          Text(
            'Attendance Recorded',
            style: TextStyle(
              color: Color(0xFF00C896),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Success bottom sheet ────────────────────────────────────

class _SuccessSheet extends StatelessWidget {
  final String unitName;
  final String studentName;
  final double distance;

  const _SuccessSheet({
    required this.unitName,
    required this.studentName,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        color: Color(0xFF0D2A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF00C896), width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF00C896), size: 56),
          const SizedBox(height: 16),
          const Text(
            'Attendance Recorded!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$unitName · ${distance.toStringAsFixed(0)}m from classroom',
            style: const TextStyle(color: Color(0xFF8899AA), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

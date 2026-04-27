import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:attendance_app/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home_screen.dart';
import 'screens/lecturer_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B4D8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const _AuthGate(),
    );
  }
}

/// Listens to Firebase Auth state and routes to the correct screen.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ── Loading ────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D1B2A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
            ),
          );
        }

        // ── Not signed in ──────────────────────────────────
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // ── Signed in — fetch student profile ──────────────
        return FutureBuilder(
          future: _authService.fetchStudentProfile(snapshot.data!.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF0D1B2A),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
                ),
              );
            }

            if (profileSnapshot.data == null) {
              // Profile missing — sign out and back to login
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            final profile = profileSnapshot.data!;
            if (profile.role == 'lecturer' || profile.role == 'admin') {
              return LecturerScreen(lecturer: profile);
            }
            return HomeScreen(student: profile);
          },
        );
      },
    );
  }
}


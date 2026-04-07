// ============================================================
// STEP 1 — AUTH SERVICE
// Handles registration-number-based sign-in and sign-up.
// Internally maps reg numbers to a synthetic email for Firebase Auth.
// ============================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/reg_number.dart';
import '../models/student_model.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;
  final StudentModel? student;

  const AuthResult.ok(this.student)
      : success = true,
        errorMessage = null;

  const AuthResult.fail(this.errorMessage)
      : success = false,
        student = null;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ── Current signed-in user ──────────────────────────────────

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Sign In ─────────────────────────────────────────────────

  /// Sign in with registration number + password.
  /// Returns AuthResult.ok with the student profile, or AuthResult.fail with a message.
  Future<AuthResult> signIn(String rawRegNumber, String password) async {
    // 1. Parse the registration number
    final regNum = RegNumber.parse(rawRegNumber);
    if (regNum == null) {
      return const AuthResult.fail(
        'Invalid registration number format.\nExpected: SCM211-0234/2021',
      );
    }

    // 2. Attempt Firebase Auth sign-in
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: regNum.authEmail,
        password: password,
      );

      // 3. Fetch student profile from Realtime Database
      final snapshot = await _db
          .child('students')
          .child(credential.user!.uid)
          .get();

      if (!snapshot.exists) {
        await _auth.signOut();
        return const AuthResult.fail('Student profile not found. Contact admin.');
      }

      final student = StudentModel.fromMap(
        credential.user!.uid,
        snapshot.value as Map,
      );

      return AuthResult.ok(student);
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(_friendlyAuthError(e.code));
    } catch (e) {
      return AuthResult.fail('Unexpected error: $e');
    }
  }

  // ── Sign Up (first-time registration) ──────────────────────

  /// Create a new student account.
  /// The [name] field is what shows in the app — reg number is the login key.
  Future<AuthResult> signUp({
    required String rawRegNumber,
    required String password,
    required String name,
  }) async {
    final regNum = RegNumber.parse(rawRegNumber);
    if (regNum == null) {
      return const AuthResult.fail(
        'Invalid registration number format.\nExpected: SCM211-0234/2021',
      );
    }

    if (password.length < 8) {
      return const AuthResult.fail('Password must be at least 8 characters.');
    }

    try {
      // 1. Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: regNum.authEmail,
        password: password,
      );

      final uid = credential.user!.uid;

      // 2. Write student profile to Realtime Database (no deviceId yet — set on first login)
      final student = StudentModel(
        uid: uid,
        regNumber: regNum.raw,
        name: name,
        courseCode: regNum.courseCode,
        admissionSerial: regNum.serial,
        admissionYear: regNum.year,
        deviceId: null, // linked on first device login — see DeviceService
        role: 'student',
      );

      await _db.child('students').child(uid).set(student.toMap());

      return AuthResult.ok(student);
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(_friendlyAuthError(e.code));
    } catch (e) {
      return AuthResult.fail('Unexpected error: $e');
    }
  }

  // ── Fetch student profile ───────────────────────────────────

  Future<StudentModel?> fetchStudentProfile(String uid) async {
    try {
      final snapshot = await _db.child('students').child(uid).get();
      if (!snapshot.exists) return null;
      return StudentModel.fromMap(uid, snapshot.value as Map);
    } catch (_) {
      return null;
    }
  }

  // ── Sign Out ────────────────────────────────────────────────

  Future<void> signOut() => _auth.signOut();

  // ── Helpers ─────────────────────────────────────────────────

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found for this registration number.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists for this registration number.';
      case 'too-many-requests':
        return 'Too many failed attempts. Try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'Authentication error ($code). Please try again.';
    }
  }
}

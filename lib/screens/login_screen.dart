// ============================================================
// LOGIN SCREEN
// Registration number + password sign-in.
// Also has a "Create account" path for first-time students.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/device_link_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _regController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(); // sign-up only

  final _authService = AuthService();
  final _deviceService = DeviceLinkService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isSignUp = false;
  String? _errorMessage;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _regController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      AuthResult result;

      if (_isSignUp) {
        result = await _authService.signUp(
          rawRegNumber: _regController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
        );
      } else {
        result = await _authService.signIn(
          _regController.text.trim(),
          _passwordController.text,
        );
      }

      if (!result.success || result.student == null) {
        setState(() => _errorMessage = result.errorMessage);
        return;
      }

      // ── Device check ────────────────────────────────────────
      final deviceResult = await _deviceService.checkAndLinkDevice(result.student!);

      if (deviceResult == DeviceCheckResult.mismatch) {
        await _authService.signOut();
        setState(() => _errorMessage = _deviceService.messageFor(deviceResult));
        return;
      }

      if (deviceResult == DeviceCheckResult.unavailable) {
        // Non-blocking warning — allow login but warn
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device ID unavailable — proxy check skipped.')),
          );
        }
      }

      // ── Navigate ─────────────────────────────────────────────
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(student: result.student!),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Logo / Header ───────────────────────────
                  const SizedBox(height: 20),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B4D8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isSignUp ? 'Create account' : 'Welcome back',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSignUp
                        ? 'Register with your student number'
                        : 'Sign in with your registration number',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF8899AA)),
                  ),
                  const SizedBox(height: 36),

                  // ── Form ────────────────────────────────────
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Name (sign-up only)
                        if (_isSignUp) ...[
                          _buildField(
                            controller: _nameController,
                            label: 'Full name',
                            hint: 'e.g. Jane Mwangi',
                            icon: Icons.person_outline,
                            validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Registration number
                        _buildField(
                          controller: _regController,
                          label: 'Registration number',
                          hint: 'e.g. SCM211-0234/2021',
                          icon: Icons.badge_outlined,
                          textCapitalization: TextCapitalization.characters,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter your registration number';
                            if (!RegExp(r'^[A-Za-z]+\d+-\d+/\d{4}$').hasMatch(v.trim())) {
                              return 'Format: COURSE-SERIAL/YEAR (e.g. SCM211-0234/2021)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password
                        _buildField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: const Color(0xFF8899AA),
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Enter your password';
                            if (_isSignUp && v.length < 8) return 'At least 8 characters required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Error message
                        if (_errorMessage != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade900.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade700, width: 1),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            ),
                          ),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00B4D8),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                                : Text(
                              _isSignUp ? 'Create account' : 'Sign in',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Toggle sign-in / sign-up
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                              style: const TextStyle(color: Color(0xFF8899AA), fontSize: 14),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _isSignUp = !_isSignUp;
                                _errorMessage = null;
                                _formKey.currentState?.reset();
                              }),
                              child: Text(
                                _isSignUp ? 'Sign in' : 'Register',
                                style: const TextStyle(
                                  color: Color(0xFF00B4D8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Reusable field widget ──────────────────────────────────

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF445566), fontSize: 14),
        labelStyle: const TextStyle(color: Color(0xFF8899AA), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF8899AA), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF1A2A3A),
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
          borderSide: const BorderSide(color: Color(0xFF00B4D8), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        errorStyle: TextStyle(color: Colors.red.shade300, fontSize: 12),
      ),
      validator: validator,
    );
  }
}

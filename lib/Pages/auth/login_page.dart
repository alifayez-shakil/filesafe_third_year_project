import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtr = TextEditingController();
  final _passCtr = TextEditingController();

  bool _showPass = false;
  bool _loading = false;
  bool _unverified = false;
  String? _error;

  @override
  void dispose() {
    _emailCtr.dispose();
    _passCtr.dispose();
    super.dispose();
  }

  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
      _unverified = false;
    });

    try {
      final err = await AuthService.login(
        email: _emailCtr.text.trim(),
        password: _passCtr.text,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (err == null) {
        context.go('/home');
      } else if (err == 'unverified') {
        setState(() {
          _unverified = true;
          _error =
              'Vault verification required. Please verify your email link inside your inbox.';
        });
      } else {
        // Friendly Supabase messages
        String msg = err;
        if (err.contains('rate limit')) {
          msg = 'Too many attempts. Please wait.';
        } else if (err.contains('Invalid login') || err.contains('invalid')) {
          msg = 'Invalid email or password.';
        }
        setState(() => _error = msg);
      }
    } on AuthException catch (e) {
      // Supabase-specific exception
      String msg = e.message.toLowerCase();
      if (msg.contains('rate limit')) {
        msg = 'Too many attempts. Please wait.';
      } else if (msg.contains('invalid login')) {
        msg = 'Invalid email or password.';
      } else {
        msg = e.message;
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _error = msg;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Cannot connect to server. Please check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Shared Input Styling Blueprint with High-End Micro-borders
    InputDecoration vaultInputDecoration({
      required String label,
      required IconData prefixIcon,
      Widget? suffixIcon,
    }) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(
          prefixIcon,
          size: 20,
          color: Colors.amber.withOpacity(0.6),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.black.withOpacity(0.25),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.amber, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115), // Deep Midnight Slate Canvas
      body: Stack(
        children: [
          // ── Ambient Background Glow Layer 1 ─────────────────────────────────
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withOpacity(0.06),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.1),
                    blurRadius: 120,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          // ── Ambient Background Glow Layer 2 ─────────────────────────────────
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E2638).withOpacity(0.4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E2638).withOpacity(0.3),
                    blurRadius: 90,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Main Content Area ───────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Brand Identity Logo Block ──────────────────────────────────
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.05),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/FileSafe_logo.png',
                          width: 300,
                          height: 300,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 300,
                                width: 300,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF161A22),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.gpp_good_rounded,
                                  size: 48,
                                  color: Colors.white54,
                                ),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'FileSafe',
                      style: TextStyle(
                        fontSize: 45,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A secure vault for your sensitive files. Please login to access your account.',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Frosted Glassmorphism Panel Container ───────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 28,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.07),
                              width: 1.2,
                            ),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // ── Dynamic Feedback Notification Alert Banner ───────────────
                                if (_error != null) ...[
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color:
                                          (_unverified
                                                  ? Colors.amber
                                                  : Colors.redAccent)
                                              .withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color:
                                            (_unverified
                                                    ? Colors.amber
                                                    : Colors.redAccent)
                                                .withOpacity(0.25),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          _unverified
                                              ? Icons.verified_user_outlined
                                              : Icons
                                                    .lock_reset_rounded, // ← fixed
                                          color: _unverified
                                              ? Colors.amber
                                              : Colors.redAccent,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: TextStyle(
                                              color: Colors.grey.shade200,
                                              fontSize: 12.5,
                                              height: 1.4,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                // ── Email Node Input ─────────────────────────────────────
                                TextFormField(
                                  controller: _emailCtr,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  decoration: vaultInputDecoration(
                                    label: 'User Email',
                                    prefixIcon: Icons.person,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty)
                                      return 'Please input your User Email';
                                    if (!_emailRegex.hasMatch(v.trim()))
                                      return 'Invalid User Email format';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // ── Password Node Input ──────────────────────────────────
                                TextFormField(
                                  controller: _passCtr,
                                  obscureText: !_showPass,
                                  textInputAction: TextInputAction.done,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  decoration: vaultInputDecoration(
                                    label: 'Enter your password',
                                    prefixIcon: Icons.vpn_key_outlined,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _showPass
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 18,
                                        color: Colors.grey.shade500,
                                      ),
                                      onPressed: () => setState(
                                        () => _showPass = !_showPass,
                                      ),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'password required'
                                      : null,
                                  onFieldSubmitted: (_) =>
                                      _loading ? null : _submit(),
                                ),
                                const SizedBox(height: 28),

                                // ── Action Trigger Button ────────────────────────────────
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        if (!_loading)
                                          BoxShadow(
                                            color: Colors.amber.withOpacity(
                                              0.15,
                                            ),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber,
                                        foregroundColor: const Color(
                                          0xFF0F1115,
                                        ),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      onPressed: _loading ? null : _submit,
                                      child: _loading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Color(0xFF0F1115),
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.lock_open_rounded,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'LOGIN',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Secondary Navigation Route Action ─────────────────────────────
                    TextButton(
                      onPressed: () => context.go('/register'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                          children: const [
                            TextSpan(text: "New account? "),
                            TextSpan(
                              text: "Create a new account",
                              style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

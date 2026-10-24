import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class _C {
  static const bgDark = Color(0xFF1F2A1A);
  static const waveDark = Color(0xFF2C3A23);
  static const waveDarkSoft = Color(0xFF374530);
  static const almond = Color(0xFFF6EFE2);
  static const almondSoft = Color(0xFFB9C4A6);
  static const almondMuted = Color(0xFF8E9A7C);
  static const rust = Color(0xFFC1703E);
  static const ink = Color(0xFF2B2820);
  static const glassFill = Color(0x14FFFFFF);
  static const glassBorder = Color(0x2EFFFFFF);
  static const fieldFill = Color(0x1EFFFFFF);
  static const fieldBorder = Color(0x33FFFFFF);
}


class _FieldWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Path()
      ..moveTo(0, size.height * 0.18)
      ..cubicTo(
        size.width * 0.28, size.height * 0.36,
        size.width * 0.58, size.height * -0.02,
        size.width * 0.82, size.height * 0.16,
      )
      ..cubicTo(
        size.width * 0.94, size.height * 0.23,
        size.width, size.height * 0.18,
        size.width, size.height * 0.12,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(p1, Paint()..color = _C.waveDark);

    final p2 = Path()
      ..moveTo(0, size.height * 0.30)
      ..cubicTo(
        size.width * 0.32, size.height * 0.45,
        size.width * 0.64, size.height * 0.16,
        size.width, size.height * 0.28,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(p2, Paint()..color = _C.waveDarkSoft.withOpacity(0.7));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _C.glassFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.glassBorder, width: 0.8),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.fieldFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.fieldBorder, width: 0.8),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: _C.almond, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _C.almondMuted.withOpacity(0.8), fontSize: 13.5),
          prefixIcon: icon == null
              ? null
              : Icon(icon, size: 18, color: _C.almondSoft),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _authErrorMessage(e));
    } catch (e) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'Invalid email.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return e.message ?? 'Could not log in. Try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgDark,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 260,
            child: CustomPaint(painter: _FieldWavesPainter()),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _C.rust,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.eco_outlined, color: _C.almond),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AgroLens',
                              style: TextStyle(
                                  color: _C.almond,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                          Text('The vet in your pocket',
                              style: TextStyle(color: _C.almondMuted, fontSize: 11.5)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Text('Welcome back',
                      style: TextStyle(
                          color: _C.almond,
                          fontSize: 24,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  // Text('Log in to check on your herd, crops and pals.',
                  //     style: TextStyle(color: _C.almondSoft, fontSize: 13)),
                  const SizedBox(height: 24),
                  _GlassCard(
                    child: Column(
                      children: [
                        _AuthField(
                          controller: _emailCtrl,
                          hint: 'Email address',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        _AuthField(
                          controller: _passCtrl,
                          hint: 'Password',
                          icon: Icons.lock_outline,
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 18,
                              color: _C.almondSoft,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                            ),
                            child: Text('Forgot password?',
                                style: TextStyle(color: _C.almondSoft, fontSize: 12.5)),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 4),
                          Text(_error!,
                              style: const TextStyle(color: Color(0xFFE2A07A), fontSize: 12)),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _C.rust,
                              foregroundColor: _C.ink,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: _C.ink),
                                  )
                                : const Text('Log in',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: Divider(color: _C.fieldBorder, height: 0.8)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('or continue with',
                            style: TextStyle(color: _C.almondMuted, fontSize: 11)),
                      ),
                      Expanded(child: Divider(color: _C.fieldBorder, height: 0.8)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _SocialButton(icon: Icons.g_mobiledata, label: 'Google', onTap: () {})),
                      const SizedBox(width: 10),
                      Expanded(child: _SocialButton(icon: Icons.phone_outlined, label: 'Phone', onTap: () {})),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: _C.almondSoft, fontSize: 12.5),
                          children: [
                            const TextSpan(text: "Don't have an account? "),
                            TextSpan(
                              text: 'Sign up',
                              style: const TextStyle(color: _C.almond, fontWeight: FontWeight.w600),
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
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _C.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.fieldBorder, width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: _C.almond),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: _C.almond, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
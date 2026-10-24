import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class _C {
  static const bgDark = Color(0xFF1F2A1A);
  static const waveDark = Color(0xFF2C3A23);
  static const waveDarkSoft = Color(0xFF374530);
  static const almond = Color(0xFFF6EFE2);
  static const almondSoft = Color(0xFFB9C4A6);
  static const almondMuted = Color(0xFF8E9A7C);
  static const rust = Color(0xFFC1703E);
  static const ink = Color(0xFF2B2820);
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

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _sent = true);
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
      case 'invalid-email':
        return 'Invalid email address.';
      default:
        return e.message ?? 'Could not send the reset link. Try again.';
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
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _C.fieldFill,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, size: 16, color: _C.almond),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _C.rust.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.mark_email_unread_outlined,
                        color: _C.rust, size: 26),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _sent ? 'Check your inbox' : 'Forgot your password?',
                    style: const TextStyle(
                        color: _C.almond, fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _sent
                        ? "We've sent a reset link to ${_emailCtrl.text.trim()}. Follow it to set a new password."
                        : "Enter the email you signed up with and we'll send you a link to reset it.",
                    style: TextStyle(color: _C.almondSoft, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  if (!_sent) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: _C.fieldFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _C.fieldBorder, width: 0.8),
                      ),
                      child: TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: _C.almond, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Email address',
                          hintStyle: TextStyle(color: _C.almondMuted.withOpacity(0.8), fontSize: 13.5),
                          prefixIcon: const Icon(Icons.mail_outline, size: 18, color: _C.almondSoft),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Color(0xFFE2A07A), fontSize: 12)),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _sendResetLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.rust,
                          foregroundColor: _C.ink,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: _C.ink),
                              )
                            : const Text('Send reset link', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _C.almond,
                          side: BorderSide(color: _C.fieldBorder, width: 0.8),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Back to log in'),
                      ),
                    ),
                  const SizedBox(height: 22),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: _C.almondSoft, fontSize: 12.5),
                          children: [
                            const TextSpan(text: 'Remembered the password? '),
                            TextSpan(
                              text: 'Log in',
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
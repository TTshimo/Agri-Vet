import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'shell_screen.dart';

/// AgroLens palette — matcha green / almond / white, dark auth variant.
class _C {
  static const bgDark = Color(0xFF1F2A1A);
  static const waveDark = Color(0xFF2C3A23);
  static const waveDarkSoft = Color(0xFF374530);
  static const matcha = Color(0xFF5C7148);
  static const matchaLight = Color(0xFFD6E0C4);
  static const almond = Color(0xFFF6EFE2);
  static const almondSoft = Color(0xFFB9C4A6);
  static const ink = Color(0xFF2B2820);
  static const inkSoft = Color(0xFF726C5C);
  static const rust = Color(0xFFC1703E);
  static const hairline = Color(0xFFEDE6D6);
  static const danger = Color(0xFFC94C3F);
  static const dangerBg = Color(0xFFFBE9E7);
}

/// Two soft bezier waves behind the dark header — same motif used on the
/// login and forgot-password screens.
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

class TwoStepVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  const TwoStepVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<TwoStepVerificationScreen> createState() =>
      _TwoStepVerificationScreenState();
}

class _TwoStepVerificationScreenState
    extends State<TwoStepVerificationScreen> {
  // 6 individual controllers for OTP digits
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String? _verificationId;
  bool _loading = false;
  bool _sending = true;
  String? _errorMessage;

  // Resend countdown
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown == 0) {
        t.cancel();
      } else {
        if (mounted) setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _sendOtp() async {
    setState(() {
      _sending = true;
      _errorMessage = null;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verification on Android
        await _signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          setState(() {
            _sending = false;
            _errorMessage =
                'Failed to send OTP. Check your phone number and try again.';
          });
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _sending = false;
          });
          _startCountdown();
          // Auto-focus first digit
          _focusNodes[0].requestFocus();
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      await FirebaseAuth.instance.currentUser
          ?.linkWithCredential(credential);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ShellScreen()),
          (_) => false,
        );
      }
    } catch (_) {
      // Already linked — just proceed
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ShellScreen()),
          (_) => false,
        );
      }
    }
  }

  Future<void> _verify() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits.');
      return;
    }
    if (_verificationId == null) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.code == 'invalid-verification-code'
            ? 'Incorrect code. Please check and try again.'
            : 'Verification failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onDigitChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    // Auto-submit when all 6 filled
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length == 6) _verify();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top
            Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _FieldWavesPainter()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: _C.almond,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Verify your phone',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: _C.almond,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _sending
                            ? 'Sending code...'
                            : 'Enter the 6-digit code sent to ${widget.phoneNumber}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _C.matchaLight,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Form
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _C.almond,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: _sending
                    ? Center(
                        child: CircularProgressIndicator(color: _C.matcha),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),

                            // Error
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _C.dangerBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _C.danger.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: _C.danger,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // OTP boxes
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(6, (i) {
                                return SizedBox(
                                  width: 46,
                                  height: 56,
                                  child: TextFormField(
                                    controller: _controllers[i],
                                    focusNode: _focusNodes[i],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    maxLength: 1,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: _C.matcha,
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      contentPadding: EdgeInsets.zero,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide:
                                            BorderSide(color: _C.hairline),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: _C.rust,
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    onChanged: (v) => _onDigitChanged(v, i),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 32),

                            // Verify button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _verify,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _C.rust,
                                  foregroundColor: _C.almond,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Verify',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Resend
                            Center(
                              child: _resendCountdown > 0
                                  ? Text(
                                      'Resend code in ${_resendCountdown}s',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _C.inkSoft,
                                      ),
                                    )
                                  : GestureDetector(
                                      onTap: _sendOtp,
                                      child: Text(
                                        'Resend code',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _C.matcha,
                                        ),
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
      ),
    );
  }
}
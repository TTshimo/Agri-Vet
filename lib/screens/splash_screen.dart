import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'shell_screen.dart';

/// AgroLens palette — matcha green / almond / white, dark splash variant.
class _C {
  static const matchaDark = Color(0xFF374530);
  static const matcha = Color(0xFF5C7148);
  static const matchaLight = Color(0xFFD6E0C4);
  static const almond = Color(0xFFF6EFE2);
  static const rust = Color(0xFFC1703E);
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnim = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2200), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            user != null ? const ShellScreen() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.matchaDark,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: _C.rust,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(
                      Icons.eco_rounded,
                      size: 52,
                      color: _C.almond,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'AgroLens',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      color: _C.almond,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    'The Vet In Your Pocket.',
                    style: TextStyle(
                      fontSize: 14,
                      color: _C.matchaLight,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 48),

                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _C.matchaLight,
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
}
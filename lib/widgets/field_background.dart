import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// The AgroLens page background: almond with a soft green field wave along
/// the bottom (the look of the Diagnose tab). Wrap a page's body in it.
class FieldBackground extends StatelessWidget {
  const FieldBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: FieldWavePainter())),
        Positioned.fill(child: child),
      ],
    );
  }
}

class FieldWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Bg.matchaTint.withOpacity(0.5);
    final path = Path()
      ..moveTo(0, size.height * 0.82)
      ..cubicTo(
        size.width * 0.17, size.height * 0.76,
        size.width * 0.36, size.height * 0.86,
        size.width * 0.56, size.height * 0.79,
      )
      ..cubicTo(
        size.width * 0.72, size.height * 0.74,
        size.width * 0.86, size.height * 0.78,
        size.width, size.height * 0.76,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  // Repaint so the wave follows dark mode.
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

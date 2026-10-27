import 'package:flutter/widgets.dart';

/// The wavy bottom edge of the dark page headers, shared by every screen.
///
/// The wave lives in a fixed band at the bottom of the header
/// ([HeaderWaveClipper.band] logical pixels), whatever the header's height.
/// It used to be drawn as a percentage of the height, so on tall headers
/// (Profile, Make a pal) it cut into the name and the search field.
/// Keep at least [band] of bottom padding under header content.
class HeaderWaveClipper extends CustomClipper<Path> {
  const HeaderWaveClipper();

  static const double band = 64;

  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    // y for a point given as 0 (top of the band) .. 1 (bottom edge).
    double y(double t) => h - band * (1 - t);
    return Path()
      ..lineTo(0, y(0.37))
      ..cubicTo(w * 0.32, y(1), w * 0.66, y(0), w, y(0.47))
      ..lineTo(w, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

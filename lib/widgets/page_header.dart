import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// The green, wavy-edged header of the main tabs (Home, Diagnose,
/// Community, Learn): just the page name, plus an optional item on the
/// right (e.g. the language picker).
class WavyPageHeader extends StatelessWidget {
  const WavyPageHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: top + 80,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipPath(
            clipper: _WavyHeaderClipper(),
            child: Container(color: Bg.matchaHeader.withOpacity(0.88)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 20, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Fg.almond,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WavyHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.774)
      ..cubicTo(w * 0.806, h * 0.955, w * 0.639, h * 0.697, w * 0.458, h * 0.839)
      ..cubicTo(w * 0.292, h * 0.968, w * 0.153, h * 0.903, 0, h * 0.968)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

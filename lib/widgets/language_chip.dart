import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../theme/palette.dart';

/// Shows the current language and lets the farmer switch on the spot.
/// It changes the same app-wide setting as Settings → Language.
class LanguageChip extends StatelessWidget {
  /// true when shown on the light page background (result view),
  /// false on the dark header.
  final bool onLight;
  const LanguageChip({super.key, this.onLight = false});

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<LanguageProvider>();
    final fg = onLight ? Fg.matchaDark : Fg.almond;
    return GestureDetector(
      onTap: () => _pick(context, i18n),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: onLight
              ? Bg.matchaTint.withOpacity(0.7)
              : Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.translate_rounded, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(
              i18n.language.nativeName,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
            ),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: fg),
          ],
        ),
      ),
    );
  }

  void _pick(BuildContext context, LanguageProvider i18n) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Bg.almond,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            for (final lang in i18n.languages)
              ListTile(
                title: Text(lang.label, style: TextStyle(color: Fg.ink)),
                trailing: lang.code == i18n.code
                    ? Icon(Icons.check_circle, color: Fg.rust)
                    : null,
                onTap: () {
                  i18n.setLanguage(lang.code);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'store.dart';

/// Look-and-feel settings that can change while the app is open.
final ValueNotifier<(ThemeMode, double)> look = ValueNotifier((ThemeMode.system, 1.0));

void applyLook(Store p) {
  final m = p.getString('theme_mode') ?? 'system';
  final mode = m == 'dark' ? ThemeMode.dark : m == 'light' ? ThemeMode.light : ThemeMode.system;
  final s = (p.getDouble('text_scale') ?? 1.0).clamp(0.85, 1.5).toDouble();
  look.value = (mode, s);
}

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color cardBg(BuildContext c) => isDark(c) ? const Color(0xFF1F2725) : Colors.white;
Color tint(BuildContext c, Color light) => isDark(c) ? Color.lerp(light, const Color(0xFF121816), 0.82)! : light;

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFF21877C),
    brightness: b,
    scaffoldBackgroundColor: dark ? const Color(0xFF121816) : const Color(0xFFF8FAF8),
  );
}

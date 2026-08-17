// F.R.I.D.A.Y. Mobile — Neural Theme
// Design system neural: cores, tipografia e estilos compartilhados.

import 'package:flutter/material.dart';

// ── Paleta Neural ────────────────────────────────────────────────────────────
class NColor {
  static const cyan    = Color(0xFF00F0FF);
  static const cyanDim = Color(0xFF00B8CC);
  static const orange  = Color(0xFFFF6B00);
  static const emerald = Color(0xFF00FF88);
  static const red     = Color(0xFFFF2244);
  static const bgVoid  = Color(0xFF030609);
  static const bgDeep  = Color(0xFF050811);
  static const bgPanel = Color(0x88050C19);
  static const border  = Color(0x3300F0FF);
  static const textPrimary = Color(0xFFE0F8FF);
  static const textMuted   = Color(0x8CB4E6FF);
}

// ── Glow Helpers ─────────────────────────────────────────────────────────────
List<BoxShadow> glowCyan({double intensity = 1.0}) => [
  BoxShadow(color: NColor.cyan.withOpacity(0.45 * intensity), blurRadius: 20),
  BoxShadow(color: NColor.cyan.withOpacity(0.15 * intensity), blurRadius: 60),
];

List<BoxShadow> glowEmerald({double intensity = 1.0}) => [
  BoxShadow(color: NColor.emerald.withOpacity(0.45 * intensity), blurRadius: 20),
  BoxShadow(color: NColor.emerald.withOpacity(0.15 * intensity), blurRadius: 60),
];

List<BoxShadow> glowOrange({double intensity = 1.0}) => [
  BoxShadow(color: NColor.orange.withOpacity(0.45 * intensity), blurRadius: 20),
  BoxShadow(color: NColor.orange.withOpacity(0.15 * intensity), blurRadius: 60),
];

// ── Panel Decoration ─────────────────────────────────────────────────────────
BoxDecoration panelDecoration({Color? borderColor}) => BoxDecoration(
  color: NColor.bgPanel,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(
    color: borderColor ?? NColor.border,
    width: 1,
  ),
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      NColor.cyan.withOpacity(0.04),
      Colors.transparent,
    ],
  ),
);

// ── Gauge Track ──────────────────────────────────────────────────────────────
Color gaugeColor(double pct) {
  if (pct >= 85) return NColor.red;
  if (pct >= 65) return NColor.orange;
  return NColor.cyan;
}

// ── ThemeData ────────────────────────────────────────────────────────────────
ThemeData buildNeuralTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: NColor.bgVoid,
    colorScheme: const ColorScheme.dark(
      primary: NColor.cyan,
      secondary: NColor.emerald,
      tertiary: NColor.orange,
      surface: NColor.bgDeep,
      onPrimary: NColor.bgVoid,
      onSurface: NColor.textPrimary,
    ),
    fontFamily: 'monospace',
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: NColor.cyan, fontSize: 28, fontWeight: FontWeight.w900,
        letterSpacing: 4,
      ),
      titleLarge: TextStyle(
        color: NColor.textPrimary, fontSize: 16, fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
      bodyMedium: TextStyle(
        color: NColor.textMuted, fontSize: 13, letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        color: NColor.textMuted, fontSize: 10, letterSpacing: 1.5,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: NColor.bgPanel,
        foregroundColor: NColor.cyan,
        side: const BorderSide(color: NColor.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? NColor.emerald
            : NColor.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? NColor.emerald.withOpacity(0.3)
            : NColor.bgPanel,
      ),
    ),
    dividerColor: NColor.border,
    useMaterial3: true,
  );
}

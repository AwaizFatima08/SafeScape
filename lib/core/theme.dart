import 'package:flutter/material.dart';

/// Sensory-safe palette (PDD Step 3). No pure white, no alert red.
class SC {
  static const slate = Color(0xFF12131C); // base canvas
  static const slate2 = Color(0xFF1B1D2A); // cards
  static const slate3 = Color(0xFF262939); // raised / borders
  static const lavender = Color(0xFF9D8DF1);
  static const mint = Color(0xFF90DBB7);
  static const sand = Color(0xFFF4E4BA);
  static const blue = Color(0xFF89CFF0);
  static const text = Color(0xFFE8E6F0); // soft off-white
  static const textDim = Color(0xFFA9A7BA);
  static const peach = Color(0xFFF2B8A0); // gentle "attention" tone instead of red

  static Color palette(String name) => switch (name) {
    'mint' => mint,
    'sand' => sand,
    'blue' => blue,
    _ => lavender,
  };

  /// Three related tones per palette for particles.
  static List<Color> paletteTones(String name) => switch (name) {
    'mint' => const [Color(0xFF90DBB7), Color(0xFFB5EBD0), Color(0xFF7CC5C9)],
    'sand' => const [Color(0xFFF4E4BA), Color(0xFFF2C9A0), Color(0xFFE8D39A)],
    'blue' => const [Color(0xFF89CFF0), Color(0xFFA9C8F5), Color(0xFF9AE0E8)],
    _ => const [Color(0xFF9D8DF1), Color(0xFFBBA9F7), Color(0xFFD1A6E8)],
  };
}

/// Minimum physical touch target (PDD: 72 x 72 dp) and card radius (24).
const kTouch = 72.0;
const kRadius = 24.0;

ThemeData buildTheme() {
  final scheme = const ColorScheme.dark(
    primary: SC.lavender,
    onPrimary: SC.slate,
    secondary: SC.mint,
    onSecondary: SC.slate,
    tertiary: SC.sand,
    surface: SC.slate,
    onSurface: SC.text,
    surfaceContainerHighest: SC.slate3,
    error: SC.peach,
    onError: SC.slate,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Andika');
  return base.copyWith(
    scaffoldBackgroundColor: SC.slate,
    textTheme: base.textTheme.apply(bodyColor: SC.text, displayColor: SC.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: SC.slate,
      foregroundColor: SC.text,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: SC.slate2,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(kTouch, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        textStyle: const TextStyle(fontFamily: 'Andika', fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(kTouch, 52),
        foregroundColor: SC.text,
        side: const BorderSide(color: SC.slate3, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SC.slate2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: SC.slate3),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: SC.slate3, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: SC.lavender, width: 2),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? SC.slate : SC.textDim,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? SC.mint : SC.slate3,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: SC.lavender,
      thumbColor: SC.lavender,
      inactiveTrackColor: SC.slate3,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: SC.slate3,
      contentTextStyle: TextStyle(color: SC.text, fontFamily: 'Andika', fontSize: 16),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: SC.slate2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}

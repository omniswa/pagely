import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AccentOption {
  const AccentOption(this.name, this.color);
  final String name;
  final Color color;
}

abstract final class AppTheme {
  static const List<AccentOption> accents = [
    AccentOption('Indigo', Color(0xFF5B5BD6)),
    AccentOption('Teal', Color(0xFF0F9D8A)),
    AccentOption('Rose', Color(0xFFE5484D)),
    AccentOption('Amber', Color(0xFFE08A00)),
    AccentOption('Violet', Color(0xFF8E4EC6)),
  ];

  static AccentOption accentAt(int index) =>
      accents[(index >= 0 && index < accents.length) ? index : 0];

  static ThemeData build(Brightness brightness, Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final text = _withInter(base.textTheme)
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final radius = BorderRadius.circular(14);

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(maxWidth: 560),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
      ),
    );
  }

  static TextTheme _withInter(TextTheme theme) {
    TextStyle? withInter(TextStyle? style) {
      if (style == null) return null;

      final fontFamily = GoogleFonts.inter(
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
      ).fontFamily;
      return style.copyWith(fontFamily: fontFamily);
    }

    return theme.copyWith(
      displayLarge: withInter(theme.displayLarge),
      displayMedium: withInter(theme.displayMedium),
      displaySmall: withInter(theme.displaySmall),
      headlineLarge: withInter(theme.headlineLarge),
      headlineMedium: withInter(theme.headlineMedium),
      headlineSmall: withInter(theme.headlineSmall),
      titleLarge: withInter(theme.titleLarge),
      titleMedium: withInter(theme.titleMedium),
      titleSmall: withInter(theme.titleSmall),
      bodyLarge: withInter(theme.bodyLarge),
      bodyMedium: withInter(theme.bodyMedium),
      bodySmall: withInter(theme.bodySmall),
      labelLarge: withInter(theme.labelLarge),
      labelMedium: withInter(theme.labelMedium),
      labelSmall: withInter(theme.labelSmall),
    );
  }
}

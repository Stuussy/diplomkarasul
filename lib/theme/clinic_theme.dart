import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClinicTheme {
  static const ivory = Color(0xFFF4F7FB);
  static const porcelain = Color(0xFFFFFFFF);
  static const graphite = Color(0xFF1C2430);
  static const ash = Color(0xFF6B7280);
  static const line = Color(0xFFE3EAF4);
  static const sage = Color(0xFF5B8CF7);
  static const sageSoft = Color(0xFFDDE9FF);
  static const success = Color(0xFF22B07D);
  static const warning = Color(0xFFF2A65A);
  static const error = Color(0xFFE46C6C);
  static const info = Color(0xFF8CA3FF);

  static const radiusS = 12.0;
  static const radiusM = 16.0;
  static const radiusL = 20.0;

  static ThemeData light() {
    final base = ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: ivory,
      colorScheme: const ColorScheme.light(
        primary: sage,
        onPrimary: porcelain,
        surface: porcelain,
        onSurface: graphite,
        error: error,
        onError: porcelain,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: porcelain,
        foregroundColor: graphite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _textTheme(base.textTheme).titleLarge,
      ),
      cardTheme: CardThemeData(
        color: porcelain,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
          side: const BorderSide(color: line, width: 0.6),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: line,
        thickness: 0.6,
        space: 24,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: porcelain,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: sage, width: 1.2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: porcelain,
        selectedColor: sage,
        labelStyle: _textTheme(
          base.textTheme,
        ).labelLarge?.copyWith(color: graphite),
        secondaryLabelStyle: _textTheme(
          base.textTheme,
        ).labelLarge?.copyWith(color: porcelain),
        shape: StadiumBorder(side: const BorderSide(color: line)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: sage,
          foregroundColor: porcelain,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusS),
          ),
          textStyle: _textTheme(
            base.textTheme,
          ).labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: graphite,
          side: const BorderSide(color: line),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusS),
          ),
          textStyle: _textTheme(base.textTheme).labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: graphite,
          textStyle: _textTheme(base.textTheme).labelLarge,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: porcelain,
        indicatorColor: sageSoft,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          _textTheme(base.textTheme).labelMedium?.copyWith(color: graphite),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? sage : ash,
          ),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    final manrope = GoogleFonts.manropeTextTheme(base);
    final source = GoogleFonts.sourceSans3TextTheme(base);
    return source.copyWith(
      displayLarge: manrope.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: graphite,
      ),
      displayMedium: manrope.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: graphite,
      ),
      displaySmall: manrope.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: graphite,
      ),
      headlineLarge: manrope.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: graphite,
      ),
      headlineMedium: manrope.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: graphite,
      ),
      headlineSmall: manrope.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: graphite,
      ),
      titleLarge: manrope.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: graphite,
      ),
      titleMedium: manrope.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: graphite,
      ),
      titleSmall: manrope.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: graphite,
      ),
      bodyLarge: source.bodyLarge?.copyWith(color: graphite),
      bodyMedium: source.bodyMedium?.copyWith(color: graphite),
      bodySmall: source.bodySmall?.copyWith(color: ash),
      labelLarge: source.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: graphite,
      ),
      labelMedium: source.labelMedium?.copyWith(color: ash),
    );
  }
}

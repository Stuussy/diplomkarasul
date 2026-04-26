import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClinicTheme {
  // ── Core ──
  static const midnight = Color(0xFF0D1117);
  static const obsidian = Color(0xFF161B22);
  static const slate = Color(0xFF6E7681);
  static const mist = Color(0xFFF0F3F6);
  static const snow = Color(0xFFFFFFFF);

  // ── Brand ──
  static const azure = Color(0xFF2E7CF6);
  static const azureSoft = Color(0xFFE8F1FE);
  static const azureGlow = Color(0xFF5B9BFF);

  // ── Semantic ──
  static const mint = Color(0xFF1AAB8A);
  static const mintSoft = Color(0xFFE6F7F1);
  static const amber = Color(0xFFF5A524);
  static const amberSoft = Color(0xFFFFF4E0);
  static const coral = Color(0xFFEF4444);
  static const coralSoft = Color(0xFFFEE8E8);
  static const violet = Color(0xFF8B5CF6);
  static const violetSoft = Color(0xFFF0ECFE);

  // ── Spacing ──
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space32 = 32.0;

  // ── Radius ──
  static const radiusS = 12.0;
  static const radiusM = 16.0;
  static const radiusL = 22.0;
  static const radiusXL = 28.0;

  // ── Shadows ──
  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: const Color(0x08000000),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: const Color(0x06000000),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: const Color(0x0A000000),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: const Color(0x08000000),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: const Color(0x0C000000),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0x08000000),
          blurRadius: 40,
          offset: const Offset(0, 16),
        ),
      ];

  // ── Gradients ──
  static const heroGradient = LinearGradient(
    colors: [azure, azureGlow],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient mutedGradient([double opacity = 0.08]) {
    return LinearGradient(
      colors: [
        azure.withValues(alpha: opacity + 0.02),
        violet.withValues(alpha: opacity + 0.02),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // ── Theme ──
  static ThemeData light() {
    final base = ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: mist,
      colorScheme: const ColorScheme.light(
        primary: azure,
        onPrimary: snow,
        surface: snow,
        onSurface: midnight,
        error: coral,
        onError: snow,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: snow,
        foregroundColor: midnight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _textTheme(base.textTheme).titleLarge,
      ),
      cardTheme: CardThemeData(
        color: snow,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: mist,
        thickness: 0.6,
        space: 24,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: mist,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: azure, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: coral, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: snow,
        selectedColor: azure,
        labelStyle: _textTheme(base.textTheme)
            .labelLarge
            ?.copyWith(color: midnight),
        secondaryLabelStyle: _textTheme(base.textTheme)
            .labelLarge
            ?.copyWith(color: snow),
        shape: const StadiumBorder(),
        side: const BorderSide(color: mist),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: azure,
          foregroundColor: snow,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: _textTheme(base.textTheme)
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: midnight,
          side: const BorderSide(color: mist, width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: _textTheme(base.textTheme).labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: azure,
          textStyle: _textTheme(base.textTheme).labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: azure,
          foregroundColor: snow,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: _textTheme(base.textTheme)
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: snow,
        indicatorColor: azureSoft,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          _textTheme(base.textTheme).labelMedium?.copyWith(color: midnight),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? azure : slate,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: azure,
        foregroundColor: snow,
        elevation: 2,
        shape: CircleBorder(),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
        backgroundColor: snow,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: snow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    final jakarta = GoogleFonts.plusJakartaSansTextTheme(base);
    final dm = GoogleFonts.dmSansTextTheme(base);
    return dm.copyWith(
      displayLarge: jakarta.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: midnight,
        letterSpacing: -0.5,
      ),
      displayMedium: jakarta.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: midnight,
      ),
      displaySmall: jakarta.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: midnight,
      ),
      headlineLarge: jakarta.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: midnight,
      ),
      headlineMedium: jakarta.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: midnight,
      ),
      headlineSmall: jakarta.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: midnight,
      ),
      titleLarge: jakarta.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: midnight,
      ),
      titleMedium: jakarta.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: midnight,
      ),
      titleSmall: jakarta.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: midnight,
      ),
      bodyLarge: dm.bodyLarge?.copyWith(color: midnight, height: 1.5),
      bodyMedium: dm.bodyMedium?.copyWith(color: midnight, height: 1.5),
      bodySmall: dm.bodySmall?.copyWith(color: slate, height: 1.4),
      labelLarge: dm.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: midnight,
      ),
      labelMedium: dm.labelMedium?.copyWith(
        color: slate,
        letterSpacing: 0.5,
      ),
    );
  }
}

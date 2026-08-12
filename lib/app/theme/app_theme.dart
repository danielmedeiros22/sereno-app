import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Tema Material 3 do Sereno, em variantes claro e escuro.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const colors = _LightScheme();
    return _build(colors);
  }

  static ThemeData dark() {
    const colors = _DarkScheme();
    return _build(colors);
  }

  static ThemeData _build(_Scheme s) {
    final textTheme = AppTypography.buildTextTheme(s.text, s.textSoft);

    return ThemeData(
      useMaterial3: true,
      brightness: s.brightness,
      scaffoldBackgroundColor: s.bg,
      canvasColor: s.bg,

      colorScheme: ColorScheme(
        brightness: s.brightness,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        error: AppColors.riskCritical,
        onError: Colors.white,
        surface: s.surface,
        onSurface: s.text,
        surfaceContainerHighest: s.surface2,
        outline: s.border,
        outlineVariant: s.border,
      ),

      textTheme: textTheme,

      cardTheme: CardThemeData(
        color: s.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: s.border),
        ),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: s.text,
          side: BorderSide(color: s.border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: s.bg,
        foregroundColor: s.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),

      dividerTheme: DividerThemeData(
        color: s.border,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

abstract class _Scheme {
  const _Scheme();
  Brightness get brightness;
  Color get bg;
  Color get surface;
  Color get surface2;
  Color get border;
  Color get text;
  Color get textSoft;
}

class _LightScheme extends _Scheme {
  const _LightScheme();
  @override Brightness get brightness => Brightness.light;
  @override Color get bg => AppColors.bgLight;
  @override Color get surface => AppColors.surfaceLight;
  @override Color get surface2 => AppColors.surface2Light;
  @override Color get border => AppColors.borderLight;
  @override Color get text => AppColors.textLight;
  @override Color get textSoft => AppColors.textSoftLight;
}

class _DarkScheme extends _Scheme {
  const _DarkScheme();
  @override Brightness get brightness => Brightness.dark;
  @override Color get bg => AppColors.bgDark;
  @override Color get surface => AppColors.surfaceDark;
  @override Color get surface2 => AppColors.surface2Dark;
  @override Color get border => AppColors.borderDark;
  @override Color get text => AppColors.textDark;
  @override Color get textSoft => AppColors.textSoftDark;
}

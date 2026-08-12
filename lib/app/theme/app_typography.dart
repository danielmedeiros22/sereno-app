import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipografia do Sereno.
///
/// - Inter para UI (corpo, botões, labels)
/// - Fraunces para display (números grandes, títulos, humor da orbe)
class AppTypography {
  const AppTypography._();

  static TextTheme buildTextTheme(Color primaryText, Color secondaryText) {
    // Display (Fraunces) — usado em números e títulos
    final display = GoogleFonts.frauncesTextTheme();

    // Body (Inter) — usado em UI geral
    final body = GoogleFonts.interTextTheme();

    return TextTheme(
      displayLarge: display.displayLarge?.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w500,
        letterSpacing: -1.5,
        color: primaryText,
      ),
      displayMedium: display.displayMedium?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w500,
        letterSpacing: -1,
        color: primaryText,
      ),
      displaySmall: display.displaySmall?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
        color: primaryText,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: primaryText,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: primaryText,
      ),
      headlineSmall: body.headlineSmall?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      titleLarge: body.titleLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      titleMedium: body.titleMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      titleSmall: body.titleSmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: secondaryText,
        letterSpacing: 0.5,
      ),
      bodyLarge: body.bodyLarge?.copyWith(
        fontSize: 16,
        color: primaryText,
        height: 1.5,
      ),
      bodyMedium: body.bodyMedium?.copyWith(
        fontSize: 14,
        color: primaryText,
        height: 1.5,
      ),
      bodySmall: body.bodySmall?.copyWith(
        fontSize: 12,
        color: secondaryText,
        height: 1.5,
      ),
      labelLarge: body.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      labelMedium: body.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondaryText,
      ),
      labelSmall: body.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: secondaryText,
        letterSpacing: 0.8,
      ),
    );
  }
}

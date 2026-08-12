import 'package:flutter/material.dart';

/// Paleta oficial do Sereno.
///
/// Baseada em tons de azul/paz. Verde-água para positivo (entradas),
/// âmbar/laranja para negativo (saídas), sem vermelho agressivo.
class AppColors {
  const AppColors._();

  // Paleta principal
  static const primary = Color(0xFF3B82F6);      // Azul confiança
  static const secondary = Color(0xFF14B8A6);    // Verde-água
  static const accent = Color(0xFF8B5CF6);       // Lilás
  static const alert = Color(0xFFF97316);        // Âmbar

  // Superfícies — Light
  static const bgLight = Color(0xFFF8FAFC);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surface2Light = Color(0xFFF1F5F9);
  static const borderLight = Color(0xFFE2E8F0);
  static const textLight = Color(0xFF0F172A);
  static const textSoftLight = Color(0xFF64748B);
  static const textMuteLight = Color(0xFF94A3B8);

  // Superfícies — Dark
  static const bgDark = Color(0xFF020617);
  static const surfaceDark = Color(0xFF0F172A);
  static const surface2Dark = Color(0xFF1E293B);
  static const borderDark = Color(0xFF1E293B);
  static const textDark = Color(0xFFF1F5F9);
  static const textSoftDark = Color(0xFF94A3B8);
  static const textMuteDark = Color(0xFF64748B);

  // Financeiro
  static const income = Color(0xFF14B8A6);
  static const expense = Color(0xFFF97316);

  // Termômetro (5 estados)
  static const riskCalm = Color(0xFF14B8A6);        // 0-50%
  static const riskAttentive = Color(0xFF3B82F6);   // 50-75%
  static const riskWarning = Color(0xFFEAB308);     // 75-90%
  static const riskConcerned = Color(0xFFF97316);   // 90-100%
  static const riskCritical = Color(0xFFEF4444);    // >100%

  /// Retorna a cor de risco pra um percentual dado.
  static Color riskFor(double percent) {
    if (percent <= 50) return riskCalm;
    if (percent <= 75) return riskAttentive;
    if (percent <= 90) return riskWarning;
    if (percent <= 100) return riskConcerned;
    return riskCritical;
  }

  /// Retorna o rótulo do humor pra um percentual.
  static String moodFor(double percent) {
    if (percent <= 50) return 'Serena';
    if (percent <= 75) return 'Atenta';
    if (percent <= 90) return 'Alerta';
    if (percent <= 100) return 'Preocupada';
    return 'Estourou';
  }
}

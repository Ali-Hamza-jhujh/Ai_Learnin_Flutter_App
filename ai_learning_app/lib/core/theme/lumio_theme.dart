import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// Lumio design extensions — preserves existing AppColors palette.
class LumioDecorations {
  static BoxDecoration lumioCard({bool glowing = false}) => BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: glowing
              ? AppColors.violet.withValues(alpha: 0.6)
              : AppColors.textMuted.withValues(alpha: 0.15),
          width: glowing ? 1.5 : 1.0,
        ),
        boxShadow: glowing
            ? [
                BoxShadow(
                  color: AppColors.violet.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : [],
      );

  static BoxDecoration primaryButtonDecoration() => BoxDecoration(
        gradient: AppColors.primaryGrad,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.violet.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      );
}

extension LumioColors on AppColors {
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF0D1225), Color(0xFF111827)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color gemini = Color(0xFF4285F4);
  static const Color groq = Color(0xFFF97316);
  static const Color cerebras = Color(0xFF8B5CF6);
  static const Color offline = Color(0xFFFF9800);
  static const Color warning = Color(0xFFFFD600);
}

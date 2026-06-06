import 'package:flutter/material.dart';

import '../models/disziplin_schnittstelle.dart';

/// Einheitliche Blau-Palette für die gesamte App (keine bunten Akzentfarben).
class AppPalette {
  AppPalette._();

  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryMuted = Color(0xFF64B5F6);

  static const Color surface = Color(0xFFE8F1FA);
  static const Color surfaceNested = Color(0xFFF3F8FC);
  static const Color surfaceCard = Color(0xFFF8FBFE);
  static const Color surfaceChild = Color(0xFFEEF4FA);

  static const Color border = Color(0xFF90CAF9);
  static const Color borderMuted = Color(0xFFB3D4F0);
  static const Color borderExpanded = Color(0xFF5C9FD6);

  static const Color textPrimary = Color(0xFF1A3A5C);
  static const Color textSecondary = Color(0xFF5A7089);
  static const Color icon = Color(0xFF1565C0);
  static const Color iconMuted = Color(0xFF5C8FB8);
  static const Color iconChild = Color(0xFF4A8BC4);

  static const Color success = primary;
  static const Color successSurface = Color(0xFFE3F2FD);
  static const Color successBorder = Color(0xFF90CAF9);

  static const Color warning = primaryMuted;
  static const Color warningSurface = surface;
  static const Color warningBorder = borderMuted;
  static const Color warningText = Color(0xFF0D3B66);

  static const Color error = primaryDark;
  static const Color errorSurface = Color(0xFFDCE6F0);
  static const Color errorBorder = Color(0xFF7BA3C4);
  static const Color destructive = primaryDark;
  static const Color destructiveSurface = Color(0xFFD0DDE8);

  static const List<Color> shadeSteps = [
    primaryDark,
    primary,
    primaryLight,
    primaryMuted,
    icon,
    iconChild,
  ];

  static Color shadeForIndex(int index) =>
      shadeSteps[index.abs() % shadeSteps.length];

  static Color fieldTypeBackground(String type) {
    switch (type) {
      case 'int':
      case 'number':
        return primaryDark.withOpacity(0.1);
      case 'date':
        return primary.withOpacity(0.1);
      case 'dropdown':
        return primaryLight.withOpacity(0.12);
      default:
        return primaryMuted.withOpacity(0.12);
    }
  }

  static Color fieldTypeBorder(String type) {
    switch (type) {
      case 'int':
      case 'number':
        return primaryDark.withOpacity(0.28);
      case 'date':
        return primary.withOpacity(0.28);
      case 'dropdown':
        return primaryLight.withOpacity(0.35);
      default:
        return primaryMuted.withOpacity(0.35);
    }
  }

  static Color fieldTypeText(String type) {
    switch (type) {
      case 'int':
      case 'number':
        return primaryDark;
      case 'date':
        return primary;
      case 'dropdown':
        return const Color(0xFF1976D2);
      default:
        return const Color(0xFF1565C0);
    }
  }

  static Color progressColor(double percentage) {
    if (percentage >= 100) return primary;
    if (percentage >= 80) return primaryLight;
    if (percentage >= 50) return primaryMuted;
    return iconMuted;
  }

  static Color progressMotivationColor(double percentage) {
    if (percentage >= 100) return primary;
    if (percentage >= 80) return primaryLight;
    if (percentage >= 50) return primaryMuted;
    return icon;
  }
}

/// Theme-aware Farben für Anlagen-Formulare (Dark Mode + grüne Validierung).
class AnlageFormTheme {
  final Brightness brightness;

  const AnlageFormTheme(this.brightness);

  factory AnlageFormTheme.of(BuildContext context) =>
      AnlageFormTheme(Theme.of(context).brightness);

  bool get isDark => brightness == Brightness.dark;

  Color get scaffold => isDark ? const Color(0xFF1E1E1E) : Colors.white;

  Color get sectionBg => isDark ? const Color(0xFF262626) : const Color(0xFFFAFAFA);

  Color get fieldBg => isDark ? const Color(0xFF2C2C2C) : Colors.white;

  Color get fieldBgLocked => isDark ? const Color(0xFF222222) : const Color(0xFFF5F5F5);

  Color get fieldBgMissing => isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE);

  Color get innerFieldBg => isDark ? const Color(0xFF1E1E1E) : Colors.white;

  Color get groupFrameBg => isDark ? const Color(0xFF262626) : const Color(0xFFFAFAFA);

  Color get textPrimary => isDark ? const Color(0xFFF0F0F0) : const Color(0xFF212121);

  Color get textSecondary => isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575);

  Color get textHint => isDark ? const Color(0xFF9E9E9E) : const Color(0xFF9E9E9E);

  Color get textDisabled => isDark ? const Color(0xFF888888) : const Color(0xFF757575);

  Color get border => isDark ? const Color(0xFF484848) : const Color(0xFFE0E0E0);

  Color get borderSubtle => isDark ? const Color(0xFF383838) : const Color(0xFFE0E0E0);

  Color get divider => border;

  Color get iconMuted => isDark ? const Color(0xFF9E9E9E) : const Color(0xFFBDBDBD);

  /// Grünes Häkchen bei bestätigtem Feld (unabhängig vom App-Blau).
  Color get validationIcon => isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);

  Color get validationSurface => isDark ? const Color(0xFF1B3A24) : const Color(0xFFE8F5E9);

  Color get validationBorder => const Color(0xFF66BB6A);

  Color get validationFieldBorder =>
      validationBorder.withValues(alpha: isDark ? 0.55 : 0.45);

  Color get checkNeutralBg => isDark ? const Color(0xFF333333) : const Color(0xFFF5F5F5);

  Color get checkNeutralBorder => isDark ? const Color(0xFF616161) : const Color(0xFFBDBDBD);

  Color get errorSurface => isDark ? const Color(0xFF3D2020) : const Color(0xFFFFEBEE);

  Color get errorBorder => isDark ? const Color(0xFFE57373) : const Color(0xFFEF9A9A);

  Color get errorIcon => isDark ? const Color(0xFFEF5350) : const Color(0xFFD32F2F);

  Color get missingNeutralIcon => isDark ? const Color(0xFF9E9E9E) : const Color(0xFF616161);

  Color get shadow => Colors.black.withValues(alpha: isDark ? 0.35 : 0.04);

  Color get chipDisabledBg => isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE);

  Color get photoEmptyBg => innerFieldBg;

  Color get cancelButtonBorder => isDark ? const Color(0xFF616161) : const Color(0xFFE0E0E0);

  Color get cancelButtonText => isDark ? const Color(0xFFE0E0E0) : const Color(0xFF616161);
}

/// UI-Farbe für Disziplinen (ignoriert gespeicherte Einzelfarben).
extension DisziplinUiColors on Disziplin {
  Color get uiColor => AppPalette.icon;
  Color get uiBackground => AppPalette.primary.withOpacity(0.12);
}

import 'package:flutter/material.dart';

/// Central design system. Screens should pull colours, shapes and text styles
/// from here rather than hard-coding them.
class AppTheme {
  static const Color seed = Color(0xFF00696E); // clinical teal
  static const Color accent = Color(0xFFC62828); // blood red, used sparingly

  static const double radius = 16;
  static const double pagePadding = 20;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final isLight = brightness == Brightness.light;
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: isLight ? const Color(0xFFF6F8F8) : scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? const Color(0xFFF6F8F8) : scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: isLight ? 0.4 : 0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
        thickness: 1,
      ),
    );
  }
}

/// Colours for the appointment lifecycle, resolved per brightness.
class StatusStyle {
  final Color color;
  final IconData icon;
  final String label;

  const StatusStyle(this.color, this.icon, this.label);

  static StatusStyle of(String status, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    switch (status) {
      case 'assigned':
        return StatusStyle(
          dark ? const Color(0xFF7FB3FF) : const Color(0xFF1565C0),
          Icons.person_pin_circle_outlined,
          'Assigned',
        );
      case 'completed':
        return StatusStyle(
          dark ? const Color(0xFF7BD389) : const Color(0xFF2E7D32),
          Icons.check_circle_outline,
          'Completed',
        );
      case 'cancelled':
        return StatusStyle(
          dark ? const Color(0xFFB0B6BA) : const Color(0xFF616161),
          Icons.cancel_outlined,
          'Cancelled',
        );
      case 'pending':
      default:
        return StatusStyle(
          dark ? const Color(0xFFFFC46B) : const Color(0xFFE08600),
          Icons.schedule,
          'Pending',
        );
    }
  }
}

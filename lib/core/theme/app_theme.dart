import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';

abstract final class AppTheme {
  static const _seedColor = Color(0xFF146C60);
  static const _cornerRadius = 16.0;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: colors);
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(_cornerRadius)),
    );
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.large,
          vertical: AppSpacing.medium,
        ),
      ),
      shape: const WidgetStatePropertyAll(shape),
      textStyle: WidgetStatePropertyAll(base.textTheme.labelLarge),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(_cornerRadius),
      borderSide: BorderSide(color: colors.outline),
    );
    return base.copyWith(
      scaffoldBackgroundColor: colors.surface,
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.surfaceContainerLow,
        contentPadding: const EdgeInsets.all(AppSpacing.medium),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: colors.surfaceContainerLow,
        shape: shape,
        clipBehavior: Clip.antiAlias,
      ),
      // One consistent look for every SnackBar/toast in the app (success and
      // error feedback alike) rather than each call site styling its own.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cornerRadius / 2),
        ),
        backgroundColor: colors.inverseSurface,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
        actionTextColor: colors.inversePrimary,
      ),
    );
  }
}

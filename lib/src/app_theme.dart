import 'package:flutter/material.dart';

class AppTheme {
  static const _lightSeed = Color(0xFF3949AB); // azul base do ícone
  static const _darkSeed = Color(0xFF7986CB);

  static ThemeData get light => _buildTheme(
    ColorScheme.fromSeed(
      seedColor: _lightSeed,
      brightness: Brightness.light,
    ),
    isDark: false,
  );

  static ThemeData get dark => _buildTheme(
    ColorScheme.fromSeed(
      seedColor: _darkSeed,
      brightness: Brightness.dark,
    ),
    isDark: true,
  );

  static ThemeData _buildTheme(
      ColorScheme colorScheme, {
        required bool isDark,
      }) {
    // Textos base já usando Material 3
    final baseTextTheme = ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      useMaterial3: true,
    ).textTheme;

    final textTheme = baseTextTheme.copyWith(
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 22,
        letterSpacing: 0.1,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        height: 1.4,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        height: 1.4,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor:
      isDark ? colorScheme.surface : const Color(0xFFF3F5FB),

      textTheme: textTheme,

      // AppBar mais leve e “flat”
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),

      // Cartões usados em listas (Dashboard, Home, etc.)
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? colorScheme.surface : Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // ListTiles mais “encapsulados”, com cantos arredondados
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),

      // Campos de texto (busca, filtros, etc.)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.6,
          ),
        ),
        hintStyle: baseTextTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),

      // Barra de navegação inferior em estilo pill/moderninho
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
        isDark ? colorScheme.surface : const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          final base = textTheme.labelMedium ?? const TextStyle(fontSize: 11);
          return base.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color:
            selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
      ),

      chipTheme: ChipThemeData(
        backgroundColor:
        isDark ? colorScheme.surfaceContainerHighest : colorScheme.surface,
        selectedColor: colorScheme.primaryContainer,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.25),
        space: 24,
        thickness: 1,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

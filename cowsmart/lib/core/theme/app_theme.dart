import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        error: AppColors.error,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.promptTextTheme().copyWith(
        displayLarge: GoogleFonts.prompt(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.prompt(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        displaySmall: GoogleFonts.prompt(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.prompt(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        headlineMedium: GoogleFonts.prompt(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.prompt(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.prompt(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.prompt(color: AppColors.textPrimary),
        bodyMedium: GoogleFonts.prompt(color: AppColors.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.prompt(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.prompt(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.prompt(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: GoogleFonts.prompt(color: AppColors.textHint),
        labelStyle: GoogleFonts.prompt(color: AppColors.textSecondary),
      ),
    );
  }

  static ThemeData get darkTheme {
    const darkBackground = Color(0xFF141712);
    const darkSurface = Color(0xFF1F241C);
    const darkSurfaceAlt = Color(0xFF262D22);
    const darkTextPrimary = Color(0xFFECE6DA);
    const darkTextSecondary = Color(0xFFB8AE9D);
    const darkBorder = Color(0xFF353E30);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primaryLight,
        secondary: AppColors.accent,
        surface: darkSurface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkSurface,
      dividerColor: darkBorder,
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        modalBackgroundColor: darkSurface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return const TextStyle(color: darkTextSecondary, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryLight);
          }
          return const IconThemeData(color: darkTextSecondary);
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: darkTextSecondary,
      ),
      textTheme: GoogleFonts.promptTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.prompt(color: darkTextPrimary, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.prompt(color: darkTextPrimary, fontWeight: FontWeight.bold),
        displaySmall: GoogleFonts.prompt(color: darkTextPrimary, fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.prompt(color: darkTextPrimary, fontWeight: FontWeight.w600),
        headlineMedium: GoogleFonts.prompt(color: darkTextPrimary, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.prompt(color: darkTextPrimary, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.prompt(color: darkTextPrimary, fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.prompt(color: darkTextPrimary),
        bodyMedium: GoogleFonts.prompt(color: darkTextSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.prompt(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.prompt(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side: const BorderSide(color: AppColors.primaryLight),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.prompt(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      canvasColor: darkSurface,
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: GoogleFonts.prompt(color: darkTextPrimary),
        menuStyle: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(darkSurface),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: darkSurface,
        textStyle: TextStyle(color: darkTextPrimary),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: darkSurface,
        headerBackgroundColor: darkSurfaceAlt,
        headerForegroundColor: darkTextPrimary,
        surfaceTintColor: Colors.transparent,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          if (states.contains(WidgetState.disabled)) return darkTextSecondary.withValues(alpha: 0.4);
          return darkTextPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return null;
        }),
        todayForegroundColor: const WidgetStatePropertyAll(AppColors.primaryLight),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          if (states.contains(WidgetState.disabled)) return darkTextSecondary.withValues(alpha: 0.4);
          return darkTextPrimary;
        }),
        yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return null;
        }),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: darkSurface,
        hourMinuteTextColor: darkTextPrimary,
        hourMinuteColor: darkSurfaceAlt,
        dayPeriodTextColor: darkTextPrimary,
        dayPeriodColor: darkSurfaceAlt,
        dialBackgroundColor: darkSurfaceAlt,
        dialTextColor: darkTextPrimary,
        dialHandColor: AppColors.primary,
        entryModeIconColor: darkTextSecondary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceAlt,
        labelStyle: GoogleFonts.prompt(color: darkTextPrimary),
        side: const BorderSide(color: darkBorder),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIconColor: AppColors.primaryLight,
        suffixIconColor: darkTextSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: GoogleFonts.prompt(color: darkTextSecondary.withValues(alpha: 0.6)),
        labelStyle: GoogleFonts.prompt(color: darkTextSecondary),
      ),
    );
  }
}

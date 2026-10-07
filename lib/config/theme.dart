import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App color palette - premium Japanese aesthetic (和風: 墨・金茶・朱・藍)
class AppColors {
  // 墨 (sumi) - backgrounds
  static const Color sumi = Color(0xFF12100E);
  static const Color sumiSurface = Color(0xFF1C1915);
  static const Color sumiCard = Color(0xFF26211A);
  static const Color sumiLine = Color(0xFF3D362B);

  // 生成り (kinari) - text on dark
  static const Color washi = Color(0xFFF2EADB);
  static const Color washiDim = Color(0xFFB9AE9B);

  // 金茶 (kincha) - main accent
  static const Color kin = Color(0xFFC9A24D);
  static const Color kinLight = Color(0xFFE6CB86);

  // 朱 (shu) / 藍 (ai) / 藤 (fuji) / 若竹 (wakatake)
  static const Color shu = Color(0xFFC1442E);
  static const Color shuLight = Color(0xFFDB6A55);
  static const Color shuDark = Color(0xFF7A2618);
  static const Color ai = Color(0xFF3F6289);
  static const Color aiLight = Color(0xFF6F98C2);
  static const Color fuji = Color(0xFF9382B8);
  static const Color wakatake = Color(0xFF7FA463);
  static const Color wakatakeDark = Color(0xFF3B5A2A);

  // Existing names kept so current references keep working
  static const Color primary = sumi;
  static const Color primaryLight = sumiSurface;
  static const Color primaryDark = Color(0xFF0A0908);
  static const Color accent = kin;
  static const Color bambooGreen = wakatake; // 竹色 (takeniro)
  static const Color success = wakatake;
  static const Color warning = Color(0xFFE0A030);
  static const Color error = shuLight;
  static const Color white = washi; // 生成り
  static const Color grey100 = Color(0xFFF2EADB);
  static const Color grey300 = Color(0xFFD8CDB8);
  static const Color grey500 = Color(0xFF8C8272);
  static const Color grey700 = Color(0xFF5A5246);
  static const Color grey900 = sumiCard;
  static const Color bgDark = sumi;
  static const Color bgLight = Color(0xFFF5EEDF);
}

/// App Theme configuration
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.bgDark,

      canvasColor: AppColors.sumi,
      dividerColor: AppColors.sumiLine,

      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: AppColors.kin,
        onPrimary: AppColors.sumi,
        secondary: AppColors.shu,
        onSecondary: AppColors.washi,
        tertiary: AppColors.ai,
        surface: AppColors.sumiSurface,
        onSurface: AppColors.washi,
        error: AppColors.shuLight,
        outline: AppColors.sumiLine,
      ),

      // Typography - Japanese serif fonts via Google Fonts
      textTheme: TextTheme(
        displayLarge: GoogleFonts.notoSerifJp(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
        displayMedium: GoogleFonts.notoSerifJp(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
        // headlineSmall is the most-referenced variant across the app
        // (33 call sites) — was missing entirely, so it silently fell
        // back to Flutter's default font on every screen using it.
        headlineLarge: GoogleFonts.notoSerifJp(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
        headlineMedium: GoogleFonts.notoSerifJp(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
        headlineSmall: GoogleFonts.notoSerifJp(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
        titleLarge: GoogleFonts.notoSerifJp(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
        titleMedium: GoogleFonts.notoSerifJp(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.white,
        ),
        bodyLarge: GoogleFonts.notoSerifJp(
          fontSize: 16,
          color: AppColors.white,
        ),
        bodyMedium: GoogleFonts.notoSerifJp(
          fontSize: 14,
          color: AppColors.grey300,
        ),
        labelLarge: GoogleFonts.notoSerifJp(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
        // 以前はここで未定義だったバリアント（多くの画面がbodySmall/
        // titleSmall等を直接参照している）は、Flutter標準の
        // デフォルトフォントにフォールバックしてしまい、和文明朝体が
        // 適用されない箇所があったため追加する。
        displaySmall: GoogleFonts.notoSerifJp(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
        titleSmall: GoogleFonts.notoSerifJp(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
        bodySmall: GoogleFonts.notoSerifJp(
          fontSize: 12,
          color: AppColors.grey300,
        ),
        labelMedium: GoogleFonts.notoSerifJp(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.white,
        ),
        labelSmall: GoogleFonts.notoSerifJp(
          fontSize: 11,
          color: AppColors.grey300,
        ),
      ),

      // Button styles
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.sumi,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.primaryLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: AppColors.sumiLine,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: AppColors.sumiLine,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: AppColors.kin,
            width: 1.5,
          ),
        ),
        hintStyle: const TextStyle(color: AppColors.grey500),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // App bar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.notoSerifJp(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 4,
          color: AppColors.white,
        ),
        iconTheme: const IconThemeData(color: AppColors.kin),
        shape: Border(
          bottom: BorderSide(
            color: AppColors.kin.withOpacity(0.25),
            width: 1,
          ),
        ),
      ),

      // Components - hairline gold borders, small radius
      cardTheme: CardThemeData(
        color: AppColors.sumiCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: AppColors.kin.withOpacity(0.35)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.kin,
          side: const BorderSide(color: AppColors.kin),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.kin),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.sumiSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: AppColors.kin.withOpacity(0.35)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.sumiSurface,
        modalBackgroundColor: AppColors.sumiSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.sumiCard,
        contentTextStyle: const TextStyle(color: AppColors.washi),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: AppColors.kin.withOpacity(0.35)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.sumiLine,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.sumiCard,
        selectedColor: AppColors.kin.withOpacity(0.25),
        labelStyle: const TextStyle(color: AppColors.washi),
        side: BorderSide(color: AppColors.kin.withOpacity(0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.kin,
        textColor: AppColors.washi,
      ),
      iconTheme: const IconThemeData(color: AppColors.washi),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.kin,
        linearTrackColor: AppColors.sumiLine,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.kin
              : AppColors.washiDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.kin.withOpacity(0.35)
              : AppColors.sumiLine,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.white,
      scaffoldBackgroundColor: AppColors.bgLight,

      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        secondary: AppColors.grey100,
        surface: AppColors.white,
        background: AppColors.bgLight,
        error: AppColors.error,
      ),

      textTheme: TextTheme(
        displayLarge: GoogleFonts.notoSerifJp(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        bodyMedium: GoogleFonts.notoSerifJp(
          fontSize: 14,
          color: AppColors.grey700,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// 👇 Yahan gaur karein: Humne 'app_colors.dart' ko import kiya hai
import 'app_colors.dart'; 

class AppTheme {
  // ☀️ Light Theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground, // ✅ Yahan AppColors use ho raha hai
    primaryColor: AppColors.primaryStart,
    
    // Text Styling
    textTheme: _buildTextTheme(Colors.black87),
    
    // Input Fields
    inputDecorationTheme: _inputDecoration(Colors.grey.shade200, Colors.black54),
  );

  // 🌙 Dark Theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground, // ✅ Yahan AppColors use ho raha hai
    primaryColor: AppColors.primaryStart,
    
    // Text Styling
    textTheme: _buildTextTheme(AppColors.textLight),
    
    // Input Fields
    inputDecorationTheme: _inputDecoration(AppColors.darkSurface, Colors.white60),
  );

  // Helper Functions (Fonts setup)
  static TextTheme _buildTextTheme(Color color) {
    return TextTheme(
      displayLarge: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.bold, color: color),
      displayMedium: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w600, color: color),
      bodyLarge: GoogleFonts.outfit(fontSize: 16, color: color),
      bodyMedium: GoogleFonts.outfit(fontSize: 14, color: color.withOpacity(0.8)),
      labelLarge: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
    );
  }

  static InputDecorationTheme _inputDecoration(Color fill, Color iconColor) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      prefixIconColor: iconColor,
      labelStyle: GoogleFonts.outfit(color: iconColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryStart, width: 2),
      ),
    );
  }
}
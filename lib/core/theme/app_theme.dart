import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart'; 

class AppTheme {
  // ☀️ LIGHT THEME
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    primaryColor: AppColors.primaryStart,
    
    // ✅ Main Text Theme
    textTheme: _buildTextTheme(AppColors.textDark),
    
    // ✅ Input Fields (Login/Signup Boxes)
    inputDecorationTheme: _inputDecoration(
      fillColor: Colors.white, 
      textColor: AppColors.textDark, 
      borderColor: Colors.grey.shade300,
    ),
  );

  // 🌙 DARK THEME
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    primaryColor: AppColors.primaryStart,
    
    // ✅ Main Text Theme
    textTheme: _buildTextTheme(AppColors.textLight),
    
    // ✅ Input Fields
    inputDecorationTheme: _inputDecoration(
      fillColor: AppColors.darkSurface, 
      textColor: AppColors.textLight, 
      borderColor: Colors.white10,
    ),
  );

  // --- HELPER FUNCTIONS ---

  static TextTheme _buildTextTheme(Color color) {
    return TextTheme(
      displayLarge: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.bold, color: color),
      displayMedium: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w600, color: color),
      
      // Body text (used inside TextFields mostly)
      bodyLarge: GoogleFonts.outfit(fontSize: 16, color: color),
      // ✨ FIX: withOpacity -> withValues(alpha: 0.8)
      bodyMedium: GoogleFonts.outfit(fontSize: 14, color: color.withValues(alpha: 0.8)),
      
      labelLarge: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
    );
  }

  static InputDecorationTheme _inputDecoration({
    required Color fillColor, 
    required Color textColor, 
    required Color borderColor
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      // ✨ FIX: withOpacity -> withValues(alpha: 0.7)
      prefixIconColor: textColor.withValues(alpha: 0.7), 
      
      // 1. Text Color when typing uses textTheme.bodyLarge automatically.
      
      // 2. Label Text (e.g. "Email") - Normal State
      // ✨ FIX: withOpacity -> withValues(alpha: 0.7)
      labelStyle: GoogleFonts.outfit(color: textColor.withValues(alpha: 0.7)), 
      
      // 3. Label Text (When box is clicked/active)
      floatingLabelStyle: GoogleFonts.outfit(color: AppColors.primaryStart, fontWeight: FontWeight.bold), 
      
      // 4. Hint Text (e.g. "Enter your email")
      // ✨ FIX: withOpacity -> withValues(alpha: 0.4)
      hintStyle: GoogleFonts.outfit(color: textColor.withValues(alpha: 0.4)),

      // Borders
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryStart, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
    );
  }
}
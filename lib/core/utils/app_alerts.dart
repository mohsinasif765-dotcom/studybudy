import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppAlerts {
  
  // 🔴 ERROR SNACKBAR (Red)
  static void showError(BuildContext context, String message) {
    _showSnackbar(
      context, 
      message, 
      color: const Color(0xFFDC2626), // Red-600
      icon: Icons.error_outline_rounded,
      title: "Oops!",
    );
  }

  // 🟢 SUCCESS SNACKBAR (Green)
  static void showSuccess(BuildContext context, String message) {
    _showSnackbar(
      context, 
      message, 
      color: const Color(0xFF059669), // Emerald-600
      icon: Icons.check_circle_outline_rounded,
      title: "Success",
    );
  }

  // 🔵 INFO SNACKBAR (Blue)
  static void showInfo(BuildContext context, String message) {
    _showSnackbar(
      context, 
      message, 
      color: const Color(0xFF2563EB), // Blue-600
      icon: Icons.info_outline_rounded,
      title: "Note",
    );
  }

  // Internal Helper
  static void _showSnackbar(BuildContext context, String message, {
    required Color color, 
    required IconData icon,
    required String title,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Purana hatao
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                // ✨ FIX: withOpacity -> withValues(alpha: 0.2)
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    message,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      // ✨ FIX: withOpacity -> withValues(alpha: 0.9)
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating, // Floating Style
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 4,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
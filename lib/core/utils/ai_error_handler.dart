import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:prepvault_ai/features/subscription/widgets/pricing_modal.dart';

void handleAiError(BuildContext context, dynamic error) {
  final String errorMsg = error.toString();
  
  // 🔍 DEBUG LOG: Asli Error print karo console mein
  debugPrint("🚨 [ERROR HANDLER] Received Error: '$errorMsg'");

  // Check different variations of the error message
  if (errorMsg.contains("LOW_CREDITS") || 
      errorMsg.contains("insufficient credits") ||
      errorMsg.contains("Need") && errorMsg.contains("have")) { // Loose matching
    
    debugPrint("✅ [ERROR HANDLER] Low Credits Detected! Showing Popup.");

    // Extract numbers safely
    String need = "more";
    String have = "0";
    
    try {
        final needMatch = RegExp(r'Need (\d+)').firstMatch(errorMsg);
        final haveMatch = RegExp(r'have (\d+)').firstMatch(errorMsg);
        if (needMatch != null) need = needMatch.group(1)!;
        if (haveMatch != null) have = haveMatch.group(1)!;
    } catch (_) {}

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text("Low Credits", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Action requires $need credits. You have $have.",
              style: GoogleFonts.outfit(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Text(
              "Upgrade your plan to continue.",
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryStart,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context); 
              showDialog(
                context: context,
                builder: (context) => const PricingModal(currentPlanId: 'free'),
              );
            },
            child: const Text("Get Credits"),
          ),
        ],
      ),
    );
  } else {
    // Generic Error
    debugPrint("❌ [ERROR HANDLER] Generic Error Shown.");
    
    String displayMsg = errorMsg.replaceAll('Exception:', '').replaceAll('Error:', '').trim();
    if (displayMsg.length > 100) displayMsg = "Something went wrong. Please check your connection.";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Error: $displayMsg"),
        backgroundColor: Colors.red,
      ),
    );
  }
}
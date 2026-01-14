import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepvault_ai/features/subscription/services/google_play_service.dart';

class SubscriptionManager {
  final _supabase = Supabase.instance.client;
  final _googleService = GooglePlayService();
  final _inAppPurchase = InAppPurchase.instance;

  // =================================================================
  // 🚀 MAIN FUNCTION: Buy Plan via Google Play
  // =================================================================
  Future<void> buyPlan(BuildContext context, String planId) async {
    try {
      debugPrint("💳 [MANAGER] Initiating purchase for Plan ID: $planId");
      
      // 1. Database se Google Product ID fetch karna
      final planData = await _getPlanDetails(planId);
      
      if (planData == null) {
        _showError(context, "Plan details not found in database. Please check your connection.");
        return;
      }

      // 2. Column 'google_product_id' se value nikalna
      final String? googleProductId = planData['google_product_id'];

      if (googleProductId == null || googleProductId.isEmpty) {
        debugPrint("⚠️ Error: google_product_id is NULL for plan: $planId");
        _showError(context, "This plan is not configured for Google Play store yet.");
        return;
      }

      debugPrint("🔍 [MANAGER] Found Google Product ID: $googleProductId");

      // 3. Google Play Store Availability Check
      final bool isAvailable = await _inAppPurchase.isAvailable();
      
      if (!isAvailable) {
        _showError(context, "Google Play Store is currently unavailable on this device.");
        return;
      }

      // 4. Start Google Billing Flow using the fetched Product ID
      debugPrint("🟢 [MANAGER] Passing to Google Service: $googleProductId");
      await _googleService.buyProduct(context, googleProductId);
      
      // Note: Transaction ki verification main.dart mein lage listener se hogi.

    } catch (e) {
      debugPrint("❌ [MANAGER] Fatal Purchase Error: $e");
      _showError(context, "An unexpected error occurred: $e");
    }
  }

  // =================================================================
  // 🛠️ HELPER FUNCTIONS
  // =================================================================

  /// Supabase se sirf 'google_product_id' fetch karta hai
  Future<Map<String, dynamic>?> _getPlanDetails(String planId) async {
    try {
      final data = await _supabase
          .from('plans')
          .select('google_product_id') 
          .eq('id', planId)
          .maybeSingle();
      
      return data;
    } catch (e) {
      debugPrint("❌ [DATABASE ERROR]: $e");
      return null;
    }
  }

  /// Error UI dikhanay ke liye
  void _showError(BuildContext context, String msg) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
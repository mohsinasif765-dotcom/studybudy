import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:prepvault_ai/core/utils/app_alerts.dart'; // Aapke alerts use kiye hain

class GooglePlayService {
  final InAppPurchase _iap = InAppPurchase.instance;

  // =================================================================
  // 1️⃣ CHECK AVAILABILITY
  // =================================================================
  Future<bool> isAvailable() async {
    try {
      final bool available = await _iap.isAvailable();
      if (!available) {
        debugPrint("❌ [GOOGLE PLAY] Store is not available (Maybe emulator or no internet).");
      }
      return available;
    } catch (e) {
      debugPrint("❌ [GOOGLE PLAY] Availability Check Error: $e");
      return false;
    }
  }

  // =================================================================
  // 2️⃣ START PURCHASE FLOW
  // =================================================================
  Future<void> buyProduct(BuildContext context, String productId) async {
    try {
      debugPrint("🛒 [GOOGLE PLAY] Fetching details for: $productId");

      // A. Pehle Product Details Mangwani parti hain Google se
      final Set<String> _kIds = {productId};
      final ProductDetailsResponse response = await _iap.queryProductDetails(_kIds);

      // B. Agar Product nahi mila (Console par active nahi hai)
      if (response.notFoundIDs.isNotEmpty) {
        if (context.mounted) {
          AppAlerts.showError(context, "Product not found on Google Play Console.");
        }
        debugPrint("❌ [GOOGLE PLAY] Product ID '$productId' not found in store.");
        return;
      }

      if (response.error != null) {
        throw response.error!;
      }

      // C. Details mil gayi, ab Purchase Flow start karo
      final ProductDetails productDetails = response.productDetails.first;
      
      debugPrint("✅ [GOOGLE PLAY] Product Found: ${productDetails.title} (${productDetails.price})");
      debugPrint("🚀 [GOOGLE PLAY] Launching Billing Flow...");

      final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
      
      // Non-Consumable (Subscription/Lifetime) ke liye ye use hota hai
      // Google Play UI open karega
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);

    } catch (e) {
      debugPrint("❌ [GOOGLE PLAY] Purchase Init Error: $e");
      if (context.mounted) {
        AppAlerts.showError(context, "Could not connect to Google Play.");
      }
    }
  }
}
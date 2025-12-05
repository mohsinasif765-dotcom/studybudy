import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// import 'package:huawei_iap/huawei_iap.dart'; // Uncomment if using Huawei

class PaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final InAppPurchase _iap = InAppPurchase.instance;

  // 🚀 MAIN FUNCTION: Buy Plan
  // Added 'isYearly' parameter
  Future<void> buyPlan(String planId, {bool isYearly = false}) async {
    try {
      
      // 1. 🌐 WEB FLOW (Stripe)
      if (kIsWeb) {
        await _handleWebPayment(planId, isYearly);
      } 
      
      // 2. 🤖 ANDROID FLOW
      else if (Platform.isAndroid) {
        // Construct Store Product ID (e.g., 'basic_monthly' or 'pro_yearly')
        // Mini plan sirf monthly hai, uske liye check lagana behtar hai
        String storeProductId = planId == 'mini' 
            ? 'mini_monthly' 
            : '${planId}_${isYearly ? 'yearly' : 'monthly'}';

        if (await _isHuaweiDevice()) {
          await _handleHuaweiPayment(storeProductId);
        } else {
          await _handleGooglePlayPayment(storeProductId);
        }
      }
      
      // 3. 🍎 IOS FLOW
      else if (Platform.isIOS) {
        String storeProductId = planId == 'mini' 
            ? 'mini_monthly' 
            : '${planId}_${isYearly ? 'yearly' : 'monthly'}';
            
        await _handleGooglePlayPayment(storeProductId); // Uses generic IAP
      }

    } catch (e) {
      print("Payment Error: $e");
      rethrow; // Rethrow taake UI mein SnackBar dikha sakein
    }
  }

  // ==========================================
  // 🌐 WEB: STRIPE
  // ==========================================
  Future<void> _handleWebPayment(String planId, bool isYearly) async {
    final response = await _supabase.functions.invoke(
      'payment-manager',
      body: {
        'action': 'create_stripe_session',
        'planId': planId,
        'interval': isYearly ? 'year' : 'month', // 👇 Backend ko batao
      },
    );

    if (response.status != 200) {
      throw Exception("Stripe Error: ${response.data}");
    }

    final url = response.data['url'];
    if (url != null) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  // ==========================================
  // 🤖 GOOGLE PLAY / APPLE STORE
  // ==========================================
  Future<void> _handleGooglePlayPayment(String productId) async {
    final bool available = await _iap.isAvailable();
    if (!available) throw Exception("Store not available");

    Set<String> _kIds = {productId}; 
    
    final ProductDetailsResponse response = await _iap.queryProductDetails(_kIds);
    
    if (response.notFoundIDs.isNotEmpty) {
      // Agar product ID match na ho Store se
      throw Exception("Product '$productId' not found in Store");
    }

    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    // Start Purchase
    // Note: Iska result 'main.dart' mein IAP stream listener handle karega
    _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  // ==========================================
  // 🧧 HUAWEI APP GALLERY
  // ==========================================
  Future<void> _handleHuaweiPayment(String productId) async {
    print("Huawei Payment: $productId");
    // Huawei logic here...
  }

  // ==========================================
  // 🔐 BACKEND VERIFICATION
  // ==========================================
  Future<void> verifyMobileReceipt(String planId, String receiptData, String platform) async {
    final response = await _supabase.functions.invoke(
      'payment-manager',
      body: {
        'action': 'verify_mobile_receipt',
        'planId': planId,
        'platform': platform,
        'receipt': receiptData,
      },
    );

    if (response.status != 200) throw Exception("Verification Failed");
    print("Plan Activated via Mobile!");
  }

  // 🕵️ Helper
  Future<bool> _isHuaweiDevice() async {
    return false; // Default Google
  }
}
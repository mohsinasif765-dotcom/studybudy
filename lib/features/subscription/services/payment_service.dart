import 'package:flutter/foundation.dart'; // ✅ Added for debugPrint
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentService {
  final _supabase = Supabase.instance.client;

  Future<void> startStripePayment(String planId, String interval) async {
    try {
      final response = await _supabase.functions.invoke(
        'payment-manager',
        body: {
          'action': 'create_stripe_session',
          'planId': planId,
          'interval': interval,
          'platform': 'mobile', 
          'is_mobile': true, 
          'callback_url': null, 
        },
      );

      final data = response.data;
      if (data == null || data['url'] == null) {
        throw "Failed to create payment session.";
      }

      final String checkoutUrl = data['url'];
      final uri = Uri.parse(checkoutUrl);

      debugPrint("🔗 [STRIPE MOBILE] Launching: $checkoutUrl");

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, 
        );
      } else {
        throw "Could not launch payment URL.";
      }

    } catch (e) {
      debugPrint("❌ [PAYMENT ERROR]: $e");
      throw "Payment Error: $e";
    }
  }
}
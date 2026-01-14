import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepvault_ai/features/subscription/widgets/pricing_modal.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  Future<void> _onContinueFree(BuildContext context) async {
    // 💾 Save Flag: User ne paywall dekh liya
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_paywall', true);

    if (context.mounted) {
      // 🚀 Go to Dashboard
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PricingModal(
        currentPlanId: 'free',
        isFullScreen: true, // 🔥 Full Screen Mode ON
        onContinueFree: () => _onContinueFree(context), // 🔥 Custom Logic
      ),
    );
  }
}
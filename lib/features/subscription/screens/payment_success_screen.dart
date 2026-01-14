import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 👈 Import Zaroori hai
import 'package:prepvault_ai/core/theme/app_colors.dart';

class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  late ConfettiController _controller;
  bool _isSyncing = true; // Loading state to show processing

  @override
  void initState() {
    super.initState();
    // 1. Initialize Confetti
    _controller = ConfettiController(duration: const Duration(seconds: 5));
    _controller.play();

    // 2. 🔥 Refresh Profile Data Immediately
    _syncUserProfile();
  }

  // 👇 Ye function Webhook ke baad latest data kheench layega
  Future<void> _syncUserProfile() async {
    try {
      debugPrint("⏳ [UI] Waiting for Webhook update...");
      // Thora wait karein taake Stripe Webhook DB update kar le
      await Future.delayed(const Duration(seconds: 3));

      debugPrint("🔄 [UI] Syncing Profile...");
      
      // ✅ FIX: 'client' add kiya hai beech mein
      await Supabase.instance.client.functions.invoke('payment-manager', body: {
        'action': 'sync_profile' 
      });

      debugPrint("✅ [UI] Profile Synced Successfully!");
      
      if (mounted) {
        setState(() {
          _isSyncing = false; // Sync complete
        });
      }
    } catch (e) {
      debugPrint("⚠️ [UI] Sync Warning: $e");
      // Agar error bhi aaye to user ko rokna nahi hai
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. CONTENT (Center)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Scale Icon
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle_rounded, size: 100, color: Colors.green),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  Text(
                    "Payment Successful!",
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 🔥 Dynamic Text
                  Text(
                    _isSyncing 
                        ? "Finalizing your upgrade...\nPlease wait a moment." 
                        : "Thank you for your purchase.\nYour credits have been added.",
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: GoogleFonts.outfit(fontSize: 16, color: Colors.black54, height: 1.5),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Go Home Button
                  if (_isSyncing) 
                     const CircularProgressIndicator(color: AppColors.primaryStart)
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          // Dashboard par wapis jao aur stack clear karo
                          context.go('/dashboard'); 
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryStart,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text("Continue Studying", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. CONFETTI (Top Center)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _controller,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
              gravity: 0.2,
              numberOfParticles: 20,
            ),
          ),
        ],
      ),
    );
  }
}
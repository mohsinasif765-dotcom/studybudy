import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepvault_ai/core/services/ad_service.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';

class CreditManager {
  
  static Future<bool> canProceed({
    required BuildContext context, 
    required int requiredCredits, 
    required int availableCredits
  }) async {
    
    // 1. Agar credits kaafi hain -> Shukar hai, chalo! ✅
    if (availableCredits >= requiredCredits) {
      return true;
    }

    // 2. Low Credits Dialog
    final bool? shouldWatchAd = await showDialog<bool>(
      context: context,
      barrierDismissible: false, 
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.bolt, color: Colors.orange),
            SizedBox(width: 10),
            Text("Low Credits!"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("This action requires $requiredCredits credits, but you have $availableCredits."),
            const SizedBox(height: 15),
            const Text("Get more credits to continue:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade50, 
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: ListTile(
                leading: const Icon(Icons.play_circle_filled, color: Colors.green, size: 30),
                title: const Text("Watch Ad", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text("Get +10 Credits Instantly", style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(ctx, true),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryStart, 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx, false);
              context.push('/subscription');
            },
            child: const Text("Upgrade Plan"),
          ),
        ],
      ),
    );

    if (!context.mounted) return false;

    // 3. Agar User ne "Watch Ad" select kiya
    if (shouldWatchAd == true) {
      return await _processAdAndCreditUpdate(context);
    }

    return false;
  }

  // 🔥 UPDATED: Secure Processing Logic
  static Future<bool> _processAdAndCreditUpdate(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return false;

    // 1. Loader Dikhao
    _showLoading(context);

    try {
      // 2. Show Rewarded Ad
      bool adWatched = await AdService().showRewardedAd(); 
      
      // Loader Hatao (Ad khatam hone ke baad)
      if (context.mounted) Navigator.pop(context);

      if (adWatched) {
        // 3. Dubara Loader (Database update ke liye)
        if (context.mounted) _showLoading(context);

        // ✅ FIX 1: Overwrite khatam. Database khud calculate karega.
        await supabase.rpc('increment_credits_safe', params: {
          'user_id': userId,
          'amount_to_add': 10,
        });

        // ✅ FIX 2: Edge Function call karein taakay App ki state sync ho jaye
        // Ye wahi function hai jo humne 'sync_profile' ke liye likha tha
        try {
          await supabase.functions.invoke('payment-manager', body: {'action': 'sync_profile'});
        } catch (e) {
          debugPrint("Sync Warning: Edge function sync failed but credits added.");
        }

        if (context.mounted) Navigator.pop(context); // Final Loader Hatao

        // Success Feedback
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🎉 +10 Credits Added! Try again now."),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            )
          );
        }
        return true; 
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ad skipped. No credits added.")));
        }
      }
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      debugPrint("Credit Manager Error: $e");
    }

    return false;
  }

  // Helper function for loading dialog
  static void _showLoading(BuildContext context) {
    if (!context.mounted) return;
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primaryStart)),
    );
  }
}
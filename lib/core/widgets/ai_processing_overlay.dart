import 'dart:ui'; // ImageFilter ke liye
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';

class AIProcessingOverlay {
  
  // ===========================================================================
  // 1️⃣ PUBLIC SHOW METHOD (Entry Point)
  // ===========================================================================
  static Future<T?> show<T>({
    required BuildContext context,
    required Future<T> Function(Function(String) updateStatus) asyncTask,
    String initialMessage = "Processing...", 
  }) async {
    
    debugPrint("🚀 [OVERLAY] Request received. Opening Dialog...");
    debugPrint("ℹ️ [OVERLAY] Initial Message: $initialMessage");

    // 1. Show Dialog & Wait for Result
    final result = await showDialog(
      context: context,
      barrierDismissible: false, // User bahar click karke band na kar sake
      // ✨ FIX: withOpacity -> withValues(alpha: 0.85)
      barrierColor: Colors.black.withValues(alpha: 0.85), 
      builder: (context) => _ProcessingDialog(
        asyncTask: asyncTask,
        initialMessage: initialMessage,
      ),
    );

    // 2. 🛑 ERROR HANDLING MAGIC
    // Agar Dialog se error wapis aya (jo humne _error_wrapper_ mein chupaya tha)
    if (result is Map && result.containsKey('_error_wrapper_')) {
      debugPrint("❌ [OVERLAY] Error detected from dialog. Rethrowing to parent...");
      throw result['_error_wrapper_'];
    }

    debugPrint("✅ [OVERLAY] Dialog closed successfully. Returning result.");
    return result as T?;
  }

  // ===========================================================================
  // 2️⃣ BACKGROUND NOTIFICATION (Large Files)
  // ===========================================================================
  static void showBackgroundNotification(BuildContext context) {
    debugPrint("⚠️ [OVERLAY] Switching to Background Mode Notification");
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                // ✨ FIX: withOpacity -> withValues(alpha: 0.1)
                color: Colors.orange.withValues(alpha: 0.1), 
                shape: BoxShape.circle
              ),
              child: const Icon(Icons.access_time_rounded, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Taking a bit longer...", 
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 18)
              )
            ),
          ],
        ),
        content: Text(
          "Your file is large, so we've moved processing to the background.\n\nYou can safely use the app. We'll update 'Recent Activity' once ready.",
          style: GoogleFonts.outfit(fontSize: 15, height: 1.5, color: Colors.black87),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context), 
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryStart, 
                foregroundColor: Colors.white, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: const Text("Continue Browsing"),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 3️⃣ INTERNAL DIALOG WIDGET (Stateful Logic)
// ===========================================================================
class _ProcessingDialog<T> extends StatefulWidget {
  final Future<T> Function(Function(String) updateStatus) asyncTask;
  final String initialMessage; 

  const _ProcessingDialog({required this.asyncTask, required this.initialMessage});
  
  @override
  State<_ProcessingDialog<T>> createState() => _ProcessingDialogState<T>();
}

class _ProcessingDialogState<T> extends State<_ProcessingDialog<T>> {
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.initialMessage; 
    debugPrint("🟢 [DIALOG UI] Initialized. Starting Task...");
    
    // Thora delay taake UI render ho jaye, phir task start ho
    Future.microtask(() => _startTask());
  }

  void _startTask() async {
    try {
      debugPrint("⚡ [DIALOG TASK] Executing Async Task...");

      // Task Run karo aur Status Update ka callback provide karo
      final result = await widget.asyncTask((newStatus) {
        if (mounted) {
          debugPrint("🔄 [DIALOG STATUS] Changed to: $newStatus");
          setState(() => _status = newStatus);
        }
      });
      
      // 🔥 SUCCESS HANDLING
      if (mounted) {
        debugPrint("✅ [DIALOG TASK] Completed. Finalizing UI...");
        
        setState(() => _status = "Finalizing...");
        
        // 1.5 Second ka wait taake user 'Success' feel kar sake (Jhatka na lage)
        await Future.delayed(const Duration(milliseconds: 1500));
        
        if (mounted) {
          debugPrint("🚪 [DIALOG UI] Popping with Success Result.");
          Navigator.pop(context, result);
        }
      }

    } catch (e) {
      debugPrint("❌ [DIALOG TASK FAILED] Exception: $e");
      
      // Error ko wrap karke wapis bhejo taake 'show' method usay throw kar sake
      if (mounted) {
        Navigator.pop(context, {'_error_wrapper_': e});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Glass Blur Effect
      child: PopScope(
        canPop: false, // 🔒 Back Button Blocked
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🌟 Animated Icon
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      // ✨ FIX: withOpacity -> withValues(alpha: 0.5)
                      color: AppColors.primaryStart.withValues(alpha: 0.5), 
                      blurRadius: 60, 
                      spreadRadius: 10
                    )
                  ],
                ),
                child: const Icon(Icons.auto_awesome, size: 50, color: AppColors.primaryStart)
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(duration: 1500.ms, color: Colors.purpleAccent)
                    .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1000.ms, curve: Curves.easeInOut)
                    .then()
                    .scale(begin: const Offset(1.1, 1.1), end: const Offset(1, 1), curve: Curves.easeInOut),
              ),
              
              const SizedBox(height: 40),
              
              // 📝 Dynamic Status Text (Animated Switcher for smoothness)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(animation),
                    child: child,
                  ));
                },
                child: Text(
                  _status,
                  key: ValueKey(_status), // Key zaroori hai text change animation ke liye
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white, 
                    fontSize: 24, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 1
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // ⏳ Loader Bar
              SizedBox(
                width: 150,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white24, 
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(10), 
                  minHeight: 4
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                "Please wait while AI works...", 
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)
              ),
            ],
          ),
        ),
      ),
    );
  }
}
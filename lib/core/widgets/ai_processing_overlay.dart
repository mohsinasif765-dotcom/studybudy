import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:studybudy_ai/core/theme/app_colors.dart';

class AIProcessingOverlay {
  // 🚀 Static method to show the overlay easily
  static Future<T?> show<T>({
    required BuildContext context,
    required Future<T> Function(Function(String) updateStatus) asyncTask,
  }) async {
    return showDialog<T>(
      context: context,
      barrierDismissible: false, // User close na kar sake
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => _ProcessingDialog(asyncTask: asyncTask),
    );
  }
}

class _ProcessingDialog<T> extends StatefulWidget {
  final Future<T> Function(Function(String) updateStatus) asyncTask;

  const _ProcessingDialog({required this.asyncTask});

  @override
  State<_ProcessingDialog<T>> createState() => _ProcessingDialogState<T>();
}

class _ProcessingDialogState<T> extends State<_ProcessingDialog<T>> {
  String _status = "Initializing...";

  @override
  void initState() {
    super.initState();
    _startTask();
  }

  void _startTask() async {
    try {
      // Task run karein aur result wapis karein
      final result = await widget.asyncTask((newStatus) {
        if (mounted) setState(() => _status = newStatus);
      });
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Error handle parent karega
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌫️ BLUR EFFECT
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✨ Animated AI Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryStart.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: const Icon(Icons.auto_awesome, size: 40, color: AppColors.primaryStart)
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: 2.seconds, color: Colors.purpleAccent),
            ),
            
            const SizedBox(height: 30),

            // 📝 Animated Status Text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
                  child: child,
                ));
              },
              child: Text(
                _status,
                key: ValueKey(_status), // Key change hone par animation chalegi
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 10),
            
            // Subtitle
            Text(
              "Please wait while we process your file...",
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
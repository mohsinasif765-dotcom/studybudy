import 'dart:async'; // 🔥 For Timeout handling
import 'dart:io'; // 🔥 For SocketException
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:prepvault_ai/features/quiz/models/quiz_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 👇 Custom Imports
import 'package:prepvault_ai/core/widgets/smart_banner_ad.dart';
import 'package:prepvault_ai/core/services/ad_service.dart';

class QuizResultScreen extends StatefulWidget {
  final int score;
  final int totalQuestions;
  final List<QuizQuestion> questions;
  final String? testTitle;

  const QuizResultScreen({
    super.key, 
    required this.score, 
    required this.totalQuestions, 
    required this.questions,
    this.testTitle,
  });

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    
    // 1. Pop-up Animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();

    // 2. 🔥 Save Result & Ad Logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _saveOrUpdateResult();
       
       // 3. 🔥 SMART AD CHECK: Sirf free user ko full screen ad dikhao
       if (AdService().isFreeUserNotifier.value) {
         try {
           AdService().showInterstitialAd(onAdClosed: () {});
         } catch (e) {
           debugPrint("Ad Error: $e");
         }
       }
    });
  }

  // 💾 SMART SAVE LOGIC
  Future<void> _saveOrUpdateResult() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final String title = widget.testTitle ?? "Practice Quiz";
    final int percentage = ((widget.score / widget.totalQuestions) * 100).toInt();

    try {
      final existingRecord = await _supabase
          .from('quiz_history')
          .select('id, score')
          .eq('user_id', userId)
          .eq('test_title', title)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (existingRecord != null) {
        await _supabase.from('quiz_history').update({
          'score': widget.score,
          'percentage': percentage,
          'created_at': DateTime.now().toIso8601String(), 
        }).eq('id', existingRecord['id']);
        debugPrint("🔄 Updated existing score for: $title");
      } else {
        await _supabase.from('quiz_history').insert({
          'user_id': userId,
          'test_title': title,
          'score': widget.score,
          'total_questions': widget.totalQuestions,
          'percentage': percentage,
        });
        debugPrint("✅ Saved new score for: $title");
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Progress Saved Successfully!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      debugPrint("❌ Error saving result: $e");
      
      if (mounted) {
        String message = "Progress not saved: Unknown Error";
        if (e.toString().contains("SocketException") || e.toString().contains("Network") || e is TimeoutException) {
          message = "⚠️ Internet nahi hai. Result database mein save nahi hua.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 🔄 RESTART LOGIC
  void _restartQuiz() {
    context.pushReplacement('/quiz-player', extra: widget.questions);
  }

  @override
  Widget build(BuildContext context) {
    double percentage = (widget.score / widget.totalQuestions) * 100;
    bool isPass = percentage >= 50;
    Color statusColor = isPass ? Colors.green : Colors.redAccent;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ✨ ANIMATED CARD
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 500),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // 1. HEADER ICON (Animated)
                            TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 1000),
                              curve: Curves.elasticOut,
                              builder: (context, double val, child) {
                                return Transform.scale(
                                  scale: val,
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isPass ? Icons.emoji_events_rounded : Icons.cancel_outlined,
                                      size: 60,
                                      color: statusColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            const SizedBox(height: 24),

                            // 2. TEXT STATUS
                            Text(
                              isPass ? "Congratulations!" : "Don't Give Up!",
                              style: GoogleFonts.outfit(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isPass 
                                ? "You have successfully passed the test." 
                                : "You need a bit more practice.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),

                            const SizedBox(height: 40),

                            // 3. CIRCULAR SCORE INDICATOR
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 180,
                                  height: 180,
                                  child: CircularProgressIndicator(
                                    value: 1.0, 
                                    strokeWidth: 15,
                                    color: Colors.grey.shade100,
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                                SizedBox(
                                  width: 180,
                                  height: 180,
                                  child: TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0, end: percentage / 100),
                                    duration: const Duration(seconds: 2),
                                    curve: Curves.easeOutQuart,
                                    builder: (context, double value, child) {
                                      return CircularProgressIndicator(
                                        value: value,
                                        strokeWidth: 15,
                                        color: statusColor,
                                        strokeCap: StrokeCap.round,
                                      );
                                    },
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TweenAnimationBuilder(
                                      tween: IntTween(begin: 0, end: widget.score),
                                      duration: const Duration(seconds: 2),
                                      curve: Curves.easeOut,
                                      builder: (context, int val, child) {
                                        return Text(
                                          "$val",
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 48,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        );
                                      },
                                    ),
                                    Text(
                                      "/ ${widget.totalQuestions}",
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),

                            const SizedBox(height: 40),

                            // 4. MAIN ACTION BUTTONS
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMainButton(
                                    label: "Home",
                                    icon: Icons.home_rounded,
                                    color: Colors.white,
                                    textColor: Colors.black87,
                                    borderColor: Colors.grey.shade300,
                                    onTap: () => context.go('/dashboard'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildMainButton(
                                    label: "Restart", 
                                    icon: Icons.refresh_rounded,
                                    color: AppColors.primaryStart,
                                    textColor: Colors.white,
                                    borderColor: Colors.transparent,
                                    onTap: _restartQuiz, 
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🔥 UPDATED: Smart Banner Ad at Bottom (Checking for Free User)
          ValueListenableBuilder<bool>(
            valueListenable: AdService().isFreeUserNotifier,
            builder: (context, isFree, child) {
              if (isFree) {
                return const SafeArea(
                  top: false,
                  child: SmartBannerAd(),
                );
              }
              return const SizedBox.shrink(); // Paid user ke liye gayab
            },
          ),
        ],
      ),
    );
  }

  // ✨ HELPER: Main Buttons (Restart / Home)
  Widget _buildMainButton({
    required String label, 
    required IconData icon, 
    required Color color, 
    required Color textColor,
    required Color borderColor,
    required VoidCallback onTap
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
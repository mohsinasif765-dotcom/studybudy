import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:prepvault_ai/features/quiz/models/quiz_model.dart';

// 👇 Imports for Ads
import 'package:prepvault_ai/core/widgets/smart_banner_ad.dart';
import 'package:prepvault_ai/core/services/ad_service.dart';

// ✅ NEW IMPORT (Neon Widget)
import 'package:prepvault_ai/core/widgets/neon_quiz_option.dart'; 

class QuizPlayScreen extends StatefulWidget {
  final List<QuizQuestion> questions;

  const QuizPlayScreen({super.key, required this.questions});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedOptionIndex;
  bool _isAnswered = false;
  bool _canPop = false; 

  @override
  void initState() {
    super.initState();
    // Interstitial load hoga, lekin AdService check karega ke user free hai ya nahi
    AdService().loadInterstitialAd();
  }

  void _handleAnswer(int optionIndex) {
    if (_isAnswered) return;

    setState(() {
      _selectedOptionIndex = optionIndex;
      _isAnswered = true;
      if (optionIndex == widget.questions[_currentIndex].correctAnswerIndex) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _isAnswered = false;
      });
    } else {
      // 🏁 QUIZ FINISHED
      setState(() => _canPop = true); 
      _showAdAndNavigate();
    }
  }

  void _showAdAndNavigate() {
    // Ye function khud check kar lega ke user paid hai ya free
    AdService().showInterstitialAd(
      onAdClosed: () {
        _navigateToResult();
      }
    );
  }

  void _navigateToResult() {
    if (!mounted) return;
    context.pushReplacement(
      '/quiz-result', 
      extra: {
        'score': _score,
        'totalQuestions': widget.questions.length,
        'questions': widget.questions,
      }
    );
  }

  Future<bool> _onWillPop() async {
    if (_canPop) return true;
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quit Quiz?'),
        content: const Text('Your progress will be lost.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentIndex];
    final progress = (_currentIndex + 1) / widget.questions.length;

    return PopScope(
      canPop: _canPop, 
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          setState(() => _canPop = true);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text(
            "Quiz Session", 
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.black87)
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black87),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                setState(() => _canPop = true);
                Navigator.of(context).pop();
              }
            },
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade300, 
              color: AppColors.primaryStart,
              minHeight: 6,
            ),
          ),
        ),
        
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      children: [
                        // --- HEADER INFO ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Question ${_currentIndex + 1}/${widget.questions.length}", 
                              style: GoogleFonts.outfit(color: Colors.black54, fontWeight: FontWeight.bold)
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryStart.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20)
                              ),
                              child: Text(
                                "Score: $_score", 
                                style: const TextStyle(color: AppColors.primaryStart, fontWeight: FontWeight.bold)
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // --- QUESTION TEXT ---
                        Text(
                          question.question,
                          style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        
                        // --- OPTIONS LIST ---
                        Expanded(
                          child: ListView.builder(
                            itemCount: question.options.length,
                            itemBuilder: (context, index) {
                              final bool isSelected = _selectedOptionIndex == index;
                              final bool isCorrect = index == question.correctAnswerIndex;

                              return NeonQuizOption(
                                text: question.options[index],
                                letter: ['A','B','C','D'][index],
                                isSelected: isSelected,
                                isAnswered: _isAnswered,
                                isCorrect: isCorrect,
                                onTap: () => _handleAnswer(index),
                              );
                            },
                          ),
                        ),

                        // --- EXPLANATION ---
                        if (_isAnswered) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lightbulb_outline, color: Colors.blue.shade800, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    question.explanation, 
                                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.blue.shade900),
                                    maxLines: 3, 
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // --- NEXT BUTTON ---
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _nextQuestion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryStart, 
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                            ),
                            child: Text(
                              _currentIndex == widget.questions.length - 1 ? "FINISH QUIZ" : "NEXT QUESTION",
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // 🔥 REACTIVE AD WIDGET: Sirf tab dikhega jab isFreeUserNotifier true ho
            ValueListenableBuilder<bool>(
              valueListenable: AdService().isFreeUserNotifier,
              builder: (context, isFreeUser, child) {
                if (!isFreeUser) {
                  return const SizedBox.shrink(); // Paid user ke liye bilkul gayab
                }
                return const SafeArea(
                  top: false, 
                  child: SmartBannerAd(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
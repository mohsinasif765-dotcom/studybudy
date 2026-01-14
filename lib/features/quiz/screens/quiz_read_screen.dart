import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepvault_ai/features/quiz/models/quiz_model.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';

// 👇 Imports for Ads
import 'package:prepvault_ai/core/widgets/smart_banner_ad.dart';
import 'package:prepvault_ai/core/services/ad_service.dart'; // 🔥 Import AdService

class QuizReadScreen extends StatelessWidget {
  final List<QuizQuestion> questions;

  const QuizReadScreen({super.key, required this.questions});

  @override
  Widget build(BuildContext context) {
    
    // 🔥 CRASH PROOF: Handle Empty Data Case
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Read Mode"), backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: Text("No questions to display")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Read Mode",
          textScaler: TextScaler.noScaling,
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey.shade50,
      
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: questions.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    final q = questions[index];
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05), // withOpacity is safer
                            blurRadius: 10
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Question Text ---
                          Text(
                            "Q${index + 1}. ${q.question}",
                            textScaler: TextScaler.noScaling,
                            style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 16),
                          
                          // --- Options List ---
                          ...List.generate(q.options.length, (optIdx) {
                            final isCorrect = optIdx == q.correctAnswerIndex;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isCorrect ? Colors.green.shade50 : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCorrect ? Colors.green : Colors.grey.shade300,
                                  width: isCorrect ? 2 : 1
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isCorrect ? Icons.check_circle : Icons.circle_outlined,
                                    color: isCorrect ? Colors.green : Colors.black45,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      q.options[optIdx],
                                      textScaler: TextScaler.noScaling,
                                      style: TextStyle(
                                        fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                        color: isCorrect ? Colors.green.shade900 : Colors.black87
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          // --- Explanation ---
                          if (q.explanation.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.05), 
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.lightbulb_outline, size: 16, color: Colors.black54),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Explanation: ${q.explanation}",
                                      textScaler: TextScaler.noScaling,
                                      style: GoogleFonts.outfit(color: Colors.black54, fontSize: 13, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 🔥 FIXED AD LOGIC: Sirf free users ke liye dikhayega
          ValueListenableBuilder<bool>(
            valueListenable: AdService().isFreeUserNotifier,
            builder: (context, isFree, child) {
              if (!isFree) return const SizedBox.shrink(); // VIP ke liye gap khatam

              return const SafeArea(
                top: false,
                child: SmartBannerAd(),
              );
            },
          ),
        ],
      ),
    );
  }
}
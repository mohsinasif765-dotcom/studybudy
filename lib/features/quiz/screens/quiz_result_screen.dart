import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:studybudy_ai/core/theme/app_colors.dart';
import 'package:studybudy_ai/features/quiz/models/quiz_model.dart';
// 👇 Naye PDF Service ko import kiya
import 'package:studybudy_ai/core/services/pdf_service.dart';

class QuizResultScreen extends StatelessWidget {
  final int score;
  final int totalQuestions;
  final List<QuizQuestion> questions;

  const QuizResultScreen({
    super.key, 
    required this.score, 
    required this.totalQuestions, 
    required this.questions
  });

  @override
  Widget build(BuildContext context) {
    double percentage = (score / totalQuestions) * 100;
    
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- Score Animation ---
              const Icon(Icons.emoji_events, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text("Quiz Completed!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("$score / $totalQuestions", style: const TextStyle(fontSize: 20, color: Colors.grey)),
              Text("${percentage.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.primaryStart)),
              
              const SizedBox(height: 50),
              
              // --- ACTION BUTTONS (Wrap use kiya taake mobile/web dono pe fit ho) ---
              Wrap(
                spacing: 16, // Horizontal gap
                runSpacing: 16, // Vertical gap
                alignment: WrapAlignment.center,
                children: [
                  // 1. Home Button
                  OutlinedButton.icon(
                    onPressed: () => context.go('/dashboard'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    icon: const Icon(Icons.home),
                    label: const Text("Home"),
                  ),

                  // 2. Download Report (Student Result)
                  ElevatedButton.icon(
                    onPressed: () => PdfService.generateQuizReport(questions, score, totalQuestions),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent, 
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    icon: const Icon(Icons.assessment),
                    label: const Text("Download Report"),
                  ),

                  // 3. Export Blank Exam (Teacher Mode)
                  ElevatedButton.icon(
                    onPressed: () => PdfService.generateExamPaper(questions, "AI Generated Quiz"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87, 
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    icon: const Icon(Icons.print),
                    label: const Text("Export Exam Paper"),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
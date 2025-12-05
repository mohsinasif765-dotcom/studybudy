import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybudy_ai/core/theme/app_colors.dart';
import 'package:studybudy_ai/features/quiz/models/quiz_model.dart';
import 'package:studybudy_ai/features/quiz/services/quiz_service.dart';
import 'quiz_play_screen.dart';
import 'package:studybudy_ai/features/subscription/widgets/pricing_modal.dart';

class QuizSetupScreen extends StatefulWidget {
  final String fileContent;
  
  const QuizSetupScreen({super.key, required this.fileContent});

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  String _difficulty = 'Medium';
  double _questionCount = 10; // Default
  bool _isLoading = false;
  final TextEditingController _topicController = TextEditingController();

  Future<void> _startQuiz() async {
    setState(() => _isLoading = true);
    try {
      final int requestedCount = _questionCount.toInt();

      final config = QuizConfig(
        difficulty: _difficulty,
        topic: _topicController.text.isEmpty ? 'General' : _topicController.text,
        count: requestedCount,
        fileContent: widget.fileContent,
      );

      // AI se questions mangwao
      final questions = await QuizService().generateQuiz(config);

      if (!mounted) return;

      // 🔍 SMART CHECK: Kya AI ne kam sawal banaye?
      // Agar generated questions requested se 20% kam hain (e.g. asked 50, got 30)
      if (questions.length < requestedCount && questions.isNotEmpty) {
        // User ko batao k content kam tha
        _showLowContentDialog(questions, requestedCount);
      } else {
        // Sab theek hai, start karo
        _navigateToPlay(questions);
      }

    } catch (e) {
      if (mounted) {
        if (e == 'LOW_CREDITS') {
          showDialog(
            context: context,
            builder: (c) => const PricingModal(currentPlanId: 'free'),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🚶 Navigation Logic
  void _navigateToPlay(List<QuizQuestion> questions) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizPlayScreen(questions: questions),
      ),
    );
  }

  // 🔔 SMART DIALOG (Agar sawal kam milein)
  void _showLowContentDialog(List<QuizQuestion> questions, int requested) {
    showDialog(
      context: context,
      barrierDismissible: false, // User ko OK dabana hi padega
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 10),
            Text("Quality Over Quantity"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "You asked for $requested questions, but we generated ${questions.length}.",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Reason: The provided text was concise. To ensure the quiz remains high-quality and free of repetition, we avoided creating duplicate questions.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Cancel
            child: const Text("Go Back"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Dialog band karo
              _navigateToPlay(questions); // Quiz shuru karo
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryStart, foregroundColor: Colors.white),
            child: Text("Start Quiz (${questions.length})"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configure Quiz"), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Select Difficulty", style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Easy', label: Text('Easy')),
                ButtonSegment(value: 'Medium', label: Text('Medium')),
                ButtonSegment(value: 'Hard', label: Text('Hard')),
              ],
              selected: {_difficulty},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() => _difficulty = newSelection.first);
              },
            ),
            
            const SizedBox(height: 30),
            
            // 👇 UPDATED SLIDER (MAX 50)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Number of Questions", style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primaryStart.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text("${_questionCount.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryStart)),
                )
              ],
            ),
            Slider(
              value: _questionCount,
              min: 5,
              max: 50, // 👈 30 se 50 kar diya
              divisions: 9, // 5, 10, 15... 50
              activeColor: AppColors.primaryStart,
              label: _questionCount.toInt().toString(),
              onChanged: (value) => setState(() => _questionCount = value),
            ),
            const Text(
              "Note: Higher counts require more detailed documents.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),

            const SizedBox(height: 30),
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: "Specific Topic (Optional)",
                hintText: "e.g. Organic Chemistry",
                prefixIcon: Icon(Icons.topic),
              ),
            ),

            const Spacer(),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startQuiz,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryStart,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("GENERATE & START QUIZ"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
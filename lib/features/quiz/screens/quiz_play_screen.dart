import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybudy_ai/core/theme/app_colors.dart';
import 'package:studybudy_ai/features/quiz/models/quiz_model.dart';
import 'quiz_result_screen.dart'; // Iske baad hum ye file banayenge

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
      // Quiz Khatam -> Result Screen par jao
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuizResultScreen(
            score: _score,
            totalQuestions: widget.questions.length,
            questions: widget.questions,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text("Question ${_currentIndex + 1}/${widget.questions.length}"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / widget.questions.length,
              backgroundColor: Colors.grey.shade200,
              color: AppColors.primaryStart,
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 30),
            Text(
              question.question,
              style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView.separated(
                itemCount: question.options.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildOptionCard(index, question);
                },
              ),
            ),
            if (_isAnswered)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.blue),
                    const SizedBox(width: 10),
                    Expanded(child: Text(question.explanation, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            if (_isAnswered)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryStart, 
                    foregroundColor: Colors.white
                  ),
                  child: Text(_currentIndex == widget.questions.length - 1 ? "FINISH QUIZ" : "NEXT QUESTION"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(int index, QuizQuestion question) {
    Color borderColor = Colors.grey.shade300;
    Color bgColor = Colors.white;
    IconData? icon;

    if (_isAnswered) {
      if (index == question.correctAnswerIndex) {
        borderColor = Colors.green;
        bgColor = Colors.green.withValues(alpha: 0.1);
        icon = Icons.check_circle;
      } else if (index == _selectedOptionIndex) {
        borderColor = Colors.red;
        bgColor = Colors.red.withValues(alpha: 0.1);
        icon = Icons.cancel;
      }
    } else if (_selectedOptionIndex == index) {
      borderColor = AppColors.primaryStart;
    }

    return GestureDetector(
      onTap: () => _handleAnswer(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                question.options[index],
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            if (icon != null) Icon(icon, color: borderColor),
          ],
        ),
      ),
    );
  }
}
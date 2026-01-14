import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepvault_ai/features/quiz/models/quiz_model.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';

// 👇 1. Import Smart Banner Ad & Ad Service
import 'package:prepvault_ai/core/widgets/smart_banner_ad.dart';
import 'package:prepvault_ai/core/services/ad_service.dart'; // 🔥 IMPORT ADDED

class QuestionSetReadScreen extends StatefulWidget {
  final List<QuizQuestion> questions;
  final String title; 

  const QuestionSetReadScreen({
    super.key, 
    required this.questions,
    this.title = "Read Mode", 
  });

  @override
  State<QuestionSetReadScreen> createState() => _QuestionSetReadScreenState();
}

class _QuestionSetReadScreenState extends State<QuestionSetReadScreen> {
  
  // ===========================================================================
  // 1️⃣ STATE MANAGEMENT
  // ===========================================================================
  final Set<int> _revealedAnswers = {};

  @override
  void initState() {
    super.initState();
    debugPrint("🟢 [QSET_READ] Screen Initialized. Questions: ${widget.questions.length}");
  }

  @override
  void dispose() {
    debugPrint("👋 [QSET_READ] Screen Disposed");
    super.dispose();
  }

  void _toggleAnswer(int index) {
    setState(() {
      if (_revealedAnswers.contains(index)) {
        _revealedAnswers.remove(index);
      } else {
        _revealedAnswers.add(index);
      }
    });
  }

  // ===========================================================================
  // 2️⃣ UI BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      
      appBar: AppBar(
        title: Text(
          widget.title, 
          textScaler: TextScaler.noScaling, 
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.black87)
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      
      // 🔥 2. Layout Update: Column -> Expanded -> Banner
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: widget.questions.isEmpty 
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: widget.questions.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 20),
                      itemBuilder: (context, index) {
                        return _buildQuestionCard(index, widget.questions[index]);
                      },
                    ),
              ),
            ),
          ),

          // 🔥 3. SMART BANNER AD (VIP LOGIC ADDED)
          // Sirf Free User ko dikhao
          ValueListenableBuilder<bool>(
            valueListenable: AdService().isFreeUserNotifier, // ✅ Correct Instance Access
            builder: (context, isFreeUser, child) {
              if (!isFreeUser) return const SizedBox.shrink(); // 🛑 VIPs k liye Hide
              
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

  // ===========================================================================
  // 3️⃣ HELPER WIDGETS
  // ===========================================================================

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.menu_book, size: 60, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(
          "No questions to display.", 
          textScaler: TextScaler.noScaling,
          style: GoogleFonts.outfit(color: Colors.black54, fontSize: 16)
        ),
      ],
    );
  }

  Widget _buildQuestionCard(int index, QuizQuestion q) {
    final isRevealed = _revealedAnswers.contains(index);
    final marks = q.marks ?? 5; 

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // ✅ Safe Shadow
        boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          // --- HEADER: Q# & MARKS ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  // ✅ Safe Color Opacity
                  color: AppColors.primaryStart.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Question ${index + 1}",
                  textScaler: TextScaler.noScaling, 
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.primaryStart, fontSize: 12),
                ),
              ),
              Text(
                "[$marks Marks]",
                textScaler: TextScaler.noScaling,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // --- QUESTION TEXT ---
          Text(
            q.question,
            textScaler: TextScaler.noScaling,
            style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, height: 1.4, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          
          // --- ANSWER SECTION (THEORY LOGIC) ---
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: double.infinity,
            padding: isRevealed ? const EdgeInsets.all(16) : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: isRevealed ? const Color(0xFFE0F2F1) : Colors.transparent, // Teal Tint
              borderRadius: BorderRadius.circular(12),
              border: isRevealed ? Border.all(color: Colors.teal.shade200) : null,
            ),
            child: isRevealed
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 18, color: Colors.teal),
                          const SizedBox(width: 8),
                          Text(
                            "Model Answer",
                            textScaler: TextScaler.noScaling,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.teal.shade800, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 🔥 Display Theory Answer (Fallback to Explanation if Answer is null)
                      Text(
                        q.answer ?? q.explanation, 
                        textScaler: TextScaler.noScaling,
                        style: GoogleFonts.outfit(fontSize: 15, color: Colors.teal.shade900, height: 1.5),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _toggleAnswer(index),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text("Show Answer", textScaler: TextScaler.noScaling),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryStart,
                        elevation: 0,
                        side: const BorderSide(color: AppColors.primaryStart),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
          ),

          // --- HIDE BUTTON (Only when visible) ---
          if (isRevealed)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: GestureDetector(
                onTap: () => _toggleAnswer(index),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.visibility_off_outlined, size: 14, color: Colors.black54),
                    const SizedBox(width: 6),
                    Text(
                      "Hide Answer", 
                      textScaler: TextScaler.noScaling,
                      style: GoogleFonts.outfit(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}
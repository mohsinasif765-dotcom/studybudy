import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybudy_ai/core/theme/app_colors.dart';

class SelectionModal extends StatelessWidget {
  final String source; // 'upload' or 'camera'
  // Added fileContent to pass actual extracted text if available
  final String fileContent; 

  const SelectionModal({
    super.key, 
    required this.source,
    this.fileContent = '', // Default empty if not passed
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      // 👇 Overflow error se bachne ke liye Scrollable banaya
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Handle Bar (UI Design)
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 2. Title & Subtitle
            Text(
              "What would you like to do?",
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Choose an action for your ${source == 'camera' ? 'scan' : 'file'}.",
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),

            // 3. Options List
            
            // --- OPTION A: GENERATE SUMMARY ---
            _buildOption(
              context,
              title: "Generate Summary",
              subtitle: "Get concise notes & key points",
              icon: Icons.auto_awesome,
              color: const Color(0xFF6366F1), // Indigo Color
              onTap: () {
                Navigator.pop(context); // Modal band karo
                
                // 👇 Go to Summary Screen
                // Passing the actual fileContent if available, otherwise dummy text for testing
                final contentToPass = fileContent.isNotEmpty ? fileContent : """
Artificial Intelligence (AI) is intelligence demonstrated by machines, as opposed to the natural intelligence displayed by humans or animals. Leading AI textbooks define the field as the study of "intelligent agents": any system that perceives its environment and takes actions that maximize its chance of achieving its goals.

Some popular accounts use the term "artificial intelligence" to describe machines that mimic "cognitive" functions that humans associate with the human mind, such as "learning" and "problem solving", however, this definition is rejected by major AI researchers.

AI applications include advanced web search engines (e.g., Google), recommendation systems (used by YouTube, Amazon and Netflix), understanding human speech (such as Siri and Alexa), self-driving cars (e.g., Tesla), automated decision-making and competing at the highest level in strategic game systems (such as chess and Go).
                  """;

                context.push(
                  '/summary', 
                  extra: contentToPass
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // --- OPTION B: GENERATE QUIZ ---
            _buildOption(
              context,
              title: "Generate Quiz",
              subtitle: "Test your knowledge with MCQs",
              icon: Icons.quiz_rounded,
              color: const Color(0xFFEC4899), // Pink Color
              onTap: () {
                Navigator.pop(context); // Modal band karo
                
                // 👇 Go to Quiz Setup Screen
                final contentToPass = fileContent.isNotEmpty ? fileContent : "Photosynthesis is the process by which green plants and some other organisms use sunlight to synthesize foods with the help of chlorophyll pigments.";
                
                context.push(
                  '/quiz-setup', 
                  extra: contentToPass
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Helper Widget taake code clean rahe
  Widget _buildOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            // Icon Circle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            
            // Texts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            
            // Arrow Icon
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
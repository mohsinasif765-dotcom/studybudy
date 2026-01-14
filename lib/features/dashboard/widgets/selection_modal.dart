import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';

class SelectionModal extends StatelessWidget {
  final String source; // 'upload' or 'camera'
  final String fileContent;

  const SelectionModal({
    super.key,
    required this.source,
    this.fileContent = '',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 2. Title
              Text(
                "What would you like to do?",
                textScaleFactor: 1.0,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              
              // 🔥 UPDATED: Subtitle color changed from Grey to Black
              Text(
                "Choose an action for your content.",
                textScaleFactor: 1.0,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  // Agar Dark mode hai to light grey, nahi to Black
                  color: isDark ? Colors.grey.shade300 : Colors.black87, 
                ),
              ),
              const SizedBox(height: 32),

              // 3. AVAILABLE OPTIONS
              
              // --- GENERATE SUMMARY ---
              _buildOption(
                context,
                title: "Generate Summary",
                subtitle: "Get concise notes & key points",
                icon: Icons.auto_awesome,
                color: const Color(0xFF6366F1), // Indigo
                onTap: () {
                  Navigator.pop(context);
                  final contentToPass = fileContent.isNotEmpty ? fileContent : "Dummy Text...";
                  context.push('/summary', extra: contentToPass);
                },
              ),
              
              const SizedBox(height: 16),
              
              // --- GENERATE QUIZ ---
              _buildOption(
                context,
                title: "Generate Quiz",
                subtitle: "Test your knowledge with MCQs",
                icon: Icons.quiz_rounded,
                color: const Color(0xFFEC4899), // Pink
                onTap: () {
                  Navigator.pop(context);
                  final contentToPass = fileContent.isNotEmpty ? fileContent : "Dummy Text...";
                  context.push('/quiz-setup', extra: contentToPass);
                },
              ),

              const SizedBox(height: 24),
              
              // --- DIVIDER FOR COMING SOON ---
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      "COMING SOON",
                      textScaleFactor: 1.0,
                      style: GoogleFonts.outfit(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold, 
                        // 🔥 UPDATED: Thora dark kiya taake saaf dikhe
                        color: isDark ? Colors.grey.shade400 : Colors.black54
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),

              // 4. COMING SOON OPTIONS
              
              // --- WEBSITE LINK ---
              _buildOption(
                context,
                title: "Website Link",
                subtitle: "Summarize articles from URL",
                icon: Icons.link_rounded,
                color: Colors.blue,
                isComingSoon: true,
                onTap: () {},
              ),
              const SizedBox(height: 16),

              // --- AUDIO ---
              _buildOption(
                context,
                title: "Audio Processing",
                subtitle: "Transcribe recordings & lectures",
                icon: Icons.mic_rounded,
                color: Colors.orange,
                isComingSoon: true,
                onTap: () {},
              ),
              const SizedBox(height: 16),

              // --- VIDEO ---
              _buildOption(
                context,
                title: "Video Analysis",
                subtitle: "Extract insights from videos",
                icon: Icons.videocam_rounded,
                color: Colors.red,
                isComingSoon: true,
                onTap: () {},
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // 👇 Updated Helper Widget
  Widget _buildOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isComingSoon = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: isComingSoon ? null : onTap,
      child: Opacity(
        opacity: isComingSoon ? 0.6 : 1.0, // Thora opacity badhaya taake text dikhe
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
                  color: isComingSoon ? Colors.grey.withOpacity(0.2) : color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: isComingSoon ? Colors.black54 : color, size: 24),
              ),
              const SizedBox(width: 16),
              
              // Texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          textScaleFactor: 1.0,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            // 🔥 UPDATED: Title Black
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        if (isComingSoon) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "SOON",
                              textScaleFactor: 1.0,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87, // Badge text black
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                    Text(
                      subtitle,
                      textScaleFactor: 1.0,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        // 🔥 UPDATED: Subtitle Grey se Black kar diya
                        color: isDark ? Colors.grey.shade400 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow or Lock Icon
              Icon(
                isComingSoon ? Icons.lock_outline_rounded : Icons.arrow_forward_ios_rounded,
                size: isComingSoon ? 20 : 16,
                color: isDark ? Colors.grey : Colors.black54, // Icon thora dark
              ),
            ],
          ),
        ),
      ),
    );
  }
}
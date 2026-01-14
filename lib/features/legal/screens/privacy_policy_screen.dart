import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart'; // Ensure path is correct

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader("Last Updated: January 1, 2024"),
            const SizedBox(height: 20),
            
            _buildParagraph(
              "PrepVault AI values your privacy deeply. This policy outlines how we collect, use, and protect your data when you use our services."
            ),

            _buildSectionTitle("1. Data Collection"),
            _buildParagraph("We only collect data necessary to operate the Service effectively:"),
            _buildBulletPoint("User Authentication: Email and User ID to secure your account and track credits."),
            _buildBulletPoint("Study History: Summaries and Quizzes are saved to allow you to revisit sessions."),
            _buildBulletPoint("Uploaded Content: PDFs/Images are used solely for AI analysis and are not permanently stored for training."),
            _buildBulletPoint("Usage Data: We track which AI features are used to optimize app performance."),

            _buildSectionTitle("2. Data Usage & Processing"),
            _buildParagraph("Your data is used strictly to provide and improve the Service:"),
            _buildBulletPoint("Credit Deduction: We process usage data to deduct credits when AI features are used."),
            _buildBulletPoint("AI Processing: Your content is sent to Google Gemini (or selected AI providers) for analysis only. It is NOT used to train their models."),
            _buildBulletPoint("No Selling: We do not sell your personal data or study history to third parties."),

            _buildSectionTitle("3. Third-Party Disclosure"),
            _buildParagraph("Our Service relies on the following trusted platforms:"),
            _buildBulletPoint("Supabase: For secure authentication and database hosting."),
            _buildBulletPoint("Google Gemini / OpenAI: For AI analysis and content generation."),
            _buildBulletPoint("Stripe / Payment Gateway: For secure payment processing."),

            _buildSectionTitle("4. Security"),
            _buildParagraph(
              "We employ industry-standard security measures, including Row Level Security (RLS) and encryption, to protect your data from unauthorized access."
            ),

            _buildSectionTitle("5. Contact Us"),
            _buildParagraph(
              "If you have any questions regarding privacy, please contact us via the 'Help & Support' section in the app."
            ),
            
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            _buildLinkText("Official Policy: https://sites.google.com/view/studybudy-ai/home"),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets for Clean Code ---

  Widget _buildHeader(String text) {
    return Text(text, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14));
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryStart,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.outfit(fontSize: 15, color: Colors.black87, height: 1.5),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(fontSize: 15, color: Colors.black87, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLinkText(String text) {
    return SelectableText(
      text,
      style: GoogleFonts.outfit(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline),
    );
  }
}
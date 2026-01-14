import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Terms & Conditions',
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
            _buildHeader("Effective Date: January 1, 2024"),
            const SizedBox(height: 20),

            _buildParagraph(
              "Please read these Terms of Service carefully before using the PrepVault AI Service. By using the app, you agree to be bound by these terms."
            ),

            _buildSectionTitle("1. User Obligations"),
            _buildBulletPoint("Prohibited Content: You agree not to upload illegal, harmful, or privacy-violating content."),
            _buildBulletPoint("Account Security: You are responsible for maintaining the security of your login credentials."),

            _buildSectionTitle("2. Credits & Subscriptions"),
            _buildBulletPoint("Credits: Credits are digital units required to utilize AI features. They are non-refundable."),
            _buildBulletPoint("Subscription: Plans may renew automatically via our payment provider. You may cancel your subscription at any time."),

            // --- IMPORTANT DISCLAIMER ---
            Container(
              margin: const EdgeInsets.symmetric(vertical: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text("3. AI Disclaimer", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "AI-generated content (Summaries, Quizzes) may not be 100% accurate. PrepVault AI does not guarantee the correctness of the output. Always verify information from your original source material. We are not liable for errors in AI generation.",
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),
            // ---------------------------

            _buildSectionTitle("4. Termination"),
            _buildParagraph(
              "We reserve the right to suspend or terminate your account if these Terms are violated."
            ),

            _buildSectionTitle("5. Governing Law"),
            _buildParagraph(
              "These Terms are governed by the laws of Pakistan."
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            _buildLinkText("Official Terms: https://sites.google.com/view/studybudy-ai/terms-conditions"),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Reuse similar helper widgets ---
  // (You can technically move these to a separate 'LegalWidgets' file to avoid code duplication, 
  // but for simplicity, I'm repeating the method structure here).

  Widget _buildHeader(String text) => Text(text, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14));

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(text, style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryStart)),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: GoogleFonts.outfit(fontSize: 15, color: Colors.black87, height: 1.5)),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 6, color: Colors.grey)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: GoogleFonts.outfit(fontSize: 15, color: Colors.black87, height: 1.5))),
        ],
      ),
    );
  }

  Widget _buildLinkText(String text) {
    return SelectableText(text, style: GoogleFonts.outfit(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline));
  }
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybudy_ai/core/theme/app_colors.dart';
import 'package:studybudy_ai/core/widgets/cyber_button.dart';
import 'package:studybudy_ai/features/auth/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleReset() async {
    if (_emailController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _authService.resetPassword(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.green, content: Text("Password reset link sent to your email!")),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // 🎨 LEFT SIDE (Desktop)
          if (isDesktop)
            Expanded(
              flex: 1,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryStart, AppColors.primaryEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(top: -50, left: -50, child: _buildCircle(200)),
                    Positioned(bottom: -50, right: -50, child: _buildCircle(300)),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2)
                            ),
                            child: const Icon(Icons.lock_reset, size: 80, color: Colors.white),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            "Recover Account",
                            style: GoogleFonts.spaceGrotesk(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "We will help you get back on track.",
                            style: GoogleFonts.outfit(fontSize: 18, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 📝 RIGHT SIDE: RESET FORM
          Expanded(
            flex: 1,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!isDesktop) ...[
                        const Center(child: Icon(Icons.lock_reset, size: 60, color: AppColors.primaryStart)),
                        const SizedBox(height: 20),
                      ],

                      Text(
                        "Forgot Password?",
                        style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 8),
                      Text("Enter your email and we'll send you a link to reset your password.", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16)),
                      
                      const SizedBox(height: 40),

                      _buildTextField(controller: _emailController, label: "Email Address", icon: Icons.email_outlined),

                      const SizedBox(height: 30),

                      CyberButton(
                        text: "SEND RESET LINK",
                        isLoading: _isLoading,
                        onPressed: _handleReset,
                      ),

                      const SizedBox(height: 30),

                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text("Back to Login", style: TextStyle(color: AppColors.primaryStart, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helpers
  Widget _buildCircle(double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: AppColors.primaryStart),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryStart, width: 2)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
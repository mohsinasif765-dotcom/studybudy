import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:prepvault_ai/core/widgets/cyber_button.dart';
import 'package:prepvault_ai/features/auth/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  // ---------------------------------------------------------------------------
  // 🧹 SMART ERROR CLEANER
  // ---------------------------------------------------------------------------
  String _getCleanErrorMessage(String rawError) {
    final error = rawError.toLowerCase();
    if (error.contains("user not found") || error.contains("invalid email")) {
      return "We couldn't find an account with that email.";
    }
    if (error.contains("too many requests") || error.contains("rate limit")) {
      return "Too many attempts. Please wait a while before trying again.";
    }
    if (error.contains("network") || error.contains("connection")) {
      return "Network error. Please check your internet connection.";
    }
    return "Something went wrong. Please try again.";
  }

  Future<void> _handleReset() async {
    if (_emailController.text.trim().isEmpty) {
      _showSnack("Please enter your email address", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      await _authService.resetPassword(_emailController.text.trim());
      
      if (mounted) {
        _showSnack("Reset link sent! Check your email inbox.", Colors.green);
        await Future.delayed(const Duration(seconds: 2));
        if(mounted) context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = _getCleanErrorMessage(e.toString());
        _showSnack(cleanMsg, Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              
              // 1. LOGO & ICON
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryStart.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset_rounded, size: 60, color: AppColors.primaryStart),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                "Forgot Password?",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.black87
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Don't worry! Enter your email and we'll send you a reset link.",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 16),
              ),
              
              const SizedBox(height: 40),

              // 2. INPUT FIELD
              _buildTextField(
                controller: _emailController,
                label: "Email Address",
                icon: Icons.email_outlined,
              ),

              const SizedBox(height: 30),

              // 3. ACTION BUTTON
              SizedBox(
                width: double.infinity,
                child: CyberButton(
                  text: "SEND RESET LINK",
                  isLoading: _isLoading,
                  onPressed: _handleReset,
                ),
              ),

              const SizedBox(height: 30),

              // Back to Login
              TextButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.arrow_back, size: 18, color: Colors.grey),
                label: Text(
                  "Back to Login",
                  style: GoogleFonts.outfit(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.outfit(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: AppColors.primaryStart),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300), 
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryStart, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ Supabase Import Zaroori hai
import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:prepvault_ai/core/widgets/cyber_button.dart';
import 'package:prepvault_ai/features/auth/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;

  // ---------------------------------------------------------------------------
  // 🧹 SMART ERROR CLEANER
  // ---------------------------------------------------------------------------
  String _getCleanErrorMessage(String rawError) {
    final error = rawError.toLowerCase();
    if (error.contains("invalid login credentials") || error.contains("invalid_grant")) {
      return "Incorrect email or password. Please try again.";
    }
    if (error.contains("email not confirmed")) {
      return "Please verify your email address before logging in.";
    }
    if (error.contains("network") || error.contains("connection")) {
      return "Network error. Please check your internet connection.";
    }
    return "Login failed. Please check your details.";
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showSnack("Please enter both email and password", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Auth Login
      await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      if (mounted) {
        _showSnack("Welcome Back! 👋", Colors.green);
        
        // ---------------------------------------------------------
        // 🔥 NEW: Check Subscription Plan from Supabase Profile
        // ---------------------------------------------------------
        final userId = Supabase.instance.client.auth.currentUser?.id;
        
        if (userId != null) {
          final profileData = await Supabase.instance.client
              .from('profiles')
              .select('plan_id, is_vip') // Plan aur VIP status dono check kar rahe hain
              .eq('id', userId)
              .single();

          final String planId = profileData['plan_id'] ?? 'free';
          final bool isVip = profileData['is_vip'] ?? false;

          if (mounted) {
            // 🛑 LOGIC: Agar Plan 'free' hai aur Banda VIP bhi nahi hai -> Paywall dikhao
            if (planId == 'free' && !isVip) {
               context.go('/subscription'); 
            } else {
               // ✅ Agar Plan Paid hai -> Dashboard jao
               context.go('/dashboard');
            }
          }
        }
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
              
              // 1. LOGO & BRANDING
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryStart.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_rounded, size: 60, color: AppColors.primaryStart),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                "Welcome Back!",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.black87
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Log in to continue your learning journey.",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 16),
              ),
              
              const SizedBox(height: 40),

              // 2. INPUT FIELDS
              _buildTextField(
                controller: _emailController,
                label: "Email Address",
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 20),

              _buildTextField(
                controller: _passwordController,
                label: "Password",
                icon: Icons.lock_outline,
                isPassword: true,
              ),

              // Forgot Password Link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: Text("Forgot Password?", style: GoogleFonts.outfit(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 24),

              // 3. ACTIONS
              SizedBox(
                width: double.infinity,
                height: 55,
                child: CyberButton( 
                  text: "LOG IN",
                  isLoading: _isLoading,
                  onPressed: _handleLogin,
                ),
              ),

              const SizedBox(height: 30),

              // Sign Up Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ", style: GoogleFonts.outfit(color: Colors.grey.shade600)),
                  GestureDetector(
                    onTap: () => context.push('/signup'),
                    child: Text(
                      "Sign Up",
                      style: GoogleFonts.outfit(color: AppColors.primaryStart, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
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
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: GoogleFonts.outfit(
        color: Colors.black87, 
        fontSize: 16, 
        fontWeight: FontWeight.w500
      ),
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
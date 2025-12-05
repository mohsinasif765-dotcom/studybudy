import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybudy_ai/core/theme/app_colors.dart';
import 'package:studybudy_ai/core/widgets/cyber_button.dart';
import 'package:studybudy_ai/features/auth/services/auth_service.dart';

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

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Failed: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 📏 Screen Width Check
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // ---------------------------------------------
          // 🎨 LEFT SIDE: BRANDING (Only visible on Desktop)
          // ---------------------------------------------
          if (isDesktop)
            Expanded(
              flex: 1, // 50% width
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
                    // Background Pattern (Circles)
                    Positioned(top: -50, left: -50, child: _buildCircle(200)),
                    Positioned(bottom: -50, right: -50, child: _buildCircle(300)),
                    
                    // Center Content
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
                            child: const Icon(Icons.auto_awesome, size: 80, color: Colors.white),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            "StudyBuddy AI",
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 40, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.white
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Master your studies with the power of AI.",
                            style: GoogleFonts.outfit(
                              fontSize: 18, 
                              color: Colors.white70
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ---------------------------------------------
          // 📝 RIGHT SIDE: LOGIN FORM
          // ---------------------------------------------
          Expanded(
            flex: 1,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450), // Form ki width fix rakho
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Mobile Logo (Only if NOT desktop)
                      if (!isDesktop) ...[
                        const Center(child: Icon(Icons.auto_awesome, size: 60, color: AppColors.primaryStart)),
                        const SizedBox(height: 20),
                      ],

                      Text(
                        "Welcome Back! 👋",
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 32, 
                          fontWeight: FontWeight.bold, 
                          color: AppColors.textDark
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Enter your credentials to access your account.",
                        style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16),
                      ),
                      
                      const SizedBox(height: 40),

                      // Email
                      _buildTextField(
                        controller: _emailController,
                        label: "Email Address",
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 20),

                      // Password
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
                          child: const Text("Forgot Password?", style: TextStyle(color: Colors.grey)),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Login Button
                      CyberButton(
                        text: "LOG IN",
                        isLoading: _isLoading,
                        onPressed: _handleLogin,
                      ),

                      const SizedBox(height: 30),

                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account? ", style: TextStyle(color: Colors.grey)),
                          GestureDetector(
                            onTap: () => context.push('/signup'),
                            child: const Text(
                              "Sign Up",
                              style: TextStyle(color: AppColors.primaryStart, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
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

  // --- Helper Widgets ---

  Widget _buildCircle(double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: AppColors.primaryStart),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryStart, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
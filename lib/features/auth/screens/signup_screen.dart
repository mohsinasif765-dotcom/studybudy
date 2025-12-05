import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybudy_ai/core/theme/app_colors.dart';
import 'package:studybudy_ai/core/widgets/cyber_button.dart';
import 'package:studybudy_ai/features/auth/services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleSignup() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account Created! Please check email to confirm."), backgroundColor: Colors.green),
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
          // 🎨 LEFT SIDE: BRANDING (Desktop Only)
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
                            child: const Icon(Icons.rocket_launch, size: 80, color: Colors.white),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            "Join the Future",
                            style: GoogleFonts.spaceGrotesk(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Create an account to start your AI learning journey.",
                            style: GoogleFonts.outfit(fontSize: 18, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 📝 RIGHT SIDE: SIGNUP FORM
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
                        const Center(child: Icon(Icons.auto_awesome, size: 60, color: AppColors.primaryStart)),
                        const SizedBox(height: 20),
                      ],

                      Text(
                        "Create Account",
                        style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 8),
                      Text("Fill in your details to get started.", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16)),
                      
                      const SizedBox(height: 40),

                      _buildTextField(controller: _nameController, label: "Full Name", icon: Icons.person_outline),
                      const SizedBox(height: 20),
                      _buildTextField(controller: _emailController, label: "Email Address", icon: Icons.email_outlined),
                      const SizedBox(height: 20),
                      _buildTextField(controller: _passwordController, label: "Password", icon: Icons.lock_outline, isPassword: true),

                      const SizedBox(height: 30),

                      CyberButton(
                        text: "REGISTER NOW",
                        isLoading: _isLoading,
                        onPressed: _handleSignup,
                      ),

                      const SizedBox(height: 30),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Already have an account? ", style: TextStyle(color: Colors.grey)),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: const Text("Log In", style: TextStyle(color: AppColors.primaryStart, fontWeight: FontWeight.bold)),
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

  // Helpers
  Widget _buildCircle(double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
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
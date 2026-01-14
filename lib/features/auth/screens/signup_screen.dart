import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart'; // ✅ Hive Import zaroori hai
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:prepvault_ai/core/widgets/cyber_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // ===========================================================================
  // 1️⃣ VARIABLES & CONTROLLERS
  // ===========================================================================
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isAgreed = false; 

  // ===========================================================================
  // 2️⃣ SIGN UP LOGIC
  // ===========================================================================
  Future<void> _handleSignUp() async {
    // 1. Validation
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _passwordController.text.isEmpty) {
      _showSnack("Please fill in all fields", Colors.orange);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnack("Passwords do not match!", Colors.red);
      return;
    }

    if (_passwordController.text.length < 6) {
      _showSnack("Password must be at least 6 characters long", Colors.orange);
      return;
    }

    if (!_isAgreed) {
      _showSnack("Please agree to the Privacy Policy.", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔥 Step 2: Retrieve Country from Hive (Jo Onboarding man save ki thi)
      var box = Hive.isBoxOpen('user_prefs') ? Hive.box('user_prefs') : await Hive.openBox('user_prefs');
      String savedCountry = box.get('target_audience', defaultValue: 'US'); // Default US agar kuch na mile

      // 3. Create Account
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _nameController.text.trim(),
          'country': savedCountry, // ✅ Chupke se country save kardi
        },
      );

      if (response.user != null) {
        if (mounted) {
          _showSnack("Account Created! 🚀", Colors.green);
          context.go('/subscription'); 
        }
      }

    } catch (e) {
      if (mounted) {
        String msg = e.toString().toLowerCase();
        if (msg.contains("already registered")) msg = "Email already exists. Please Log In.";
        else if (msg.contains("network")) msg = "Check your internet connection.";
        else msg = "Signup failed. Please try again.";
        _showSnack(msg, Colors.red);
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
      ),
    );
  }

  // ===========================================================================
  // 3️⃣ UI BUILDER
  // ===========================================================================
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
              
              // 1. LOGO & HEADER
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.primaryStart.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.person_add_rounded, size: 50, color: AppColors.primaryStart),
              ),
              const SizedBox(height: 24),
              Text("Create Account", style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              Text("Join us to start your learning journey.", textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 16)),
              
              const SizedBox(height: 40),

              // 2. FORM FIELDS
              _buildTextField(controller: _nameController, label: "Full Name", icon: Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField(controller: _emailController, label: "Email Address", icon: Icons.email_outlined),
              const SizedBox(height: 16),

              // ❌ COUNTRY PICKER REMOVED (Successfully)

              _buildTextField(controller: _passwordController, label: "Password", icon: Icons.lock_outline, isPassword: true),
              const SizedBox(height: 16),
              _buildTextField(controller: _confirmPasswordController, label: "Confirm Password", icon: Icons.lock_clock_outlined, isPassword: true),

              const SizedBox(height: 20),

              // 3. PRIVACY & BUTTON
              Row(
                children: [
                  SizedBox(
                    height: 24, width: 24,
                    child: Checkbox(value: _isAgreed, activeColor: AppColors.primaryStart, onChanged: (val) => setState(() => _isAgreed = val ?? false)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[700]),
                        children: [
                          const TextSpan(text: "I agree to "),
                          TextSpan(
                            text: "Privacy Policy",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryStart, decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse('https://sites.google.com/view/studybudy-ai/home')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: CyberButton(text: "CREATE ACCOUNT", isLoading: _isLoading, onPressed: _handleSignUp),
              ),

              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => context.push('/login'),
                child: Text("Already have an account? Log In", style: GoogleFonts.outfit(color: Colors.grey.shade600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: GoogleFonts.outfit(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: AppColors.primaryStart),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryStart, width: 2)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}
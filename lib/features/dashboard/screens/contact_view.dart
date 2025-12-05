import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybudy_ai/core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContactView extends StatefulWidget {
  const ContactView({super.key});

  @override
  State<ContactView> createState() => _ContactViewState();
}

class _ContactViewState extends State<ContactView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  
  String _category = 'general'; // general, bug, suggestion
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _prefillUser();
  }

  void _prefillUser() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _nameController.text = user.userMetadata?['full_name'] ?? '';
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final finalSubject = "[${_category.toUpperCase()}] ${_subjectController.text}";
      
      // Call Edge Function
      await Supabase.instance.client.functions.invoke('send-email', body: {
        'name': _nameController.text,
        'email': _emailController.text,
        'subject': finalSubject,
        'message': _messageController.text,
      });

      if (mounted) {
        // Show Success Dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
            title: Text("Message Sent!", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
            content: const Text("Thank you for reaching out. We will get back to you shortly."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  context.pop(); // Go back to settings
                },
                child: const Text("Done"),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to send: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text("Contact Support", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Category Selector
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'general', label: Text('General'), icon: Icon(Icons.help_outline)),
                      ButtonSegment(value: 'bug', label: Text('Report Bug'), icon: Icon(Icons.bug_report)),
                      ButtonSegment(value: 'suggestion', label: Text('Idea'), icon: Icon(Icons.lightbulb)),
                    ],
                    selected: {_category},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() => _category = newSelection.first);
                    },
                    style: ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  
                  const SizedBox(height: 30),

                  // 2. Header Text based on Category
                  _buildHeaderMessage(),

                  const SizedBox(height: 30),

                  // 3. Inputs
                  _buildTextField(controller: _nameController, label: "Your Name", icon: Icons.person),
                  const SizedBox(height: 16),
                  _buildTextField(controller: _emailController, label: "Email Address", icon: Icons.email, isEmail: true),
                  const SizedBox(height: 16),
                  _buildTextField(controller: _subjectController, label: "Subject", icon: Icons.short_text),
                  const SizedBox(height: 16),
                  _buildTextField(controller: _messageController, label: "Message", icon: Icons.message, maxLines: 5),

                  const SizedBox(height: 40),

                  // 4. Submit Button
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getCategoryColor(),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("SEND MESSAGE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildHeaderMessage() {
    String title = "How can we help?";
    String sub = "We usually respond within 24 hours.";
    Color color = AppColors.primaryStart;

    if (_category == 'bug') {
      title = "Found a Bug?";
      sub = "Please describe the issue in detail so we can fix it.";
      color = Colors.orange;
    } else if (_category == 'suggestion') {
      title = "Have an Idea?";
      sub = "We love feedback! Tell us how to improve.";
      color = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 5),
          Text(sub, textAlign: TextAlign.center, style: GoogleFonts.outfit(color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Color _getCategoryColor() {
    if (_category == 'bug') return Colors.orange;
    if (_category == 'suggestion') return Colors.purple;
    return AppColors.primaryStart;
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    int maxLines = 1,
    bool isEmail = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        if (isEmail && !value.contains('@')) return 'Invalid Email';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 0), // Align top if multiline
          child: Icon(icon, color: Colors.grey),
        ),
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _getCategoryColor(), width: 2)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
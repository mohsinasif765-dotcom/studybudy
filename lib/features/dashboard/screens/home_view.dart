import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:file_picker/file_picker.dart'; 
import 'package:go_router/go_router.dart'; // Routing
import 'package:studybudy_ai/core/theme/app_colors.dart';
import 'package:studybudy_ai/features/dashboard/widgets/action_card.dart';
import 'package:studybudy_ai/core/services/file_processing_service.dart';
import 'package:studybudy_ai/core/widgets/ai_processing_overlay.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final FileProcessingService _fileService = FileProcessingService();
  final ImagePicker _picker = ImagePicker();

  // 🏁 START FLOW: Pehle Action Pucho
  void _startProcess(String sourceType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildActionSelectionModal(sourceType),
    );
  }

  // 1. 📄 Pick PDF Logic
  void _pickAndProcessPDF(String actionType) async {
    Navigator.pop(context); // Close selection modal

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        if (!mounted) return;

        // 🚀 SMART HYBRID PROCESSING
        final extractedText = await AIProcessingOverlay.show<String?>(
          context: context,
          asyncTask: (updateStatus) async {
            return await _fileService.processSmartly(
              result.files.single, 
              onStatusChange: updateStatus
            );
          },
        );

        if (!mounted) return;

        // 🟢 Case A: Small File (Text mil gaya) -> Go Next
        if (extractedText != null) {
          if (actionType == 'summary') {
            context.push('/summary', extra: extractedText);
          } else {
            context.push('/quiz-setup', extra: extractedText);
          }
        } 
        // 🔴 Case B: Large File (Null mila) -> Show Notification Msg
        else {
          _showLargeFileMessage();
        }
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  // 2. 📷 Camera Scan Logic
  void _scanAndProcessImage(String actionType) async {
    Navigator.pop(context); // Close modal

    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      
      if (photo != null) {
        if (!mounted) return;

        final text = await AIProcessingOverlay.show<String>(
          context: context,
          asyncTask: (updateStatus) async {
            updateStatus("Scanning Image...");
            return await _fileService.extractTextFromImage(photo);
          },
        );
        
        if (text != null && mounted) {
          if (actionType == 'summary') {
            context.push('/summary', extra: text);
          } else {
            context.push('/quiz-setup', extra: text);
          }
        }
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  // 🔔 Large File Dialog
  void _showLargeFileMessage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("File Uploaded 🚀"),
        content: const Text(
          "Your file is large (>5MB), so we are processing it on our AI Server.\n\n"
          "You can close the app. We will notify you once the ${"result"} is ready.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("OK, Got it")
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  // ✨ ACTION SELECTION MODAL (Design)
  Widget _buildActionSelectionModal(String source) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text("Select Goal", style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          _buildOptionTile(
            title: "Generate Summary",
            icon: Icons.article_outlined,
            color: Colors.blue,
            onTap: () => source == 'pdf' ? _pickAndProcessPDF('summary') : _scanAndProcessImage('summary'),
          ),
          const SizedBox(height: 12),
          _buildOptionTile(
            title: "Create Quiz / Test",
            icon: Icons.quiz_outlined,
            color: Colors.pink,
            onTap: () => source == 'pdf' ? _pickAndProcessPDF('quiz') : _scanAndProcessImage('quiz'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOptionTile({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textDark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Hello, Student 👋", style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey)),
                      Text("Let's Study!", style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                  CircleAvatar(radius: 24, backgroundColor: AppColors.primaryStart.withValues(alpha: 0.2), child: const Icon(Icons.person, color: AppColors.primaryStart)),
                ],
              ),
              const SizedBox(height: 32),

              // Cards Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: constraints.maxWidth > 600 ? 1.2 : 0.75,
                    children: [
                      ActionCard(
                        title: "Upload PDF",
                        subtitle: "Summarize & Quiz",
                        icon: Icons.upload_file_rounded,
                        gradientColors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        onTap: () => _startProcess('pdf'), // 👈 Start New Flow
                      ),
                      ActionCard(
                        title: "Scan Notes",
                        subtitle: "Camera OCR",
                        icon: Icons.camera_alt_rounded,
                        gradientColors: const [Color(0xFFEC4899), Color(0xFFF43F5E)],
                        onTap: () => _startProcess('camera'), // 👈 Start New Flow
                      ),
                    ],
                  );
                }
              ),
              
              // ... Recent Activity code (Same as before) ...
            ],
          ),
        ),
      ),
    );
  }
}
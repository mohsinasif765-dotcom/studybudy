import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:prepvault_ai/features/dashboard/widgets/action_card.dart';
import 'package:prepvault_ai/features/dashboard/widgets/recent_activity_list.dart';
import 'package:prepvault_ai/core/services/file_processing_service.dart';
import 'package:prepvault_ai/core/widgets/ai_processing_overlay.dart';
import 'package:prepvault_ai/core/utils/ai_error_handler.dart';
import 'package:prepvault_ai/features/history/services/history_service.dart'; 

// 👇 Custom Imports
import 'package:prepvault_ai/core/widgets/smart_banner_ad.dart';
import 'package:prepvault_ai/core/utils/credit_manager.dart'; 
import 'package:prepvault_ai/core/services/ad_service.dart';

class HomeView extends StatefulWidget {
  final VoidCallback? onSwitchToHistory;
  const HomeView({super.key, this.onSwitchToHistory});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // ===========================================================================
  // 1️⃣ VARIABLES
  // ===========================================================================
  final FileProcessingService _fileService = FileProcessingService();
  final ImagePicker _picker = ImagePicker();
  final HistoryService _historyService = HistoryService();

  final int _summaryCost = 10; 

  @override
  void initState() {
    super.initState();
    debugPrint("🚀 [HOME] Initializing Home View...");
    _initAdsSafe();
  }

  // 🔥 SAFE AD INIT: Crash Proof
  Future<void> _initAdsSafe() async {
    try {
      AdService().loadInterstitialAd();
      AdService().loadRewardedAd();
      await AdService().updateSubscriptionStatus().catchError((_) {});
      if (mounted) setState(() {}); 
    } catch (e) {
      debugPrint("⚠️ Ad Init Warning: $e");
    }
  }

  // ===========================================================================
  // ⏳ UI HELPER: LOADING DIALOG (Anti-Hang)
  // ===========================================================================
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryStart),
              const SizedBox(height: 16),
              Text("Verifying Credits...", style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.none, color: Colors.black)),
            ],
          ),
        ),
      ),
    );
  }

  void _hideLoadingDialog() {
    if (Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // ===========================================================================
  // 🔍 LOGIC: CHECK CREDITS (Network Safe)
  // ===========================================================================
  Future<bool> _fetchAndCheckCredits() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await Supabase.instance.client
          .from('profiles') 
          .select('credits_remaining') 
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 10));

      final int currentCredits = response['credits_remaining'] ?? 0;
      
      if (mounted) _hideLoadingDialog(); 
      if (!mounted) return false;

      return await CreditManager.canProceed(
        context: context, 
        requiredCredits: _summaryCost, 
        availableCredits: currentCredits
      );

    } catch (e) {
      if (mounted) _hideLoadingDialog();
      debugPrint("❌ Credit Check Failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please check your internet connection."),
          backgroundColor: Colors.red,
        )
      );
      return false;
    }
  }

  // ===========================================================================
  // 3️⃣ PDF LOGIC
  // ===========================================================================
  Future<void> _pickAndProcessPDF() async {
    Navigator.pop(context); 
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || !mounted) return;

      final PlatformFile file = result.files.single;

      _showLoadingDialog();

      bool canProceed = await _fetchAndCheckCredits();
      if (!canProceed) return;

      final dynamic resultData = await AIProcessingOverlay.show<dynamic>(
        context: context,
        initialMessage: "Generating Summary...",
        asyncTask: (updateStatus) async {
          return await _fileService.processSmartly(
            file,
            'summary',
            onStatusChange: updateStatus,
            options: null, 
          );
        },
      );

      if (!mounted) return;
      
      if (resultData != null && resultData != 'BACKGROUND_MODE') {
        _showSummaryReadyDialog(resultData, file.name);
      } else if (resultData == 'BACKGROUND_MODE') {
        AIProcessingOverlay.showBackgroundNotification(context);
      }
      
    } catch (e) {
      if (mounted) _hideLoadingDialog();
      if (mounted) handleAiError(context, e);
    }
  }

  // ===========================================================================
  // 4️⃣ CAMERA LOGIC
  // ===========================================================================
  Future<void> _scanAndProcessImage() async {
    Navigator.pop(context);

    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (photo == null || !mounted) return;

      _showLoadingDialog();

      bool canProceed = await _fetchAndCheckCredits();
      if (!canProceed) return;

      final dynamic resultData = await AIProcessingOverlay.show<dynamic>(
        context: context,
        initialMessage: "Analyzing Image...",
        asyncTask: (updateStatus) async {
          return await _fileService.processImageSmartly(
            photo, 
            'summary', 
            onStatusChange: updateStatus, 
            options: null 
          );
        },
      );

      if (!mounted) return;

      if (resultData != null) {
        _showSummaryReadyDialog(resultData, "Scanned Document");
      }
      
    } catch (e) {
      if (mounted) _hideLoadingDialog();
      if (mounted) handleAiError(context, e);
    }
  }

  // ===========================================================================
  // 5️⃣ SAVE & NAVIGATE (Strict Ad Flow)
  // ===========================================================================
  Future<void> _saveAndNavigateSummary(dynamic content, String fileName) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      String summaryText = content is Map ? (content['summary_markdown'] ?? content['text'] ?? "") : content.toString();

      final data = {
        'user_id': userId,
        'type': 'summary',
        'title': 'Summary: $fileName',
        'original_file_name': fileName,
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
        'content': summaryText 
      };

      final response = await Supabase.instance.client
          .from('study_history')
          .insert(data)
          .select('id')
          .single()
          .timeout(const Duration(seconds: 10));
      
      _historyService.cacheSummaryInstantly(response['id'], summaryText, title: 'Summary: $fileName');

      if (!mounted) return;
      context.push('/summary/${response['id']}');

    } catch (e) {
      debugPrint("❌ Save Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection Issue: Summary saved locally."), backgroundColor: Colors.orange));
      }
    }
  }

  // ===========================================================================
  // 6️⃣ UI HELPERS & BUILD
  // ===========================================================================
  void _showSummaryReadyDialog(dynamic content, String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Summary Ready!", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Analyzed '$fileName'. Tap View to read."),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryStart, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: () {
                Navigator.pop(context); 
                AdService().showInterstitialAd(
                  onAdClosed: () {
                    _saveAndNavigateSummary(content, fileName);
                  }
                );
              }, 
              child: const Text("View Summary", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  void _handleCardTap(String actionType) {
    if (actionType == 'quiz') context.push('/quiz-setup');
    else if (actionType == 'questionset') context.push('/questionset-setup');
    else if (actionType == 'examstore') context.push('/exam-store');
    else showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (c) => _buildSourceSelectionModal());
  }

  Widget _buildSourceSelectionModal() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Generate Summary", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
          _buildOptionTile("Upload PDF", Icons.upload_file_rounded, Colors.blue, _pickAndProcessPDF),
          const SizedBox(height: 12),
          _buildOptionTile("Scan Camera", Icons.camera_alt_rounded, Colors.pink, _scanAndProcessImage),
      ]),
    );
  }

  Widget _buildOptionTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color)),
      title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("Hello, Student 👋", style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey)),
                            Text("Let's Study!", style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        ]),
                        const Icon(Icons.auto_stories, color: AppColors.primaryStart, size: 22),
                    ]),
                    const SizedBox(height: 32),
                    
                    LayoutBuilder(builder: (context, constraints) {
                      return GridView.count(
                        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: constraints.maxWidth > 600 ? 3 : 2,
                        crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: constraints.maxWidth > 600 ? 1.5 : 0.8,
                        children: [
                          ActionCard(title: "Summary", subtitle: "PDF", icon: Icons.summarize_rounded, gradientColors: const [Color(0xFF0EA5E9), Color(0xFF3B82F6)], onTap: () => _handleCardTap('summary')),
                          ActionCard(title: "Quiz", subtitle: "Test", icon: Icons.quiz_rounded, gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)], onTap: () => _handleCardTap('quiz')),
                          ActionCard(title: "Questions", subtitle: "Practice", icon: Icons.assignment_turned_in_rounded, gradientColors: const [Color(0xFF10B981), Color(0xFF059669)], onTap: () => _handleCardTap('questionset')),
                          ActionCard(title: "Exam Store", subtitle: "Papers", icon: Icons.store_mall_directory_rounded, gradientColors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)], onTap: () => _handleCardTap('examstore')),
                        ],
                      );
                    }),
                    
                    const SizedBox(height: 32),
                    RecentActivityList(onViewAll: widget.onSwitchToHistory),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
          
          // 🔥 FIXED: Smart Banner Ad with Subscription Check
          ValueListenableBuilder<bool>(
            valueListenable: AdService().isFreeUserNotifier,
            builder: (context, isFree, child) {
              if (isFree) {
                return const SafeArea(
                  top: false,
                  child: SmartBannerAd(),
                );
              }
              return const SizedBox.shrink(); // Premium user ke liye zero space
            },
          ),
        ],
      ),
    );
  }
}
import 'dart:convert'; // Json Encode ke liye
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:prepvault_ai/features/quiz/models/quiz_model.dart';
import 'package:prepvault_ai/core/services/file_processing_service.dart';
import 'package:prepvault_ai/core/widgets/ai_processing_overlay.dart';
import 'package:prepvault_ai/core/utils/ai_error_handler.dart';
import 'package:prepvault_ai/features/history/services/history_service.dart'; 

// 👇 Custom Imports (Ads & Credits)
import 'package:prepvault_ai/core/widgets/smart_banner_ad.dart';
import 'package:prepvault_ai/core/utils/credit_manager.dart'; 
import 'package:prepvault_ai/core/services/ad_service.dart';

class QuestionSetSetupScreen extends StatefulWidget {
  final String? fileContent;
  const QuestionSetSetupScreen({super.key, this.fileContent});

  @override
  State<QuestionSetSetupScreen> createState() => _QuestionSetSetupScreenState();
}

class _QuestionSetSetupScreenState extends State<QuestionSetSetupScreen> {
  // ===========================================================================
  // 1️⃣ VARIABLES
  // ===========================================================================
  final FileProcessingService _fileService = FileProcessingService();
  final ImagePicker _picker = ImagePicker();

  String _difficulty = 'Medium';
  double _questionCount = 10;
  final TextEditingController _topicController = TextEditingController();
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initSafe(); // 🔥 Safe Init
  }

  // 🔥 Crash Proof Init & Ad Pre-loading
  Future<void> _initSafe() async {
    try {
      // Background mein ad load kar rahe hain taake jab user click kare to ad ready ho
      AdService().loadInterstitialAd();
      AdService().loadRewardedAd();
      
      await AdService().updateSubscriptionStatus().catchError((_) {});
      if (mounted) setState(() {}); 
    } catch (e) {
      debugPrint("⚠️ Ad Init Warning: $e");
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 💡 EXAM-SPECIFIC RECOMMENDATIONS
  // ===========================================================================
  String get _recommendationText {
    if (_questionCount <= 10) {
      return "Perfect for a quick 'Short Question' test. Upload 3-5 pages for precise model answers.";
    } else if (_questionCount <= 20) {
      return "Standard Exam Mode. Ensure your document covers enough topics for 20 unique theory questions.";
    } else {
      return "Comprehensive Paper Mode. Best for long chapters. Expect detailed analysis and critical thinking questions.";
    }
  }

  // ===========================================================================
  // 2️⃣ UI HANDLERS
  // ===========================================================================
  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
            Text(
              "Select Material for Exam Paper", 
              textScaler: TextScaler.noScaling, 
              style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)
            ),
            const SizedBox(height: 8),
            Text(
              "AI will generate Questions, Answers & Marks.", 
              textScaler: TextScaler.noScaling, 
              style: GoogleFonts.outfit(color: Colors.grey.shade700, fontSize: 12)
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.picture_as_pdf, color: Colors.red),
              ),
              title: const Text("Upload Book/Notes (PDF)", textScaler: TextScaler.noScaling, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
              subtitle: const Text("Best for detailed theory extraction", textScaler: TextScaler.noScaling, style: TextStyle(color: Colors.black54)),
              onTap: () => _pickFileAndStart(source: 'pdf'),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.camera_alt, color: Colors.blue),
              ),
              title: const Text("Scan Physical Paper", textScaler: TextScaler.noScaling, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
              subtitle: const Text("Snap a photo of your textbook", textScaler: TextScaler.noScaling, style: TextStyle(color: Colors.black54)),
              onTap: () => _pickFileAndStart(source: 'camera'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
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
              Text("Checking Credits...", style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.none, color: Colors.black)),
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
  // 🔍 LOGIC: CHECK CREDITS (Safe Way)
  // ===========================================================================
  Future<bool> _fetchAndCheckCredits() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if(mounted) _hideLoadingDialog();
        return false;
      }

      final response = await Supabase.instance.client
          .from('profiles') 
          .select('credits_remaining') 
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 10)); // Timeout added

      final int currentCredits = response['credits_remaining'] ?? 0;
      final int requiredCost = _questionCount.toInt();

      if (mounted) _hideLoadingDialog(); 
      if (!mounted) return false;

      return await CreditManager.canProceed(
        context: context, 
        requiredCredits: requiredCost, 
        availableCredits: currentCredits
      );

    } catch (e) {
      if (mounted) _hideLoadingDialog();
      debugPrint("❌ Credit Check Failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection error. Please check internet.")));
      return false;
    }
  }

  // ===========================================================================
  // 3️⃣ STEP 1: FILE PICKING
  // ===========================================================================
  Future<void> _pickFileAndStart({required String source}) async {
    Navigator.pop(context); 
    debugPrint("🟢 [EXAM-GEN] Starting process from: $source");

    XFile? photo;
    FilePickerResult? fileResult;

    try {
      if (source == 'camera') {
        photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
        if (photo == null) return;
      } else {
        fileResult = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
        if (fileResult == null) return;
      }

      _showLoadingDialog();

      bool canProceed = await _fetchAndCheckCredits();
      if (!canProceed) return;

      _generateQuestionSet(photo: photo, fileResult: fileResult, source: source);

    } catch (e) {
      if (mounted && Navigator.canPop(context)) _hideLoadingDialog();
      debugPrint("File Picking Error: $e");
    }
  }

  // ===========================================================================
  // 3️⃣ STEP 2: AI GENERATION LOGIC
  // ===========================================================================
  Future<void> _generateQuestionSet({XFile? photo, FilePickerResult? fileResult, required String source}) async {
    if (!mounted) return;

    try {
      // Start AI Overlay
      final dynamic rawResult = await AIProcessingOverlay.show<dynamic>(
        context: context,
        initialMessage: "Drafting Exam Paper...", 
        asyncTask: (updateStatus) async {
          
          final Map<String, dynamic> options = {
            'difficulty': _difficulty,
            'count': _questionCount.toInt(),
            'topic': _topicController.text.trim(),
            'type': 'questionset', 
            'action': 'generate_question_set' 
          };

          if (source == 'camera') {
            return await _fileService.processImageSmartly(photo!, 'questionset', onStatusChange: updateStatus, options: options);
          } else {
            return await _fileService.processSmartly(fileResult!.files.single, 'questionset', onStatusChange: updateStatus, options: options);
          }
        },
      );

      if (!mounted) return;

      if (rawResult == 'BACKGROUND_MODE') {
        AIProcessingOverlay.showBackgroundNotification(context);
        return;
      }

      debugPrint("🧩 [EXAM-GEN] Parsing Response...");
      final List<QuizQuestion> questions = _robustParse(rawResult);

      if (questions.isNotEmpty) {
        // 🎉 Valid Response -> Show Popup
        if (questions.length < _questionCount.toInt()) {
          _showLowContentDialog(questions, _questionCount.toInt());
        } else {
          _showExamReadyDialog(questions); 
        }
      } else {
        _showCustomError("Could not generate valid exam questions. Try a clearer document.");
      }

    } catch (e) {
      if (mounted) handleAiError(context, e);
    }
  }

  // 🔥 UPDATED PARSER (Super Safe)
  List<QuizQuestion> _robustParse(dynamic rawData) {
    try {
      dynamic processedData = rawData;

      if (processedData is String) {
        String clean = processedData.replaceAll('```json', '').replaceAll('```', '').trim();
        try { processedData = jsonDecode(clean); } catch (e) { return []; }
      }

      List<dynamic> listToParse = [];
      if (processedData is Map && processedData.containsKey('data')) {
        listToParse = processedData['data'];
      } else if (processedData is List) {
        listToParse = processedData;
      }

      List<QuizQuestion> validQuestions = [];
      for (var item in listToParse) {
        try {
          // Force convert to Map<String, dynamic> safely
          final cleanItem = Map<String, dynamic>.from(item as Map);
          validQuestions.add(QuizQuestion.fromTheoryJson(cleanItem));
        } catch (e) {
          debugPrint("⚠️ Skipping bad item: $e");
        }
      }
      return validQuestions;
    } catch (e) {
      return [];
    }
  }

  // ===========================================================================
  // 4️⃣ SAVE & NAVIGATE (With Timeout & Safety)
  // ===========================================================================
  Future<void> _saveAndNavigate(List<QuizQuestion> questions) async {
    setState(() => _isSaving = true);
    
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw "User not logged in";

      final title = _topicController.text.isNotEmpty 
          ? _topicController.text 
          : 'Theory Set (${questions.length} Qs)';

      final data = {
        'user_id': userId,
        'type': 'questionset', 
        'title': title,
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
        'content': jsonEncode({'data': questions.map((e) => e.toJson()).toList()}), 
      };

      // 🔥 Timeout Protection (10 seconds)
      final response = await Supabase.instance.client
          .from('study_history')
          .insert(data)
          .select('id')
          .single()
          .timeout(const Duration(seconds: 10));

      final newId = response['id'];

      HistoryService().cacheQuestionSetInstantly(newId, questions, title: title);

      if (!mounted) return;
      setState(() => _isSaving = false);

      context.push('/questionset-dashboard/$newId');

    } catch (e) {
      debugPrint("❌ Save Error: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        // Error ke bawajood navigate karwa sakte hain agar offline caching strong hai, 
        // lekin filhal user ko bata rahe hain.
        _showCustomError("Saved locally (Sync pending). Check internet.");
        // Optional: Force navigate if you have local storage
        // context.push('/questionset-dashboard/local_temp_id'); 
      }
    }
  }

  // ===========================================================================
  // 5️⃣ DIALOGS (With Ads Flow)
  // ===========================================================================
  void _showExamReadyDialog(List<QuizQuestion> questions) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.description, color: AppColors.primaryStart),
            const SizedBox(width: 10),
            const Text("Exam Paper Ready"),
          ],
        ),
        content: Text("We extracted ${questions.length} high-quality questions for you."),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryStart, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              onPressed: () {
                Navigator.pop(context); // Close Popup
                
                // 🔥 THE ADS FLOW: Show Ad -> On Close -> Save & Navigate
                AdService().showInterstitialAd(
                  onAdClosed: () {
                    _saveAndNavigate(questions);
                  }
                );
              },
              child: const Text("View Paper & Solutions"),
            ),
          )
        ],
      ),
    );
  }

  void _showLowContentDialog(List<QuizQuestion> questions, int requested) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Short Exam Paper"),
        content: Text("We extracted ${questions.length} questions (Requested: $requested)."),
        actions: [
          TextButton(
            onPressed: () {
             Navigator.pop(context);
             // Same Ad Flow here
             AdService().showInterstitialAd(
               onAdClosed: () => _saveAndNavigate(questions)
             );
            }, 
            child: const Text("View Anyway")
          )
        ],
      ),
    );
  }

  void _showCustomError(String msg) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // ===========================================================================
  // 6️⃣ UI BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), 
      appBar: AppBar(
        title: Text("Theory Generator", 
          textScaler: TextScaler.noScaling, 
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.black87)
        ), 
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        centerTitle: true,
        leading: const BackButton(color: Colors.black87),
      ),
      
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // INFO BANNER
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD), 
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFECB5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.school_outlined, color: Color(0xFF856404)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Exam Paper Mode", textScaler: TextScaler.noScaling, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: const Color(0xFF856404))),
                                      Text("Generates Subjective Questions with Model Answers & Marks. (No MCQs)", textScaler: TextScaler.noScaling, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF856404))),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          Card(
                            elevation: 0, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey.shade200)), 
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Target Difficulty", textScaler: TextScaler.noScaling, style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  const SizedBox(height: 12),
                                  SizedBox(width: double.infinity, child: SegmentedButton<String>(
                                      segments: const [
                                        ButtonSegment(value: 'Easy', label: Text('Basic'), icon: Icon(Icons.star_outline, size: 16)), 
                                        ButtonSegment(value: 'Medium', label: Text('Standard'), icon: Icon(Icons.star_half, size: 16)), 
                                        ButtonSegment(value: 'Hard', label: Text('Advanced'), icon: Icon(Icons.star, size: 16))
                                      ],
                                      selected: {_difficulty}, onSelectionChanged: (s) => setState(() => _difficulty = s.first),
                                      style: ButtonStyle(
                                        backgroundColor: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.primaryStart : Colors.transparent),
                                        foregroundColor: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.white : Colors.black87),
                                        textStyle: WidgetStateProperty.all(GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                                      )
                                  )),
                                  
                                  const SizedBox(height: 32),
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                      Text("Number of Items", textScaler: TextScaler.noScaling, style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(color: AppColors.primaryStart.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                        child: Text("${_questionCount.toInt()} Qs", textScaler: TextScaler.noScaling, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryStart)),
                                      )
                                  ]),
                                  Slider(value: _questionCount, min: 5, max: 30, divisions: 5, activeColor: AppColors.primaryStart, onChanged: (v) => setState(() => _questionCount = v)),
                                  
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(_recommendationText, textScaler: TextScaler.noScaling, style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic)),
                                  ),

                                  const SizedBox(height: 32),
                                  TextField(
                                    controller: _topicController, 
                                    style: const TextStyle(color: Colors.black87),
                                    decoration: InputDecoration(
                                      labelText: "Specific Topic/Chapter (Optional)", labelStyle: const TextStyle(color: Colors.black54),
                                      hintText: "e.g., Photosynthesis, Newton's Laws", hintStyle: const TextStyle(color: Colors.black38),
                                      prefixIcon: const Icon(Icons.topic_outlined, color: Colors.black54),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50
                                    )
                                  ),
                                  const SizedBox(height: 40),
                                  
                                  SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(
                                      onPressed: _showUploadOptions, 
                                      icon: const Icon(Icons.auto_awesome), 
                                      label: Text("GENERATE EXAM PAPER", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryStart, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        elevation: 4, shadowColor: AppColors.primaryStart.withValues(alpha: 0.4) 
                                      )
                                  )),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (_isSaving)
                  Container(
                    color: const Color.fromRGBO(0, 0, 0, 0.5), 
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: AppColors.primaryStart),
                            const SizedBox(height: 16),
                            Text("Finalizing Paper...", textScaler: TextScaler.noScaling, style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // 🔥 Bottom Banner Ad (VIP Logic Applied)
          ValueListenableBuilder<bool>(
            valueListenable: AdService().isFreeUserNotifier, // ✅ Fix applied here
            builder: (context, isFreeUser, child) {
              if (!isFreeUser) return const SizedBox.shrink(); // 🛑 Hide for VIPs
              
              return const SafeArea(
                top: false,
                child: SmartBannerAd(),
              );
            },
          ),
        ],
      ),
    );
  }
}
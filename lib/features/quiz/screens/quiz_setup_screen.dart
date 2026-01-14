import 'dart:convert'; // Json Encode ke liye
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Supabase Import

import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:prepvault_ai/features/quiz/models/quiz_model.dart';
import 'package:prepvault_ai/core/services/file_processing_service.dart';
import 'package:prepvault_ai/core/widgets/ai_processing_overlay.dart';
import 'package:prepvault_ai/core/utils/ai_error_handler.dart';
import 'package:prepvault_ai/features/history/services/history_service.dart';

// 👇 Custom Imports
import 'package:prepvault_ai/core/widgets/smart_banner_ad.dart';
import 'package:prepvault_ai/core/utils/credit_manager.dart'; 
import 'package:prepvault_ai/core/services/ad_service.dart';

class QuizSetupScreen extends StatefulWidget {
  final String? fileContent;
  const QuizSetupScreen({super.key, this.fileContent});

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  // ===========================================================================
  // 1️⃣ VARIABLES & CONTROLLERS
  // ===========================================================================
  final FileProcessingService _fileService = FileProcessingService();
  final ImagePicker _picker = ImagePicker();

  String _difficulty = 'Medium';
  double _questionCount = 10;
  final TextEditingController _topicController = TextEditingController();
  
  // Loading State for Database Saving
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initSafe(); // 🔥 Crash Proof Init
  }

  // 🔥 SAFE INIT: Agar internet na ho to crash na ho
  Future<void> _initSafe() async {
    try {
      // Sirf koshish karega update karne ki, fail hua to ignore karega
      await AdService().updateSubscriptionStatus().catchError((_) {});
      
      if (mounted) setState(() {}); 
      
      // Load Interstitial Ad beforehand for smoother experience
      AdService().loadInterstitialAd(); 
      AdService().loadRewardedAd();
    } catch (e) {
      debugPrint("⚠️ Ad Service Init Error (Offline mode): $e");
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 💡 HELPER: Dynamic Recommendation Text
  // ===========================================================================
  String get _recommendationText {
    if (_questionCount <= 10) {
      return "For optimal quality, we recommend uploading a file with at least 3 to 5 pages of rich, valuable content.";
    } else if (_questionCount <= 20) {
      return "To ensure a diverse set of questions, please provide a document containing 10 to 20 pages of detailed context.";
    } else {
      return "For deep coverage and high volume, please upload a comprehensive document with 25 to 40+ pages of data.";
    }
  }

  // ===========================================================================
  // 2️⃣ UI HANDLERS (Bottom Sheet & Inputs)
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
            Text("Select Source for Quiz", style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text("Upload PDF Document"),
              onTap: () => _pickFileAndStart(source: 'pdf'),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text("Scan with Camera"),
              onTap: () => _pickFileAndStart(source: 'camera'),
            ),
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
        _hideLoadingDialog();
        _showCustomError("You need to be logged in.");
        return false;
      }

      final response = await Supabase.instance.client
          .from('profiles') 
          .select('credits_remaining') 
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 10));

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
      _showCustomError("Network error. Please check your internet connection.");
      return false;
    }
  }

  // ===========================================================================
  // 3️⃣ STEP 1: FILE PICKING
  // ===========================================================================
  Future<void> _pickFileAndStart({required String source}) async {
    Navigator.pop(context); 

    XFile? photo;
    PlatformFile? pdfFile; 

    try {
      if (source == 'camera') {
        photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
        if (photo == null) return;
      } else {
        FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
        if (result == null) return;
        pdfFile = result.files.single;
      }

      _showLoadingDialog();
      bool canProceed = await _fetchAndCheckCredits();
      if (!canProceed) return;

      _generateQuiz(photo: photo, pdfFile: pdfFile, source: source);

    } catch (e) {
      if (mounted) _hideLoadingDialog();
    }
  }

  // ===========================================================================
  // 3️⃣ STEP 2: AI GENERATION LOGIC
  // ===========================================================================
  Future<void> _generateQuiz({XFile? photo, PlatformFile? pdfFile, required String source}) async {
    if (!mounted) return;

    try {
      final dynamic finalResult = await AIProcessingOverlay.show<dynamic>(
        context: context,
        asyncTask: (updateStatus) async {
          final Map<String, dynamic> quizOptions = {
            'difficulty': _difficulty,
            'count': _questionCount.toInt(),
            'topic': _topicController.text.trim(),
          };

          if (source == 'camera' && photo != null) {
            return await _fileService.processImageSmartly(
              photo, 'quiz', onStatusChange: updateStatus, options: quizOptions
            );
          } 
          else if (pdfFile != null) {
            return await _fileService.processSmartly(
              pdfFile, 'quiz', onStatusChange: updateStatus, options: quizOptions,
            );
          }
          throw "No file provided";
        },
      );

      if (!mounted) return;

      List<QuizQuestion> questions = [];
      
      List<QuizQuestion> safeParse(List<dynamic> rawList) {
        List<QuizQuestion> validItems = [];
        for (var item in rawList) {
          if (item is Map) {
            try {
              final cleanMap = Map<String, dynamic>.from(item);
              validItems.add(QuizQuestion.fromJson(cleanMap));
            } catch (e) { /* ignore */ }
          }
        }
        return validItems;
      }

      if (finalResult is List) {
        questions = safeParse(finalResult);
      }
      else if (finalResult is Map && finalResult.containsKey('data')) {
        if (finalResult['data'] is List) questions = safeParse(finalResult['data']);
      }
      else if (finalResult == 'BACKGROUND_MODE') {
        AIProcessingOverlay.showBackgroundNotification(context);
        return;
      }

      if (questions.isNotEmpty) {
        _showQuizReadyDialog(questions);
      } else {
        _showCustomError("AI failed to generate valid questions.");
      }

    } catch (e) {
      if (mounted) handleAiError(context, e);
    }
  }

  // ===========================================================================
  // 4️⃣ SAVE & NAVIGATE
  // ===========================================================================
  Future<void> _saveAndNavigate(List<QuizQuestion> questions) async {
    if (!mounted) return;
    setState(() => _isSaving = true);
    
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw "User not logged in";

      final quizTitle = _topicController.text.isNotEmpty 
          ? _topicController.text 
          : 'Generated Quiz (${questions.length} Qs)';

      final quizData = {
        'user_id': userId,
        'type': 'quiz',
        'title': quizTitle,
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
        'content': jsonEncode({
          'data': questions.map((e) => e.toJson()).toList()
        }),
      };

      final response = await Supabase.instance.client
          .from('study_history')
          .insert(quizData)
          .select('id')
          .single()
          .timeout(const Duration(seconds: 15));

      final newQuizId = response['id'];
      HistoryService().cacheDataInstantly(newQuizId, questions, title: quizTitle);

      if (!mounted) return;
      setState(() => _isSaving = false);
      context.push('/quiz-dashboard/$newQuizId');

    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showCustomError("Connection failed! Try again.");
      }
    }
  }

  // ===========================================================================
  // 5️⃣ DIALOGS (WITH AD LOGIC)
  // ===========================================================================
  
  void _showQuizReadyDialog(List<QuizQuestion> questions) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.primaryStart, size: 28),
            const SizedBox(width: 10),
            Text("Quiz Ready!", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("AI has successfully generated ${questions.length} questions."),
        actionsPadding: const EdgeInsets.all(20),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); 
                // 🔥 Ad Logic for Free Users
                if (AdService().isFreeUserNotifier.value) {
                  AdService().showInterstitialAd(
                    onAdClosed: () => _saveAndNavigate(questions)
                  );
                } else {
                  _saveAndNavigate(questions);
                }
              }, 
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryStart,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Start Quiz", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  void _showCustomError(String rawMessage) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(rawMessage))]),
        backgroundColor: const Color(0xFFC62828), 
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ===========================================================================
  // 6️⃣ UI BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: Text("Configure Quiz", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
      
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
                      child: Card(
                        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey.shade200)), color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Text("Difficulty Level", style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              SizedBox(width: double.infinity, child: SegmentedButton<String>(
                                  segments: const [ButtonSegment(value: 'Easy', label: Text('Easy')), ButtonSegment(value: 'Medium', label: Text('Medium')), ButtonSegment(value: 'Hard', label: Text('Hard'))],
                                  selected: {_difficulty}, onSelectionChanged: (s) => setState(() => _difficulty = s.first),
                                  style: ButtonStyle(shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))
                              )),
                              const SizedBox(height: 32),
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text("Questions", style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text("${_questionCount.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryStart))
                              ]),
                              Slider(value: _questionCount, min: 5, max: 30, divisions: 5, activeColor: AppColors.primaryStart, onChanged: (v) => setState(() => _questionCount = v)),
                              
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.08), 
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue.withOpacity(0.2))
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.tips_and_updates_rounded, size: 20, color: Colors.blue),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _recommendationText,
                                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.blue.shade800, height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 32),
                              TextField(controller: _topicController, decoration: InputDecoration(labelText: "Focus Topic (Optional)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)),
                              const SizedBox(height: 40),
                              SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(
                                  onPressed: _showUploadOptions, icon: const Icon(Icons.cloud_upload_outlined), label: Text("UPLOAD & GENERATE", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryStart, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))
                              )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                if (_isSaving)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: AppColors.primaryStart),
                            const SizedBox(height: 16),
                            Text("Saving your Quiz...", style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
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
              return const SizedBox.shrink(); // Hide if Paid
            },
          ),
        ],
      ),
    );
  }
}
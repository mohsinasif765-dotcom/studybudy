import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:prepvault_ai/features/quiz/models/quiz_model.dart';
import 'package:prepvault_ai/core/services/pdf_service.dart';
import 'package:prepvault_ai/features/history/services/history_service.dart'; 
// 🔥 1. New Imports for Logic
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepvault_ai/core/utils/credit_manager.dart';

// 👇 Import Smart Banner Ad and AdService
import 'package:prepvault_ai/core/widgets/smart_banner_ad.dart';
import 'package:prepvault_ai/core/services/ad_service.dart'; 

class QuizDashboardScreen extends StatefulWidget {
  final String quizId; 

  const QuizDashboardScreen({super.key, required this.quizId});

  @override
  State<QuizDashboardScreen> createState() => _QuizDashboardScreenState();
}

class _QuizDashboardScreenState extends State<QuizDashboardScreen> {
  
  // ===========================================================================
  // 1️⃣ VARIABLES & CONTROLLERS
  // ===========================================================================
  final TextEditingController _orgNameController = TextEditingController();
  final HistoryService _historyService = HistoryService(); 

  List<QuizQuestion> _questions = [];
  bool _isLoading = true;
  bool _hasError = false;

  // ===========================================================================
  // 2️⃣ LIFECYCLE METHODS
  // ===========================================================================
  @override
  void initState() {
    super.initState();
    debugPrint("🟢 [QUIZ_DASH] Screen Initialized. Target ID: ${widget.quizId}");
    _fetchQuizData();
  }

  @override
  void dispose() {
    _orgNameController.dispose();
    debugPrint("👋 [QUIZ_DASH] Screen Disposed");
    super.dispose();
  }

  // ===========================================================================
  // 3️⃣ DATA FETCHING LOGIC
  // ===========================================================================
  Future<void> _fetchQuizData() async {
    debugPrint("🔄 [QUIZ_DASH] Requesting data from HistoryService...");
    
    try {
      final rawData = await _historyService.getQuizDataById(widget.quizId);
      debugPrint("📦 [QUIZ_DASH] Raw Data Received. Count: ${rawData.length}");

      if (mounted) {
        setState(() {
          debugPrint("🧩 [QUIZ_DASH] Parsing data to QuizQuestion models...");
          _questions = rawData.map((e) => QuizQuestion.fromJson(e)).toList();
          
          _isLoading = false;
          
          if (_questions.isEmpty) {
            debugPrint("⚠️ [QUIZ_DASH] Warning: Parsed list is empty!");
            _hasError = true;
          } else {
            debugPrint("✅ [QUIZ_DASH] Success! ${_questions.length} questions loaded & ready.");
          }
        });
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [QUIZ_DASH] Critical Error: $e");
      debugPrint("❌ [QUIZ_DASH] StackTrace: $stackTrace");
      
      if (mounted) {
        setState(() { 
          _isLoading = false; 
          _hasError = true; 
        });
      }
    }
  }

  // ===========================================================================
  // 🔥 4️⃣ SMART EXPORT LOGIC (UPDATED: DYNAMIC COST)
  // ===========================================================================
  Future<void> _handleSmartExport({required String title}) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    // 1. Auth Check
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login to export.")));
      return;
    }

    // 2. Start Loader
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      // 3. Fetch Credits
      final profile = await supabase.from('profiles').select('credits_remaining').eq('id', user.id).single();
      final int availableCredits = profile['credits_remaining'] ?? 0;
      
      // 🔥 FIX: Cost Logic Updated (1 Question = 1 Credit)
      // Jitnay sawal hain list mein, utnay hi credits katnay chahiyen
      final int cost = _questions.length; 

      if (mounted) Navigator.pop(context); // Hide Loader

      debugPrint("💰 [EXPORT] Cost: $cost | Available: $availableCredits");

      // 4. Check Credit Manager 
      // (Agar credits kam hain to ye khud hi 'Watch Ad' wala dialog dikhaye ga)
      bool canProceed = await CreditManager.canProceed(
        context: context, 
        requiredCredits: cost, 
        availableCredits: availableCredits
      );

      // Agar user k paas credits thay, ya usne AD dekh liya
      if (canProceed) {
        
        // 5. Deduct Credits (Safe SQL Function)
        await supabase.rpc('decrement_credits_safe', params: {
           'user_id': user.id,
           'amount_to_deduct': cost
        }).catchError((e) async {
           // Fallback update logic
           await supabase.from('profiles').update({
             'credits_remaining': availableCredits - cost
           }).eq('id', user.id);
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Generating PDF... (-$cost Credits)"), 
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.teal,
          )
        );
        
        // 6. Generate PDF (Existing Logic)
        await PdfService.generateExamPaper(
          _questions, 
          title, 
          orgName: _orgNameController.text.isNotEmpty ? _orgNameController.text : null
        );
      }

    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      debugPrint("Export Error: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // ===========================================================================
  // 5️⃣ UI BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    
    // --- STATE A: LOADING ---
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryStart),
              const SizedBox(height: 16),
              Text(
                "Loading Quiz...", 
                textScaler: TextScaler.noScaling,
                style: GoogleFonts.spaceGrotesk(fontSize: 16, color: Colors.black87)
              ),
            ],
          ),
        ),
      );
    }

    // --- STATE B: ERROR ---
    if (_hasError || _questions.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () {
                debugPrint("🔙 [UI] User tapped Back from Error Screen");
                context.go('/dashboard');
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                "Quiz Not Found", 
                textScaler: TextScaler.noScaling,
                style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)
              ),
              const SizedBox(height: 8),
              Text(
                "Could not load the quiz data.", 
                textScaler: TextScaler.noScaling,
                style: GoogleFonts.outfit(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    // --- STATE C: SUCCESS (MAIN CONTENT) ---
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      
      appBar: AppBar(
        title: Text(
          "Quiz Ready", 
          textScaler: TextScaler.noScaling,
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.black87)
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () {
            debugPrint("❌ [UI] User tapped Close (Go to Dashboard)");
            context.go('/dashboard');
          },
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      
                      // === SECTION: SUCCESS BANNER ===
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 10)],
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 60),
                            const SizedBox(height: 16),
                            Text(
                              "${_questions.length} Questions Generated!",
                              textScaler: TextScaler.noScaling,
                              style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Your AI-powered quiz is ready. Choose how you want to proceed.",
                              textScaler: TextScaler.noScaling,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(color: Colors.black54, fontSize: 15),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      
                      // === SECTION: ACTIONS ===
                      
                      // ACTION 1: Start Test
                      _buildActionTile(
                        title: "Start Test Mode",
                        subtitle: "Take the quiz interactively and get a score.",
                        icon: Icons.play_circle_fill,
                        color: AppColors.primaryStart,
                        onTap: () {
                          debugPrint("🚀 [UI] User tapped 'Start Test Mode'");
                          context.push('/quiz-player', extra: _questions);
                        },
                      ),

                      const SizedBox(height: 16),

                      // ACTION 2: Read Mode
                      _buildActionTile(
                        title: "Read Only Mode",
                        subtitle: "View questions with answers marked.",
                        icon: Icons.menu_book,
                        color: Colors.orange,
                        onTap: () {
                          debugPrint("📖 [UI] User tapped 'Read Only Mode'");
                          context.push('/quiz-read', extra: _questions);
                        },
                      ),

                      const SizedBox(height: 32),
                      const Divider(color: Colors.black12),
                      const SizedBox(height: 20),

                      // === SECTION: EXPORT (With Credit Check) ===
                      
                      // 🔥 UI UPDATED: Cost is shown dynamically
                      Text(
                        "Export to PDF (${_questions.length} Credits)", 
                        textScaler: TextScaler.noScaling,
                        style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                      ),
                      const SizedBox(height: 12),
                      
                      TextField(
                        controller: _orgNameController,
                        style: GoogleFonts.outfit(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: "Organization/School Name (Optional)",
                          labelStyle: const TextStyle(color: Colors.black54),
                          hintText: "e.g. Oxford School System",
                          hintStyle: const TextStyle(color: Colors.black38),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.business, color: Colors.black54),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // 🔥 BUTTON: Calls _handleSmartExport
                      ElevatedButton.icon(
                        onPressed: () {
                           debugPrint("🖨️ [UI] User tapped 'Export Exam Paper'");
                           // ✅ Calls Smart Export with dynamic cost check
                           _handleSmartExport(title: "Generated Quiz");
                        },
                        icon: const Icon(Icons.print, size: 20),
                        label: const Text("Export Exam Paper", textScaler: TextScaler.noScaling),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 🔥 FIXED: Smart Banner Ad with Subscription Logic
          ValueListenableBuilder<bool>(
            valueListenable: AdService().isFreeUserNotifier,
            builder: (context, isFree, child) {
              if (isFree) {
                return const SafeArea(
                  top: false,
                  child: SmartBannerAd(),
                );
              }
              return const SizedBox.shrink(); 
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6️⃣ HELPER WIDGETS
  // ===========================================================================
  Widget _buildActionTile({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              // ✅ Safe Color Opacity
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    textScaler: TextScaler.noScaling,
                    style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                  ),
                  Text(
                    subtitle, 
                    textScaler: TextScaler.noScaling,
                    style: GoogleFonts.outfit(color: Colors.black87, fontSize: 13)
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}
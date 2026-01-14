import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:prepvault_ai/features/quiz/models/quiz_model.dart';
import 'package:prepvault_ai/core/services/pdf_service.dart';
import 'package:prepvault_ai/features/history/services/history_service.dart';
// 🔥 Supabase & Credit Manager Imports Added
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:prepvault_ai/core/utils/credit_manager.dart';

// 👇 1. Import Ad Service & Widget
import 'package:prepvault_ai/core/widgets/smart_banner_ad.dart';
import 'package:prepvault_ai/core/services/ad_service.dart'; 

class QuestionSetDashboard extends StatefulWidget {
  final String questionSetId; 

  const QuestionSetDashboard({super.key, required this.questionSetId});

  @override
  State<QuestionSetDashboard> createState() => _QuestionSetDashboardState();
}

class _QuestionSetDashboardState extends State<QuestionSetDashboard> {
  
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
    debugPrint("🟢 [QSET_DASH] Screen Initialized. ID: ${widget.questionSetId}");
    _fetchData();
  }

  @override
  void dispose() {
    _orgNameController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 3️⃣ DATA FETCHING LOGIC (Crash Proof)
  // ===========================================================================
  Future<void> _fetchData() async {
    debugPrint("🔄 [QSET_DASH] Fetching Question Set...");
    
    try {
      final rawData = await _historyService.getQuestionSetDataById(widget.questionSetId);
      
      // 🔥 SAFE PARSING LOGIC
      List<QuizQuestion> parsedList = [];
      for (var item in rawData) {
        try {
          parsedList.add(QuizQuestion.fromTheoryJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          debugPrint("⚠️ Skipping invalid question: $e");
        }
      }

      if (mounted) {
        setState(() {
          _questions = parsedList;
          _isLoading = false;
          
          if (_questions.isEmpty) {
             _hasError = true;
          } else {
             debugPrint("✅ [QSET_DASH] Loaded ${_questions.length} items.");
          }
        });
      }
    } catch (e) {
      debugPrint("❌ [QSET_DASH] Error: $e");
      if (mounted) {
        setState(() { 
          _isLoading = false; 
          _hasError = true; 
        });
      }
    }
  }

  // ===========================================================================
  // 🔥 4️⃣ SMART EXPORT LOGIC (DYNAMIC COST CHECK ADDED)
  // ===========================================================================
  Future<void> _handleSmartExport({required bool withAnswers, required String title}) async {
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
      // Jitnay sawal hain list mein, utnay hi credits katain gay
      final int cost = _questions.length; 

      if (mounted) Navigator.pop(context); // Hide Loader

      debugPrint("💰 [EXPORT] Cost: $cost | Available: $availableCredits");

      // 4. Check Credit Manager 
      // Ye function check karega k credits hain ya nahi. 
      // Agar kam hain, to ye khud hi Popup dikhaye ga.
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
        
        // 6. Generate PDF
        await PdfService.generateTheoryPaper(
          _questions, 
          title, 
          orgName: _orgNameController.text.isNotEmpty ? _orgNameController.text : null,
          withAnswers: withAnswers
        );
      }

    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      debugPrint("Export Error: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // ===========================================================================
  // 🔙 NAVIGATION SAFETY
  // ===========================================================================
  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  // ===========================================================================
  // 5️⃣ UI BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    
    // --- LOADING ---
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
                "Loading Question Set...", 
                textScaler: TextScaler.noScaling, 
                style: GoogleFonts.spaceGrotesk(fontSize: 16, color: Colors.black87)
              ),
            ],
          ),
        ),
      );
    }

    // --- ERROR ---
    if (_hasError || _questions.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: _handleBack, 
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                "Data Not Found", 
                textScaler: TextScaler.noScaling, 
                style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)
              ),
            ],
          ),
        ),
      );
    }

    // --- SUCCESS DASHBOARD ---
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      
      appBar: AppBar(
        title: Text(
          "Question Set Ready", 
          textScaler: TextScaler.noScaling, 
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.black87)
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: _handleBack, 
        ),
      ),

      // 🔥 2. Layout Update for Ad: Column -> Expanded -> Banner
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
                      
                      // === SECTION 1: INFO CARD ===
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 10)],
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.assignment_turned_in, color: Color(0xFF10B981), size: 60), 
                            const SizedBox(height: 16),
                            Text(
                              "${_questions.length} Questions Generated",
                              textScaler: TextScaler.noScaling, 
                              style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Your practice set is ready. Read, learn, or export as a paper.",
                              textScaler: TextScaler.noScaling, 
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(color: Colors.black87, fontSize: 15),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      
                      // === SECTION 2: READ MODE BUTTON ===
                      _buildActionTile(
                        title: "Read / Memorize Mode",
                        subtitle: "View questions with answers efficiently.",
                        icon: Icons.chrome_reader_mode_rounded,
                        color: Colors.blueAccent,
                        onTap: () {
                          debugPrint("📖 [UI] Navigate to Read Mode");
                          context.push('/questionset-read', extra: {'questions': _questions, 'title': 'Theory Set'});
                        },
                      ),

                      const SizedBox(height: 32),
                      const Divider(color: Colors.black12),
                      const SizedBox(height: 20),

                      // === SECTION 3: EXPORT OPTIONS ===
                      // 🔥 UI Update: Show "Cost: X Credits" dynamically
                      Text(
                        "Export Options (${_questions.length} Credits)", 
                        textScaler: TextScaler.noScaling, 
                        style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                      ),
                      const SizedBox(height: 12),
                      
                      // Org Name Input
                      TextField(
                        controller: _orgNameController,
                        style: GoogleFonts.outfit(fontSize: 16, color: Colors.black87), 
                        decoration: InputDecoration(
                          labelText: "Organization/School Name (Optional)",
                          labelStyle: const TextStyle(color: Colors.black87), 
                          hintText: "e.g. Oxford School System",
                          hintStyle: const TextStyle(color: Colors.black45),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.business, color: Colors.black87), 
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Button A: Export Q&A (Solved)
                      _buildExportButton(
                        text: "Export Q&A Sheet (Solved)",
                        icon: Icons.task_alt,
                        color: Colors.teal,
                        // ✅ Calls _handleSmartExport
                        onPressed: () => _handleSmartExport(withAnswers: true, title: "Question Set (Solved)"),
                      ),

                      const SizedBox(height: 12),

                      // Button B: Export Question Paper (Unsolved)
                      _buildExportButton(
                        text: "Export Exam Paper (Unsolved)",
                        icon: Icons.print,
                        color: Colors.black87,
                        // ✅ Calls _handleSmartExport
                        onPressed: () => _handleSmartExport(withAnswers: false, title: "Exam Paper"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 🔥 3. SMART BANNER AD (VIP LOGIC ADDED)
          // ✅ FIX: Use AdService() with brackets to access instance member
          ValueListenableBuilder<bool>(
            valueListenable: AdService().isFreeUserNotifier, // 👈 FIX IS HERE
            builder: (context, isFreeUser, child) {
              if (!isFreeUser) return const SizedBox.shrink(); // 🛑 VIPs k liye kuch mat dikhao
              
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

  Widget _buildExportButton({required String text, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          text, 
          textScaler: TextScaler.noScaling, 
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
    );
  }
}
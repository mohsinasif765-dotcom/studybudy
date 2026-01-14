import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:prepvault_ai/features/summary/models/summary_model.dart';
import 'package:prepvault_ai/features/summary/services/summary_service.dart';
import 'package:prepvault_ai/features/summary/widgets/translation_selector.dart';
import 'package:prepvault_ai/features/summary/widgets/summary_chat_drawer.dart';
import 'package:prepvault_ai/features/summary/widgets/summary_document_viewer.dart';
import 'package:prepvault_ai/core/widgets/ai_processing_overlay.dart';
import 'package:prepvault_ai/core/services/pdf_service.dart';
import 'package:prepvault_ai/features/history/services/history_service.dart';

// 🔥 IMPORTS FOR ADS
import 'package:prepvault_ai/core/widgets/smart_banner_ad.dart';
import 'package:prepvault_ai/core/services/ad_service.dart'; // ✅ Added AdService

class SummaryViewScreen extends StatefulWidget {
  final String summaryId;

  const SummaryViewScreen({super.key, required this.summaryId});

  @override
  State<SummaryViewScreen> createState() => _SummaryViewScreenState();
}

class _SummaryViewScreenState extends State<SummaryViewScreen> with SingleTickerProviderStateMixin {
  
  // ===========================================================================
  // 1️⃣ VARIABLES & CONTROLLERS
  // ===========================================================================
  
  final HistoryService _historyService = HistoryService();
  late TabController _tabController;
  
  bool _isLoading = true; 
  bool _isPdfGenerating = false;
  String _currentLang = "English";
  SummaryModel? _currentData; 
  String? _errorMessage;

  // ===========================================================================
  // 2️⃣ LIFECYCLE
  // ===========================================================================
  @override
  void initState() {
    super.initState();
    debugPrint("🟢 [SUMMARY_VIEW] Initialized with ID: ${widget.summaryId}");
    _tabController = TabController(length: 2, vsync: this);
    _fetchSummaryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    debugPrint("👋 [SUMMARY_VIEW] Screen Disposed");
    super.dispose();
  }

  // ===========================================================================
  // 3️⃣ DATA FETCHING LOGIC (Offline Safe)
  // ===========================================================================
  Future<void> _fetchSummaryData() async {
    debugPrint("🔄 [SUMMARY_VIEW] Fetching data from HistoryService...");

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final rawContent = await _historyService.getSummaryDataById(widget.summaryId);
      
      // 🔥 CRASH FIX: Null Check
      if (rawContent == null || rawContent.isEmpty) {
        throw "Empty Content from DB"; 
      }

      debugPrint("📦 [SUMMARY_VIEW] Data received (Length: ${rawContent.length})");
      _processData(rawContent);

    } catch (e) {
      debugPrint("❌ [SUMMARY_VIEW] Technical Error: $e"); 
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          // User friendly message based on error
          _errorMessage = "Unable to load summary.\nPlease check your internet connection.";
        });
      }
    }
  }

  void _processData(dynamic rawData) {
    debugPrint("🧩 [SUMMARY_VIEW] Processing data started...");

    try {
      Map<String, dynamic> finalMap;

      // =======================================================
      // STEP 1: PARSING RAW DATA
      // =======================================================
      debugPrint("🔍 [DEBUG] Step 1: Analyzing Raw Data Type: ${rawData.runtimeType}");

      if (rawData is Map) {
        finalMap = Map<String, dynamic>.from(rawData);
      } 
      else if (rawData is String) {
        try {
          final decoded = jsonDecode(rawData);
          if (decoded is Map) {
             finalMap = Map<String, dynamic>.from(decoded);
          } else {
             throw "Decoded JSON is not a Map";
          }
        } catch (e) {
          // Fallback if JSON is corrupt
          finalMap = {
            'summary_markdown': rawData.toString(),
            'title': 'Summary View',
            'emoji': '📄',
            'reading_time': '2 min',
            'key_points': [], 
            'introduction': '',
            'conclusion': ''
          };
        }
      } 
      else {
        throw "Unknown Data Format encountered: ${rawData.runtimeType}";
      }

      // =======================================================
      // STEP 2: FORMATTING FIXES
      // =======================================================
      if (!finalMap.containsKey('summary_markdown') && finalMap.containsKey('text')) {
          finalMap['summary_markdown'] = finalMap['text'];
      }

      // =======================================================
      // STEP 3: KEY POINTS FIX (Robust Cleaning)
      // =======================================================
      var rawKeyPoints = finalMap['key_points'];
      List<String> cleanPoints = [];

      if (rawKeyPoints != null && rawKeyPoints is List && rawKeyPoints.isNotEmpty) {
        for (var point in rawKeyPoints) {
          String p = point.toString().trim();
          if (!p.startsWith('#') && 
              !p.toLowerCase().contains('key points') && 
              !p.toLowerCase().contains('conclusion')) {
            cleanPoints.add(p);
          }
        }
      } 
      else {
        // Fallback Extraction logic...
        String fullText = finalMap['summary_markdown'].toString();
        if (fullText.contains('\n')) {
          List<String> lines = fullText.split('\n');
          for (var line in lines) {
            String trimmed = line.trim();
            if (trimmed.isEmpty) continue;
            if (trimmed.startsWith('#')) continue;
            if (trimmed.toLowerCase() == 'key points' || trimmed.toLowerCase() == 'conclusion') continue;
            
            bool isBullet = trimmed.startsWith('- ') || trimmed.startsWith('* ') || RegExp(r'^\d+\.').hasMatch(trimmed);
            if (!isBullet && trimmed.length > 150) continue;

            if (trimmed.length > 10 && trimmed.length < 300) {
              String cleanText = trimmed.replaceAll(RegExp(r'^[\-\*•\d\.]+\s*'), '').trim();
              cleanPoints.add(cleanText);
            }
          }
        }
        cleanPoints = cleanPoints.take(10).toList();
      }

      finalMap['key_points'] = cleanPoints;
      
      // =======================================================
      // STEP 4: MODEL GENERATION
      // =======================================================
      final model = SummaryModel.fromJson(finalMap);
      
      if (mounted) {
        setState(() {
          _currentData = model;
          _isLoading = false;
        });
        debugPrint("✅ [SUMMARY_VIEW] Data loaded successfully.");
      }

    } catch (e, stackTrace) {
      debugPrint("❌ [SUMMARY_VIEW] Parsing Error: $e"); 
      debugPrint("Trace: $stackTrace");
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Data is corrupt or invalid format.";
        });
      }
    }
  }

  // ===========================================================================
  // 4️⃣ FEATURES (Translation, Copy, PDF) - OFFLINE SAFE
  // ===========================================================================
  
  void _handleTranslation(String lang) async {
    if (lang == _currentLang) return;
    if (_currentData == null) return;

    // 🔥 Check mounted before strictly
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final translatedText = await AIProcessingOverlay.show<String>(
        context: context,
        asyncTask: (updateStatus) async {
          updateStatus("Translating to $lang...");
          // Agar internet nahi hoga to ye function throw karega
          return await SummaryService().translateSummary(_currentData!.summaryMarkdown, lang);
        },
      );

      if (translatedText != null && mounted) {
        setState(() {
          _currentLang = lang;
          _currentData = SummaryModel(
            title: _currentData!.title,
            emoji: _currentData!.emoji,
            readingTime: _currentData!.readingTime,
            keyPoints: _currentData!.keyPoints, 
            summaryMarkdown: translatedText,
          );
        });
      }
    } catch (e) {
      debugPrint("🔥 Translation Failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Translation failed. Internet required."), backgroundColor: Colors.red)
        );
      }
    }
  }

  void _handleCopy() {
    if (_currentData == null) return;
    Clipboard.setData(ClipboardData(text: _currentData!.summaryMarkdown));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard!"), backgroundColor: Colors.green));
  }

  Future<void> _handleDownloadPDF() async {
    if (_currentData == null) return;
    setState(() => _isPdfGenerating = true);
    try {
      await PdfService.generateSummaryDocument(_currentData!);
    } catch (e) {
      debugPrint("PDF Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not generate PDF."), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isPdfGenerating = false);
    }
  }

  // ===========================================================================
  // 5️⃣ UI BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      
      // 🔥 UPDATED: Column for Layout + Ad Banner
      body: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                
                if (_isLoading) {
                   return const Center(child: CircularProgressIndicator(color: AppColors.primaryStart));
                }

                // 🔥 ERROR STATE (RETRY ADDED)
                if (_errorMessage != null || _currentData == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 60),
                            const SizedBox(height: 16),
                            Text("Connection Issue", 
                              textScaler: TextScaler.noScaling,
                              style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold)
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage ?? "Something went wrong.", 
                              textAlign: TextAlign.center,
                              textScaler: TextScaler.noScaling,
                              style: GoogleFonts.outfit(color: Colors.black87, fontSize: 16),
                            ),
                            const SizedBox(height: 24),
                            
                            // 🔥 RETRY BUTTON
                            ElevatedButton.icon(
                              onPressed: _fetchSummaryData, // Calls function again
                              icon: const Icon(Icons.refresh),
                              label: const Text("Try Again", textScaler: TextScaler.noScaling),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryStart,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            TextButton(
                              onPressed: () => context.go('/dashboard'),
                              child: const Text("Go to Dashboard", textScaler: TextScaler.noScaling),
                            )
                        ],
                      ),
                    ),
                  );
                }

                // SUCCESS CONTENT
                final data = _currentData!;
                final wordCount = data.summaryMarkdown.split(RegExp(r'\s+')).length;
                final readingTime = (wordCount / 200).ceil();

                return NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverAppBar(
                      expandedHeight: 220,
                      pinned: true,
                      backgroundColor: AppColors.primaryStart,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.go('/dashboard'),
                      ),
                      actions: [
                        IconButton(icon: const Icon(Icons.copy, color: Colors.white), onPressed: _handleCopy),
                        IconButton(
                          icon: _isPdfGenerating 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                            : const Icon(Icons.download, color: Colors.white), 
                          onPressed: _isPdfGenerating ? null : _handleDownloadPDF,
                        ),
                        IconButton(
                          icon: const Icon(Icons.translate, color: Colors.white),
                          onPressed: () => showModalBottomSheet(
                            context: context, 
                            isScrollControlled: true, 
                            backgroundColor: Colors.transparent, 
                            builder: (c) => TranslationSelector(currentLanguage: _currentLang, onSelect: _handleTranslation),
                          ),
                        ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        titlePadding: const EdgeInsets.only(left: 20, bottom: 60),
                        title: Text(
                          data.title.length > 20 ? "${data.title.substring(0, 20)}..." : data.title, 
                          textScaler: TextScaler.noScaling, 
                          style: GoogleFonts.spaceGrotesk(fontSize: 16, color: Colors.white)
                        ),
                        background: Container(
                          decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryStart, AppColors.primaryEnd])),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(data.emoji, textScaler: TextScaler.noScaling, style: const TextStyle(fontSize: 40)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.24), // ✅ Safe Opacity
                                    borderRadius: BorderRadius.circular(20)
                                  ),
                                  child: Text(
                                    "$readingTime min read", 
                                    textScaler: TextScaler.noScaling,
                                    style: const TextStyle(color: Colors.white)
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                      bottom: TabBar(
                        controller: _tabController,
                        indicatorColor: Colors.white,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white60,
                        tabs: const [Tab(text: "Key Points"), Tab(text: "Full Document")],
                      ),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: Key Points
                      data.keyPoints.isEmpty 
                        ? Center(child: Text("No Key Points extracted.", textScaler: TextScaler.noScaling, style: GoogleFonts.outfit(color: Colors.grey)))
                        : Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 850), 
                              child: ListView.builder(
                                padding: const EdgeInsets.all(20), 
                                itemCount: data.keyPoints.length, 
                                itemBuilder: (context, index) => _buildKeyPointItem(index, data.keyPoints[index])
                              )
                            )
                          ),
                      // TAB 2: Full Document
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900), 
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 100), 
                            child: SummaryDocumentViewer(
                              fileName: "Document Content", 
                              content: data.summaryMarkdown, 
                              wordCount: wordCount, 
                              readingTime: readingTime
                            )
                          )
                        )
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // 🔥🔥 AD BANNER AT BOTTOM (VIP SAFE) 🔥🔥
          // ✅ FIX: Using ValueListenableBuilder for VIP Logic
          ValueListenableBuilder<bool>(
            valueListenable: AdService().isFreeUserNotifier, // ✅ Logic Fix
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

      floatingActionButton: _currentData != null ? FloatingActionButton.extended(
        onPressed: () {
            // 🔥 Wrap Chat in try-catch logic just in case
            try {
              showGeneralDialog(
                context: context,
                barrierDismissible: true,
                barrierLabel: "Chat",
                transitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (context, a1, a2) => Align(alignment: Alignment.centerRight, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: SummaryChatDrawer(documentContext: _currentData!.summaryMarkdown))),
                transitionBuilder: (context, a1, a2, child) => SlideTransition(position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: a1, curve: Curves.easeOutQuart)), child: child),
              );
            } catch (e) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat unavailable offline.")));
            }
        },
        backgroundColor: AppColors.primaryStart,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text("Ask AI", textScaler: TextScaler.noScaling),
      ) : null,
    );
  }

  // ===========================================================================
  // 6️⃣ HELPER WIDGETS
  // ===========================================================================
  Widget _buildKeyPointItem(int index, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100)
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8), 
            decoration: BoxDecoration(
              color: AppColors.primaryStart.withOpacity(0.1),
              shape: BoxShape.circle
            ), 
            child: Text(
              "${index + 1}", 
              textScaler: TextScaler.noScaling,
              style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryStart)
            )
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text, 
              textScaler: TextScaler.noScaling, 
              style: GoogleFonts.outfit(fontSize: 16, height: 1.6, color: Colors.black87)
            )
          ),
        ],
      ),
    );
  }
}
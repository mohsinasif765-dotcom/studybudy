import 'dart:convert'; 
import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:prepvault_ai/features/quiz/models/quiz_model.dart';
import 'package:prepvault_ai/features/history/services/history_service.dart';
import 'package:prepvault_ai/features/history/models/history_model.dart'; // 🔥 Model Import Zaroori hai

class RecentActivityList extends StatefulWidget {
  final VoidCallback? onViewAll; 

  const RecentActivityList({super.key, this.onViewAll});

  @override
  State<RecentActivityList> createState() => _RecentActivityListState();
}

class _RecentActivityListState extends State<RecentActivityList> {
  final HistoryService _historyService = HistoryService();
  String? _processingId; 
  
  // 🔥 Data State
  List<Map<String, dynamic>> _localData = [];
  StreamSubscription? _streamSub;

  @override
  void initState() {
    super.initState();
    _loadInitialData(); // ⚡ 1. Load from Hive immediately
    _setupRealtimeListener(); // 📡 2. Listen for Live Updates
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // 1️⃣ LOAD FROM HIVE (OFFLINE FIRST)
  // ===========================================================================
  Future<void> _loadInitialData() async {
    try {
      // HistoryService ab Hive use kar raha hai, to yeh instant hoga
      final List<HistoryItem> cachedItems = await _historyService.getHistory();
      
      if (mounted && cachedItems.isNotEmpty) {
        setState(() {
          // Top 4 items uthao aur UI ke liye Map me convert kro
          _localData = cachedItems.take(4).map((e) => e.toJson()).toList();
        });
        debugPrint("🚀 [RECENT] Loaded ${_localData.length} items from Hive Cache.");
      }
    } catch (e) {
      debugPrint("⚠️ Offline Load Warning: $e");
    }
  }

  // ===========================================================================
  // 2️⃣ SETUP STREAM (ONLINE UPDATES)
  // ===========================================================================
  void _setupRealtimeListener() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _streamSub = Supabase.instance.client
        .from('study_history')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(4)
        .listen((data) {
          if (mounted) {
            setState(() {
              _localData = data; // Live update UI
            });
            // Optional: Background mein Hive update bhi kar sakte hain agar chahein
          }
        }, onError: (e) {
          debugPrint("⚠️ Stream Error (Offline?): $e");
          // Stream fail hone par purana Hive data hi show hota rahega
        });
  }

  // ===========================================================================
  // 1️⃣ HELPER METHODS
  // ===========================================================================
  String _formatTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return "Just now";
      if (difference.inMinutes < 60) return "${difference.inMinutes} min ago";
      if (difference.inHours < 24) return "${difference.inHours} hr ago";
      return DateFormat('MMM d').format(dateTime);
    } catch (e) {
      return "Recent";
    }
  }

  // 🛠️ Extractors (Safe)
  List<dynamic> _extractList(dynamic content) {
    try {
      if (content == null) return [];
      dynamic parsed = content;
      if (parsed is String) {
        try { parsed = jsonDecode(parsed); } catch (_) { return []; }
      }
      if (parsed is Map) {
        if (parsed.containsKey('data') && parsed['data'] is List) {
          return parsed['data'];
        }
        return []; 
      } else if (parsed is List) {
        return parsed;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 🅰️ QUIZ PARSER
  List<QuizQuestion> _parseMcqData(dynamic content) {
    try {
      final list = _extractList(content);
      return list.map((e) => QuizQuestion.fromJson(e)).toList();
    } catch (e) { return []; }
  }

  // 🅱️ THEORY PARSER
  List<QuizQuestion> _parseTheoryData(dynamic content) {
    try {
      final list = _extractList(content);
      return list.map((e) => QuizQuestion.fromTheoryJson(e)).toList();
    } catch (e) { return []; }
  }

  // 🆎 SUMMARY PARSER
  String _parseSummaryData(dynamic content) {
    try {
       if (content == null) return '';
       dynamic parsed = content;
       if (parsed is String) return parsed; 
       if (parsed is Map) {
         return parsed['summary_markdown']?.toString() ?? 
                parsed['text']?.toString() ?? 
                parsed['content']?.toString() ?? '';
       }
       return '';
    } catch (e) { return ''; }
  }

  // ===========================================================================
  // 2️⃣ NAVIGATION HANDLER (With Loader)
  // ===========================================================================
  Future<void> _handleItemTap(Map<String, dynamic> file) async {
    final String id = file['id'];
    
    if (_processingId != null) return;

    setState(() => _processingId = id);

    // Timeout safety
    Timer(const Duration(seconds: 2), () {
      if (mounted && _processingId == id) {
        setState(() => _processingId = null);
      }
    });

    final String type = file['type'] ?? 'unknown';
    final dynamic content = file['content'];
    final String title = file['title'] ?? 'Untitled';

    debugPrint("🚀 [TAP] Processing: $title ($type)");

    await Future.delayed(const Duration(milliseconds: 50));

    try {
      if (!mounted) return;

      // --- 1. QUIZ ---
      if (type == 'quiz') {
        final mcqs = _parseMcqData(content);
        if (mcqs.isNotEmpty) {
          _historyService.cacheDataInstantly(id, mcqs, title: title);
          if (mounted) context.push('/quiz-dashboard/$id');
        } else {
          _showErrorSnackBar("Quiz data is empty.");
        }
      } 
      
      // --- 2. THEORY ---
      else if (type == 'questionset') {
        final theoryQuestions = _parseTheoryData(content); 
        if (theoryQuestions.isNotEmpty) {
          _historyService.cacheQuestionSetInstantly(id, theoryQuestions, title: title);
          if (mounted) context.push('/questionset-dashboard/$id');
        } else {
          _showErrorSnackBar("Question set data is empty.");
        }
      } 
      
      // --- 3. SUMMARY ---
      else if (type == 'summary') {
        final summaryText = _parseSummaryData(content);
        if (summaryText.isNotEmpty) {
          _historyService.cacheSummaryInstantly(id, summaryText, title: title);
          if (mounted) context.push('/summary/$id');
        } else {
          _showErrorSnackBar("Summary content is unavailable.");
        }
      } 
      
      else {
        _showErrorSnackBar("Unknown file type.");
      }

    } catch (e) {
      debugPrint("❌ Navigation Error: $e");
      _showErrorSnackBar("Could not open this file.");
    }
  }

  // ===========================================================================
  // 3️⃣ MAIN UI BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Recent Activity", style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            TextButton(
              onPressed: widget.onViewAll,
              child: Text("View All", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.primaryStart)),
            )
          ],
        ),
        const SizedBox(height: 10),

        _localData.isEmpty
            ? Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Center(
                  child: Text(
                    "No recent activity", 
                    style: GoogleFonts.outfit(color: Colors.grey)
                  )
                )
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _localData.length,
                itemBuilder: (context, index) {
                  final file = _localData[index];
                  
                  final rawStatus = (file['status'] ?? 'pending').toString().toLowerCase();
                  final isCompleted = rawStatus == 'completed';
                  final isError = rawStatus == 'failed' || rawStatus == 'error';
                  final isProcessing = !isCompleted && !isError;
                  
                  final type = file['type'];
                  final isSummary = type == 'summary';
                  final isQuestionSet = type == 'questionset'; 

                  final isItemLoading = _processingId == file['id'];

                  Color iconBgColor;
                  Color iconColor;
                  IconData iconData;

                  if (isError) {
                    iconBgColor = Colors.red.withValues(alpha: 0.1); iconColor = Colors.red; iconData = Icons.error_outline;
                  } else if (isSummary) {
                    iconBgColor = Colors.indigo.withValues(alpha: 0.1); iconColor = Colors.indigo; iconData = Icons.article_outlined;
                  } else if (isQuestionSet) {
                    iconBgColor = Colors.teal.withValues(alpha: 0.1); iconColor = Colors.teal; iconData = Icons.history_edu_outlined;
                  } else {
                    iconBgColor = Colors.purple.withValues(alpha: 0.1); iconColor = Colors.purple; iconData = Icons.quiz_outlined;
                  }

                  return GestureDetector(
                    onTap: () {
                      if (isCompleted) {
                        _handleItemTap(file); 
                      } else if (isError) {
                        _showErrorSnackBar("Processing failed.");
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Processing... Please wait"))
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isError ? Colors.red.shade100 : Colors.grey.shade200, 
                          width: isError ? 1.5 : 1
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(10)),
                            child: isProcessing 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                                : Icon(iconData, color: iconColor, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file['title'] ?? 'Untitled',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: isError ? Colors.red.shade900 : Colors.black87),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      isError ? "Failed" : (isProcessing ? "Analyzing..." : "Ready"),
                                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: isError ? Colors.red : (isProcessing ? Colors.blue : Colors.green)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text("• ${_formatTime(file['created_at'])}", style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                                    
                                    if (isQuestionSet && isCompleted) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(4)),
                                        child: Text("THEORY", style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.teal)),
                                      )
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          if (isCompleted) 
                            isItemLoading
                              ? SizedBox(
                                  width: 20, 
                                  height: 20, 
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5, 
                                    valueColor: AlwaysStoppedAnimation<Color>(iconColor)
                                  )
                                )
                              : Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    setState(() => _processingId = null); 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.info_outline, color: Colors.white), const SizedBox(width: 10), Expanded(child: Text(message))]),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
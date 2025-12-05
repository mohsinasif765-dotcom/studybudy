import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'package:studybudy_ai/core/theme/app_colors.dart';
// 👇 Ensure yeh imports sahi hon
import '../models/history_model.dart';
import '../services/history_service.dart';
class HistoryViewScreen extends StatefulWidget {
  const HistoryViewScreen({super.key});

  @override
  State<HistoryViewScreen> createState() => _HistoryViewScreenState();
}

class _HistoryViewScreenState extends State<HistoryViewScreen> {
  final HistoryService _service = HistoryService();
  late Future<List<HistoryItem>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  Future<void> _refreshHistory() async {
    setState(() {
      _historyFuture = _service.getHistory();
    });
  }

  void _deleteItem(String id) async {
    await _service.deleteItem(id);
    _refreshHistory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Item deleted")));
    }
  }

  // 👇 NAVIGATION LOGIC FIXED
  void _openItem(HistoryItem item) {
    if (item.type == 'summary') {
      // Summary screen par bhejo (Content string hona chahiye)
      // Note: Backend se 'content' agar JSON hai to usay string mein convert karein ya format karein
      // Filhal hum content ko direct pass kar rahe hain
      context.push('/summary', extra: item.content['summary_markdown'] ?? "No Content");
    } else {
      // Quiz ke liye abhi humein QuizPlayScreen direct open karna padega questions ke sath
      // Filhal ek message dikha dete hain
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Quiz retake feature coming soon!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Library", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshHistory,
        color: AppColors.primaryStart,
        child: FutureBuilder<List<HistoryItem>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            
            // 1. Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                itemBuilder: (_, __) => _buildSkeletonItem(),
              );
            }

            // 2. Error
            if (snapshot.hasError) {
              return Center(child: Text("Error loading history", style: GoogleFonts.outfit(color: Colors.red)));
            }

            final items = snapshot.data ?? [];

            // 3. Empty
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                      child: const Icon(Icons.history, size: 40, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Text("No history yet", style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Generate a summary to see it here.", style: GoogleFonts.outfit(color: Colors.grey)),
                  ],
                ),
              );
            }

            // 4. List
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildHistoryCard(items[index]);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistoryCard(HistoryItem item) {
    final isSummary = item.type == 'summary';
    final dateStr = DateFormat('MMM d, h:mm a').format(item.createdAt);

    return Slidable(
      key: ValueKey(item.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _deleteItem(item.id),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
            borderRadius: BorderRadius.circular(16),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => _openItem(item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: isSummary ? Colors.indigo.shade50 : Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSummary ? Icons.article_outlined : Icons.quiz_outlined,
                  color: isSummary ? Colors.indigo : Colors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(dateStr, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500)),
                        const SizedBox(width: 12),
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                          child: Text(item.originalFileName, style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonItem() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 80,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
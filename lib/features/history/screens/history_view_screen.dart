import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/history_model.dart';
import '../services/history_service.dart';

// 👇 Custom Imports
import 'package:prepvault_ai/core/widgets/smart_banner_ad.dart';
import 'package:prepvault_ai/core/services/ad_service.dart';
import 'package:prepvault_ai/core/widgets/custom_search_header.dart';

class HistoryViewScreen extends StatefulWidget {
  const HistoryViewScreen({super.key});

  @override
  State<HistoryViewScreen> createState() => _HistoryViewScreenState();
}

class _HistoryViewScreenState extends State<HistoryViewScreen> {
  final HistoryService _service = HistoryService();
  final TextEditingController _searchController = TextEditingController();
  
  List<HistoryItem> _allItems = [];
  List<HistoryItem> _filteredItems = [];
  bool _isLoading = true;
  bool _hasError = false; 
  String _selectedFilter = 'All'; 

  String? _openingItemId; 

  @override
  void initState() {
    super.initState();
    _initAds();
    _loadHistory();
    _searchController.addListener(_filterList);
  }

  Future<void> _initAds() async {
    try {
      await AdService().updateSubscriptionStatus();
      if (mounted) setState(() {}); 
    } catch (e) {
      debugPrint("⚠️ Ad Init Error: $e");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (_allItems.isEmpty) {
        if (mounted) setState(() { _isLoading = true; _hasError = false; });
    }

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final items = await _service.fetchLatestHistory(userId, onlyCompleted: true);
        if (mounted) {
          setState(() {
            _allItems = items;
            _filterList(); 
            _isLoading = false;
            _hasError = false;
          });
        }
      } else {
         if(mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_allItems.isEmpty) _hasError = true; 
        });
      }
    }
  }

  void _filterList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _allItems.where((item) {
        final matchesSearch = item.title.toLowerCase().contains(query) || 
                             item.originalFileName.toLowerCase().contains(query);
        
        final matchesType = _selectedFilter == 'All' || 
                            (_selectedFilter == 'Summary' && item.type == 'summary') ||
                            (_selectedFilter == 'Quiz' && item.type == 'quiz') ||
                            (_selectedFilter == 'Question Set' && item.type == 'questionset');

        return matchesSearch && matchesType;
      }).toList();
    });
  }

  void _deleteItem(String id) async {
    final deletedItemIndex = _allItems.indexWhere((i) => i.id == id);
    if (deletedItemIndex == -1) return;
    final deletedItem = _allItems[deletedItemIndex];

    setState(() {
      _allItems.removeAt(deletedItemIndex);
      _filterList();
    });

    try {
      await _service.deleteItem(id);
    } catch(e) {
      if (mounted) {
        setState(() {
          _allItems.insert(deletedItemIndex, deletedItem);
          _filterList();
        });
      }
    }
  }

  /// ✅ FIXED NAVIGATION LOGIC
  Future<void> _openItem(HistoryItem item) async {
    if (_openingItemId != null) return;
    
    setState(() => _openingItemId = item.id);

    try {
      // Navigation start
      if (item.type == 'summary') {
        context.push('/summary/${item.id}');
      } else if (item.type == 'quiz') {
        context.push('/quiz-dashboard/${item.id}');
      } else if (item.type == 'questionset') {
        context.push('/questionset-dashboard/${item.id}');
      }

      // 💡 HUM WAIT NAHI KARENGE. 
      // Bas 1.5 second ka delay denge taake animation smooth ho aur spinner khud hi off ho jaye.
      // Is se agar user Dashboard se bhi wapis aye to screen stuck nahi hogi.
      await Future.delayed(const Duration(milliseconds: 1500));
    } finally {
      if (mounted) {
        setState(() => _openingItemId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text("My Library", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black), 
            onPressed: () {
              setState(() => _isLoading = true);
              _loadHistory(); 
            },
          )
        ],
      ),
      body: Column(
        children: [
          CustomSearchHeader(
            controller: _searchController,
            hintText: "Search library...",
            categories: const ["All", "Summary", "Quiz", "Question Set"],
            selectedCategory: _selectedFilter,
            onCategorySelect: (category) {
              setState(() {
                _selectedFilter = category;
                _filterList();
              });
            },
          ),

          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: RefreshIndicator(
                  onRefresh: _loadHistory,
                  color: AppColors.primaryStart,
                  child: _isLoading
                      ? ListView.builder(padding: const EdgeInsets.all(16), itemCount: 5, itemBuilder: (_, __) => _buildSkeletonItem())
                      : _hasError 
                        ? _buildErrorView() 
                        : _filteredItems.isEmpty
                            ? _buildEmptyView()
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredItems.length,
                                separatorBuilder: (c, i) => const SizedBox(height: 12),
                                itemBuilder: (context, index) => _buildHistoryCard(_filteredItems[index]),
                              ),
                ),
              ),
            ),
          ),

          ValueListenableBuilder<bool>(
            valueListenable: AdService().isFreeUserNotifier,
            builder: (context, isFree, child) {
              if (isFree) {
                return const SafeArea(top: false, child: SmartBannerAd());
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---
  
  Widget _buildEmptyView() {
    bool isSearchActive = _searchController.text.isNotEmpty;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isSearchActive ? Icons.search_off : Icons.history_edu, size: 60, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                  isSearchActive ? "No results found" : "Your library is empty", 
                  style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 18, fontWeight: FontWeight.bold)
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 60, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text("Could not load history", style: GoogleFonts.outfit(color: Colors.grey.shade800, fontSize: 16)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _loadHistory(),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryStart, foregroundColor: Colors.white),
            child: const Text("Retry"),
          )
        ],
      ),
    );
  }

  Widget _buildHistoryCard(HistoryItem item) {
    final dateStr = DateFormat('MMM d, h:mm a').format(item.createdAt);
    IconData iconData = Icons.article_outlined;
    Color iconColor = Colors.indigo;
    Color bgColor = Colors.indigo.shade50;

    if (item.type == 'quiz') {
      iconData = Icons.quiz_outlined;
      iconColor = Colors.purple;
      bgColor = Colors.purple.shade50;
    } else if (item.type == 'questionset') {
      iconData = Icons.assignment_turned_in_outlined;
      iconColor = Colors.teal;
      bgColor = Colors.teal.shade50;
    }

    return Slidable(
      key: ValueKey(item.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _deleteItem(item.id),
            backgroundColor: Colors.red,
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
            color: Colors.white, 
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                child: Icon(iconData, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("$dateStr • ${item.originalFileName}", maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              if (_openingItemId == item.id)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryStart))
              else
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
      child: Container(height: 80, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
    );
  }
}
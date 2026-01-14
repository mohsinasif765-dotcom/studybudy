import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Model Import
import '../models/official_test_model.dart';

// Custom Imports
import 'package:prepvault_ai/core/widgets/smart_banner_ad.dart';
import 'package:prepvault_ai/core/utils/credit_manager.dart';
import 'package:prepvault_ai/core/services/ad_service.dart';

// ✅ Custom Search Header Import
import 'package:prepvault_ai/core/widgets/custom_search_header.dart';

class OfficialStoreScreen extends StatefulWidget {
  const OfficialStoreScreen({super.key});

  @override
  State<OfficialStoreScreen> createState() => _OfficialStoreScreenState();
}

class _OfficialStoreScreenState extends State<OfficialStoreScreen> {
  // --- VARIABLES ---
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _requestController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<OfficialTestModel> _tests = [];
  List<String> _allCategories = ['All'];

  Set<String> _unlockedTestIds = {};

  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  bool _isSendingRequest = false;

  // User Status
  bool _isVip = false;
  String? _userCountryCode;

  final int _pageSize = 10;
  String _selectedCategory = 'All';

  // ===========================================================================
  // 1️⃣ INIT & CONFIGURATION
  // ===========================================================================
  @override
  void initState() {
    super.initState();
    debugPrint("🚀 Official Store Initializing...");

    _initAdsAndUserStatus();
    _loadCacheData();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMoreData) _loadMoreTests();
      }
    });
    _searchController.addListener(() { setState(() {}); });
  }

  Future<void> _initAdsAndUserStatus() async {
    try {
      await AdService().updateSubscriptionStatus();
      if (mounted) setState(() {});
      AdService().loadRewardedAd();
      _fetchUserProfileAndFirstPage();
    } catch (e) {
      _fetchUserProfileAndFirstPage();
    }
  }

  // ===========================================================================
  // 2️⃣ OFFLINE CACHE LOGIC
  // ===========================================================================
  Future<void> _loadCacheData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String? cachedList = prefs.getString('cached_official_tests');
      if (cachedList != null) {
        final List<dynamic> decoded = jsonDecode(cachedList);
        if (mounted) {
          setState(() {
            _tests = decoded.map((e) => OfficialTestModel.fromJson(e)).toList();
            final cats = _tests.map((e) => e.category).toSet().toList();
            _allCategories = ['All', ...cats];
            _isLoadingInitial = false;
          });
        }
      }

      final List<String>? cachedUnlocks = prefs.getStringList('cached_unlocks');
      if (cachedUnlocks != null) {
        if (mounted) setState(() => _unlockedTestIds = cachedUnlocks.toSet());
      }
    } catch (e) {
      debugPrint("⚠️ Cache Load Error: $e");
    }
  }

  Future<void> _saveCacheData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedList = jsonEncode(_tests.map((e) => e.toJson()).toList());
      await prefs.setString('cached_official_tests', encodedList);
      await prefs.setStringList('cached_unlocks', _unlockedTestIds.toList());
    } catch (e) {
      debugPrint("⚠️ Save Cache Failed: $e");
    }
  }

  // ===========================================================================
  // 3️⃣ ONLINE DATA FETCHING
  // ===========================================================================
  Future<void> _fetchUserProfileAndFirstPage() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      if (userId != null) {
         final profileData = await _supabase
            .from('profiles')
            .select('country, is_vip')
            .eq('id', userId)
            .single();
            
         _userCountryCode = profileData['country'] ?? 'PK';
         _isVip = profileData['is_vip'] ?? false;
         
         if (!_isVip) {
          final unlockedData = await _supabase
              .from('official_test_unlocks')
              .select('test_id')
              .eq('user_id', userId);

          final newUnlocks = (unlockedData as List).map((e) => e['test_id'].toString()).toSet();
          if (mounted) {
            setState(() { _unlockedTestIds = newUnlocks; });
          }
        }
      } else {
        _userCountryCode = 'PK';
      }

      if (!mounted) return;
      
      await _fetchCategories();
      await _loadMoreTests(isRefresh: true);

    } catch (e) {
      debugPrint("❌ Network Error: $e");
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await _supabase
          .from('tests')
          .select('category')
          .or('country_code.eq.$_userCountryCode,country_code.eq.ALL');

      if (response is List) {
        final Set<String> uniqueCats = {};
        for (var item in response) {
          if (item['category'] != null) uniqueCats.add(item['category']);
        }

        if (mounted) {
          setState(() {
            _allCategories = ['All', ...uniqueCats.toList()..sort()];
          });
        }
      }
    } catch (e) {
      debugPrint("⚠️ Category Fetch Error: $e");
    }
  }

  Future<void> _loadMoreTests({bool isRefresh = false}) async {
    if (isRefresh) {
      if (_tests.isEmpty) setState(() => _isLoadingInitial = true);
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final int start = isRefresh ? 0 : _tests.length;
      final int end = start + _pageSize - 1;

      var queryBuilder = _supabase
          .from('tests')
          .select('id, title, category, country_code, credit_cost, created_at, part_no, test_questions(count)')
          .or('country_code.eq.$_userCountryCode,country_code.eq.ALL');

      if (_selectedCategory != 'All') {
        queryBuilder = queryBuilder.eq('category', _selectedCategory);
      }

      final response = await queryBuilder
          .order('created_at', ascending: false)
          .range(start, end);

      if (!mounted) return;

      final newTests = (response as List).map((e) => OfficialTestModel.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          if (isRefresh) {
             _tests = newTests;
             _hasMoreData = true;
          } else {
             _tests.addAll(newTests);
          }

          if (newTests.length < _pageSize) _hasMoreData = false;

          _isLoadingInitial = false;
          _isLoadingMore = false;
        });

        _saveCacheData();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingInitial = false);
      debugPrint("⚠️ Load More Failed: $e");
    }
  }

  // 🔥 IMPROVED SMART SEARCH LOGIC (Less Strict)
  List<OfficialTestModel> get _visibleTests {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return _tests;

    // 1. Pehle exact matches ya "starts with" dekho
    final directMatches = _tests.where((t) {
      final title = t.title.toLowerCase();
      final cat = t.category.toLowerCase();
      return title.contains(query) || cat.contains(query);
    }).toList();

    if (directMatches.isNotEmpty) return directMatches;

    // 2. Agar kuch na mile, to words break karke "Fuzzy" search karo
    final queryWords = query.split(' ');
    return _tests.where((t) {
      final title = t.title.toLowerCase();
      // Agar title mein query ka koi bhi ek word mil jaye to dikha do
      return queryWords.any((word) => word.length > 2 && title.contains(word));
    }).toList();
  }

  // ===========================================================================
  // 4️⃣ REQUEST LOGIC
  // ===========================================================================
  Future<void> _sendRequest() async {
    final text = _requestController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSendingRequest = true);

    try {
      final user = _supabase.auth.currentUser;
      final data = {
        'request_text': text,
        'user_id': user?.id,
      };

      await _supabase.from('official_test_requests').insert(data);

      if (mounted) {
        _requestController.clear();
        FocusScope.of(context).unfocus(); // Request ke baad keyboard band
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request sent successfully!")));
      }
    } catch (e) {
      debugPrint("❌ Request Failed: $e");
    } finally {
      if (mounted) setState(() => _isSendingRequest = false);
    }
  }

  // ===========================================================================
  // 5️⃣ TEST START & CREDIT LOGIC
  // ===========================================================================
  Future<void> _handleTestTap(OfficialTestModel item) async {
    if (_isVip || _unlockedTestIds.contains(item.id) || item.creditCost <= 0) {
      _startTestDirectly(item);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: AppColors.primaryStart))
    );

    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from('profiles').select('credits_remaining').eq('id', userId).single();
      final int balance = profile['credits_remaining'] ?? 0;

      if (!mounted) return;
      Navigator.pop(context);

      if (balance < item.creditCost) {
        bool creditsAdded = await CreditManager.canProceed(
          context: context,
          requiredCredits: item.creditCost,
          availableCredits: balance
        );

        if (creditsAdded) {
          _handleTestTap(item);
        }
        return;
      }

      _showPurchaseDialog(item, balance, item.creditCost);

    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  Future<void> _startTestDirectly(OfficialTestModel testItem) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: AppColors.primaryStart))
    );

    try {
      final response = await _supabase
          .from('test_questions')
          .select('questions(*)')
          .eq('test_id', testItem.id);

      List<dynamic> rawQuestions = [];
      if (response is List) {
        for (var item in response) {
          if (item['questions'] != null) {
            rawQuestions.add(item['questions']);
          }
        }
      }

      if (rawQuestions.isEmpty) {
        if(mounted) {
             Navigator.pop(context);
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No questions found in this test yet.")));
        }
        return;
      }

      final List<Map<String, dynamic>> formattedQuestions = rawQuestions.map((q) {
        List<String> opts = [];
        if (q['options'] is String) {
          try {
            opts = List<String>.from(jsonDecode(q['options']));
          } catch (e) { opts = []; }
        } else if (q['options'] is List) {
          opts = List<String>.from(q['options']);
        }

        String correctText = q['correct_option'] ?? '';
        int correctIndex = opts.indexOf(correctText);
        if (correctIndex == -1) correctIndex = 0;

        return {
          'question': q['question_text'],
          'options': opts,
          'correctAnswerIndex': correctIndex,
          'explanation': q['explanation'] ?? '',
        };
      }).toList();

      if (!mounted) return;
      Navigator.pop(context);

      if (mounted) {
        context.push('/quiz-player', extra: {
          'quizData': formattedQuestions,
          'title': testItem.title,
          'id': testItem.id,
          'isOfficial': true
        });
      }

    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _showPurchaseDialog(OfficialTestModel item, int balance, int cost) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Unlock Test? 🔓"),
        content: Text("This will cost $cost Credits."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _processPurchase(item, cost, balance);
            },
            child: const Text("Unlock")
          )
        ],
      ),
    );
  }

  Future<void> _processPurchase(OfficialTestModel item, int cost, int currentBalance) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('profiles').update({'credits_remaining': currentBalance - cost}).eq('id', userId);
      await _supabase.from('official_test_unlocks').insert({'user_id': userId, 'test_id': item.id, 'cost_paid': cost});

      if (!mounted) return;
      setState(() => _unlockedTestIds.add(item.id));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cached_unlocks', _unlockedTestIds.toList());

      if (mounted) Navigator.pop(context);
      _startTestDirectly(item);

    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  // ===========================================================================
  // 6️⃣ UI BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    // 🔥 KEYBOARD DISMISS LOGIC: GestureDetector wrapped around everything
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FC),
        appBar: AppBar(
          title: Text("Exam Center", style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.black87)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black87),
          actions: [
             if (_userCountryCode != null)
               Padding(
                 padding: const EdgeInsets.only(right: 16.0),
                 child: Center(
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                     child: Text(_userCountryCode!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                   ),
                 ),
               )
          ],
        ),

        body: Column(
          children: [
            CustomSearchHeader(
              controller: _searchController,
              hintText: "Search exams...",
              categories: _allCategories,
              selectedCategory: _selectedCategory,
              showFilter: true,
              onCategorySelect: (cat) {
                setState(() {
                  _selectedCategory = cat;
                  _tests.clear();
                  _loadMoreTests(isRefresh: true);
                });
              },
            ),

            Expanded(
              child: _isLoadingInitial
                  ? _buildShimmerList()
                  : _visibleTests.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _visibleTests.length + (_hasMoreData ? 1 : 0),
                          separatorBuilder: (c, i) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == _visibleTests.length) {
                              return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: AppColors.primaryStart)));
                            }
                            return _buildTestCard(_visibleTests[index]);
                          },
                        ),
            ),
          ],
        ),

        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             ValueListenableBuilder<bool>(
              valueListenable: AdService().isFreeUserNotifier,
              builder: (context, isFreeUser, child) {
                if (!isFreeUser) return const SizedBox.shrink();
                return const SafeArea(
                  top: false,
                  bottom: false,
                  child: SmartBannerAd(),
                );
              },
            ),
            
            RequestBottomBox(
              controller: _requestController,
              isSending: _isSendingRequest,
              onSend: _sendRequest,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard(OfficialTestModel item) {
    final bool isUnlocked = _isVip || _unlockedTestIds.contains(item.id) || item.creditCost <= 0;

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8, offset: const Offset(0, 4))]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            FocusScope.of(context).unfocus(); // Tap par keyboard band
            _handleTestTap(item);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: isUnlocked ? Colors.green.shade50 : AppColors.primaryStart.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Icon(isUnlocked ? Icons.play_arrow_rounded : Icons.lock_outline_rounded, color: isUnlocked ? Colors.green : AppColors.primaryStart, size: 26)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 6),
                      
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          if (item.partNo > 1) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                              child: Text("Part ${item.partNo}", style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                            ),
                            const SizedBox(width: 6),
                          ],
                          
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
                            child: Text(item.category.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                          ),
                          const SizedBox(width: 8),
                          Text("${item.totalQuestions} Qs", style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500)),
                        ]),
                      ),
                    ],
                  ),
                ),
                if (!isUnlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.primaryStart, borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      const Icon(Icons.flash_on_rounded, size: 14, color: Colors.yellow),
                      const SizedBox(width: 4),
                      Text("${item.creditCost}", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                  )
                else
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerList() => ListView.builder(itemCount: 6, itemBuilder: (_,__) => Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.white, child: Container(height: 80, margin: const EdgeInsets.only(bottom: 10), color: Colors.white)));
  Widget _buildEmptyState() => const Center(child: Text("No tests found"));
}

class RequestBottomBox extends StatelessWidget {
  final TextEditingController controller; final bool isSending; final VoidCallback onSend;
  const RequestBottomBox({super.key, required this.controller, required this.isSending, required this.onSend});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))]),
      child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Can't find your test?", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)), const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: controller, decoration: InputDecoration(hintText: "Request it here...", filled: true, fillColor: AppColors.primaryStart.withValues(alpha: 0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)))),
          const SizedBox(width: 10),
          GestureDetector(onTap: isSending ? null : onSend, child: CircleAvatar(backgroundColor: AppColors.primaryStart, child: isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.send, color: Colors.white)))
        ])
      ])),
    );
  }
}
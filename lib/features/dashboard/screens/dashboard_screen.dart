import 'dart:async';
import 'dart:ui'; 
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';

// Screens
import 'package:prepvault_ai/features/dashboard/screens/home_view.dart';
import 'package:prepvault_ai/features/history/screens/history_view_screen.dart';
import 'package:prepvault_ai/features/dashboard/screens/settings_view.dart';
import 'package:prepvault_ai/features/store/screens/official_store_screen.dart';

// Services
import 'package:prepvault_ai/features/history/services/history_service.dart';

// Widgets
import 'package:prepvault_ai/features/dashboard/widgets/announcement_banner.dart';
import 'package:prepvault_ai/features/dashboard/widgets/notification_drawer.dart';
import 'package:prepvault_ai/features/dashboard/widgets/global_alert_listener.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ===========================================================================
  // 1️⃣ VARIABLES
  // ===========================================================================
  int _selectedIndex = 0;
  String _currentPlan = 'free'; 
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final List<Widget> _pages;

  // ===========================================================================
  // 2️⃣ INIT
  // ===========================================================================
  @override
  void initState() {
    super.initState();
    _syncUserProfile();
    _checkPlanStatus();
    HistoryService().cleanupOldFailures();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAdMobSafe();
    });

    _pages = [
      HomeView(onSwitchToHistory: () => _onItemTapped(1)),
      const HistoryViewScreen(), 
      const OfficialStoreScreen(), 
      const SettingsView(),
    ];
  }

  Future<void> _initAdMobSafe() async {
    if (kIsWeb) return;
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint("⚠️ AdMob Init Failed: $e");
    }
  }

  Future<void> _syncUserProfile() async {
    try {
      await Supabase.instance.client.functions.invoke('payment-manager', body: {'action': 'sync_profile'});
    } catch (e) {
      debugPrint("Sync Failed: $e");
    }
  }

  Future<void> _checkPlanStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data = await Supabase.instance.client
            .from('profiles').select('plan_id').eq('id', user.id).single();
        if (mounted) {
          setState(() {
            _currentPlan = (data['plan_id'] as String? ?? 'free').toLowerCase();
          });
        }
      } catch (e) {
        debugPrint("Plan check error: $e");
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  // 🛑 ADMIN CHECK REMOVED

  // ===========================================================================
  // 3️⃣ MODERN UI BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🔥 A. BACKGROUND GRADIENT
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFF8F9FF), 
                Colors.grey.shade50,
              ],
            ),
          ),
        ),

        // 🔥 B. MAIN CONTENT
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 640;

            return Scaffold(
              key: _scaffoldKey, 
              backgroundColor: Colors.transparent, 
              extendBody: true, // For Floating NavBar
              endDrawer: const NotificationDrawer(),

              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(70),
                child: _buildModernAppBar(),
              ),

              body: Column(
                children: [
                  const AnnouncementBanner(),
                  Expanded(
                    child: isMobile 
                      ? _pages[_selectedIndex] 
                      : Row( 
                          children: [
                            _buildDesktopRail(),
                            Expanded(child: _pages[_selectedIndex]),
                          ],
                        ),
                  ),
                ],
              ),

              // 🛑 ADMIN FAB REMOVED FROM HERE
              floatingActionButton: null,
              
              bottomNavigationBar: isMobile ? _buildFloatingNavBar() : null,
            );
          },
        ),

        const GlobalAlertListener(), 
      ],
    );
  }

  // ===========================================================================
  // 4️⃣ CUSTOM WIDGETS
  // ===========================================================================

  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.only(top: 30, left: 20, right: 20, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8), 
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
      ),
      child: ClipRRect( 
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryStart.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_stories, color: AppColors.primaryStart, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "PrepVault AI", // ✅ NEW BRANDING
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87)
                  ),
                ],
              ),
              
              Row(
                children: [
                  _buildPlanBadge(),
                  const SizedBox(width: 12),
                  
                  InkWell(
                    onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200),
                        color: Colors.white,
                      ),
                      child: Stack(
                        children: [
                          const Icon(Icons.notifications_outlined, color: Colors.black54, size: 24),
                          Positioned(
                            right: 0, top: 0,
                            child: Container(
                              width: 8, height: 8, 
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNavBar() {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 25), 
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87, 
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, "Home"),
          _buildNavItem(1, Icons.history_rounded, Icons.history_outlined, "History"),
          _buildNavItem(2, Icons.storefront_rounded, Icons.storefront_outlined, "Store"),
          _buildNavItem(3, Icons.settings_rounded, Icons.settings_outlined, "Settings"),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? Colors.white : Colors.white54,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopRail() {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onItemTapped,
      backgroundColor: Colors.white,
      labelType: NavigationRailLabelType.all,
      selectedLabelTextStyle: GoogleFonts.outfit(color: AppColors.primaryStart, fontWeight: FontWeight.bold),
      unselectedLabelTextStyle: GoogleFonts.outfit(color: Colors.grey),
      useIndicator: true,
      indicatorColor: AppColors.primaryStart.withValues(alpha: 0.1),
      leading: const SizedBox(height: 20),
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: AppColors.primaryStart), label: Text('Home')),
        NavigationRailDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history, color: AppColors.primaryStart), label: Text('History')),
        NavigationRailDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront, color: AppColors.primaryStart), label: Text('Store')),
        NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: AppColors.primaryStart), label: Text('Settings')),
      ],
    );
  }

  Widget _buildPlanBadge() {
    if (_currentPlan == 'vip') return _badge(text: "VIP", colors: [const Color(0xFFFFD700), const Color(0xFFFFA500)]);
    if (_currentPlan == 'pro' || _currentPlan == 'premium') return _badge(text: "PRO", colors: [const Color(0xFF6A11CB), const Color(0xFF2575FC)]);
    if (_currentPlan == 'mini') return _badge(text: "MINI", colors: [Colors.green, Colors.teal]);
    return const SizedBox.shrink();
  }

  Widget _badge({required String text, required List<Color> colors}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colors[0].withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }
}
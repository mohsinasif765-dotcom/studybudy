import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:studybudy_ai/core/theme/app_colors.dart';
import 'package:studybudy_ai/features/dashboard/screens/home_view.dart';
import 'package:studybudy_ai/features/history/screens/history_view_screen.dart';
import 'package:studybudy_ai/features/dashboard/screens/settings_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isVip = false; // 🌟 VIP Status Track karne ke liye

  final List<Widget> _pages = [
    const HomeView(),
    const HistoryViewScreen(), 
    const SettingsView(),
  ];

  @override
  void initState() {
    super.initState();
    _checkVipStatus(); // 🔍 App start hote hi check karo
  }

  // 🕵️‍♂️ Database se check karega ke user VIP hai ya nahi
  Future<void> _checkVipStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('is_vip')
            .eq('id', user.id)
            .single();
        
        if (mounted) {
          setState(() {
            _isVip = data['is_vip'] ?? false;
          });
        }
      } catch (e) {
        // Error aye to chup chap ignore karein (User ko pareshan na karein)
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  // 👑 Helper to Check Admin Email
  bool get _isAdmin {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.email == 'mohsinasif765@gmail.com';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        
        // 📱 MOBILE VIEW (< 640px)
        if (constraints.maxWidth < 640) {
          return Scaffold(
            // 🌟 TOP BAR ADDED FOR VIP BADGE
            appBar: AppBar(
              title: Text(
                "StudyBuddy AI", 
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black)
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              actions: [
                if (_isVip) _buildVipBadge(), // 💎 Sirf VIPs ko dikhega
                const SizedBox(width: 16),
              ],
            ),
            body: _pages[_selectedIndex],
            
            // 🛑 ADMIN BUTTON (Floating)
            floatingActionButton: _isAdmin 
              ? FloatingActionButton(
                  onPressed: () => context.go('/admin'),
                  backgroundColor: Colors.red,
                  tooltip: "Admin Panel",
                  child: const Icon(Icons.admin_panel_settings, color: Colors.white),
                ) 
              : null,

            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              backgroundColor: Colors.white,
              elevation: 5,
              indicatorColor: AppColors.primaryStart.withValues(alpha: 0.2),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home, color: AppColors.primaryStart),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history, color: AppColors.primaryStart),
                  label: 'History',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings, color: AppColors.primaryStart),
                  label: 'Settings',
                ),
              ],
            ),
          );
        } 
        
        // 💻 TABLET/WEB VIEW (>= 640px)
        else {
          return Scaffold(
            appBar: AppBar(
              title: Text("StudyBuddy AI", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.black)),
              backgroundColor: Colors.white,
              elevation: 0,
              actions: [
                if (_isVip) _buildVipBadge(),
                const SizedBox(width: 20),
              ],
            ),
            // 🛑 ADMIN BUTTON (Floating for Web too)
            floatingActionButton: _isAdmin 
              ? FloatingActionButton(
                  onPressed: () => context.go('/admin'),
                  backgroundColor: Colors.red,
                  tooltip: "Admin Panel",
                  child: const Icon(Icons.admin_panel_settings, color: Colors.white),
                ) 
              : null,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  backgroundColor: Colors.white,
                  labelType: NavigationRailLabelType.all,
                  selectedLabelTextStyle: GoogleFonts.outfit(
                    color: AppColors.primaryStart,
                    fontWeight: FontWeight.bold
                  ),
                  unselectedLabelTextStyle: GoogleFonts.outfit(color: Colors.grey),
                  useIndicator: true,
                  indicatorColor: AppColors.primaryStart.withValues(alpha: 0.2),
                  
                  leading: const SizedBox(height: 20), 

                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home, color: AppColors.primaryStart),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history, color: AppColors.primaryStart),
                      label: Text('History'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings, color: AppColors.primaryStart),
                      label: Text('Settings'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: _pages[_selectedIndex]),
              ],
            ),
          );
        }
      },
    );
  }

  // 🏆 GOLDEN VIP BADGE WIDGET
  Widget _buildVipBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)], // ✨ Gold Colors
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            "VIP MEMBER",
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
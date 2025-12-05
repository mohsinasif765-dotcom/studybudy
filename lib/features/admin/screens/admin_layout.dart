import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:studybudy_ai/core/theme/app_colors.dart';
import 'admin_dashboard.dart';
import 'admin_users.dart';
import 'admin_payments.dart';
import 'admin_settings.dart'; // 👈 Import New Settings

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = [
    const AdminDashboard(),
    const AdminUsers(),
    const AdminPayments(),
    const AdminSettings(), // 👈 Updated from Placeholder
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          // Mobile: Bottom Nav
          return Scaffold(
            body: _pages[_selectedIndex],
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dash'),
                NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
                NavigationDestination(icon: Icon(Icons.payments), label: 'Pay'),
                NavigationDestination(icon: Icon(Icons.settings), label: 'Config'),
              ],
            ),
          );
        } else {
          // Desktop: Side Rail
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: true,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                  leading: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text("ADMIN PANEL", style: TextStyle(color: AppColors.primaryStart, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
                    NavigationRailDestination(icon: Icon(Icons.people), label: Text('Users')),
                    NavigationRailDestination(icon: Icon(Icons.payments), label: Text('Approvals')),
                    NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Config')),
                  ],
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: TextButton.icon(
                          onPressed: () => context.go('/dashboard'),
                          icon: const Icon(Icons.exit_to_app),
                          label: const Text("Exit Admin"),
                        ),
                      ),
                    ),
                  ),
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
}
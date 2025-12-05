import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Real Stats Variables
  int _totalUsers = 0;
  int _pendingRequests = 0;
  int _totalRevenue = 0;
  String _activeAiModel = "Loading..."; // 🤖 AI Status
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  // 📊 Database se Real Data lana
  Future<void> _fetchStats() async {
    final supabase = Supabase.instance.client;
    try {
      setState(() => _isLoading = true);

      // 1. Total Users Count
      final usersCount = await supabase
          .from('profiles')
          .count(CountOption.exact);
      
      // 2. Pending Requests Count
      final pendingCount = await supabase
          .from('payment_requests')
          .count(CountOption.exact)
          .eq('status', 'pending');

      // 3. Active AI Model (From app_config table)
      String aiModel = "Gemini"; // Default
      try {
        final configRes = await supabase
          .from('app_config')
          .select('value')
          .eq('key', 'active_ai_provider')
          .maybeSingle();
        
        if (configRes != null) {
          aiModel = configRes['value'].toString().toUpperCase();
        }
      } catch (e) {
        // Table shayad na bani ho abhi
        debugPrint("Config Error: $e");
      }

      // 4. Total Revenue
      final revenueRes = await supabase
          .from('payment_requests')
          .select('amount')
          .eq('status', 'approved');
      
      int revenue = 0;
      final List<dynamic> data = revenueRes;
      for (var item in data) {
          revenue += (item['amount'] as num? ?? 0).toInt();
      }

      if (mounted) {
        setState(() {
          _totalUsers = usersCount;
          _pendingRequests = pendingCount;
          _totalRevenue = revenue;
          _activeAiModel = aiModel;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("System Overview", style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: _fetchStats, 
                  icon: const Icon(Icons.refresh),
                  tooltip: "Refresh Stats",
                )
              ],
            ),
            const SizedBox(height: 24),
            
            if (_isLoading)
               const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              // Stats Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(), 
                crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard("Total Users", "$_totalUsers", Icons.people, Colors.blue),
                  _buildStatCard("Revenue (PKR)", "Rs ${_totalRevenue.toLocaleString()}", Icons.attach_money, Colors.green),
                  _buildStatCard("Pending Requests", "$_pendingRequests", Icons.access_time, Colors.orange),
                  
                  // 🤖 NEW: AI STATUS CARD
                  _buildStatCard("Active Brain", _activeAiModel, Icons.psychology, Colors.purple),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), 
            blurRadius: 10
          )
        ],
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: GoogleFonts.outfit(color: Colors.grey)),
        ],
      ),
    );
  }
}

extension NumberParsing on int {
  String toLocaleString() {
    return toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}
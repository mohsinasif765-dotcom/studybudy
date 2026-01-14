import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';

class UserProgressChart extends StatefulWidget {
  const UserProgressChart({super.key});

  @override
  State<UserProgressChart> createState() => _UserProgressChartState();
}

class _UserProgressChartState extends State<UserProgressChart> {
  List<int> _history = [];
  bool _isLoading = true;
  
  // 🔥 State for Interaction
  int _touchedIndex = -1; // -1 matlab koi select nahi hai
  int _latestScore = 0;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch last 7 tests
      final response = await Supabase.instance.client
          .from('quiz_history')
          .select('percentage')
          .eq('user_id', userId)
          .order('created_at', ascending: true) 
          .limit(7); // Mobile screen ke liye 7 best rehte hain

      List<int> data = (response as List).map((e) => e['percentage'] as int).toList();

      if (mounted) {
        setState(() {
          _history = data;
          if (data.isNotEmpty) {
            _latestScore = data.last; // Default to showing latest score
            _touchedIndex = data.length - 1; // Default select last one
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 250,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: const Center(child: CircularProgressIndicator(color: AppColors.primaryStart)),
      );
    }

    if (_history.isEmpty) {
      return _buildEmptyState();
    }

    // Determine current display values
    final int displayScore = (_touchedIndex != -1 && _touchedIndex < _history.length) 
        ? _history[_touchedIndex] 
        : (_history.isNotEmpty ? _history.last : 0);

    String statusText = "Good Job!";
    Color statusColor = AppColors.primaryStart;
    
    if (displayScore < 50) {
      statusText = "Needs Improvement";
      statusColor = Colors.orange;
    } else if (displayScore >= 80) {
      statusText = "Excellent!";
      statusColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          // 1. DYNAMIC HEADER (Touch karne par ye change hoga)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Test Performance", style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(statusText, style: GoogleFonts.outfit(color: statusColor, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryStart.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$displayScore%",
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold, 
                    color: AppColors.primaryStart
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // 2. MODERN BAR CHART
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (_, __, ___, ____) => null, // ❌ Disable Tooltip (Mobile Friendly)
                  ),
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    if (!event.isInterestedForInteractions || barTouchResponse == null || barTouchResponse.spot == null) {
                      return;
                    }
                    // 🔥 Update state on Touch
                    setState(() {
                      _touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide Left Axis (Cleaner)
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            "T${value.toInt() + 1}",
                            style: GoogleFonts.outfit(
                              color: _touchedIndex == value.toInt() ? AppColors.primaryStart : Colors.grey.shade400,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false), // Clean look, no grid
                barGroups: _history.asMap().entries.map((entry) {
                  final index = entry.key;
                  final score = entry.value;
                  final isSelected = index == _touchedIndex;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: score.toDouble(),
                        color: isSelected ? AppColors.primaryStart : Colors.grey.shade300,
                        width: 16, // Thicker bars
                        borderRadius: BorderRadius.circular(8),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 100, // Full height background
                          color: Colors.grey.shade50,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text("No Quizzes Yet", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:studybudy_ai/features/subscription/services/payment_service.dart';
import 'manual_payment_modal.dart';

// ✅ 1. Updated Data Model to handle Database Data
class Plan {
  final String id;
  final String name;
  final int credits;
  final int priceUSD;
  final int pricePKR;
  final List<String> features;
  final bool isPopular;
  final Color color;

  Plan({
    required this.id, 
    required this.name, 
    required this.credits,
    required this.priceUSD, 
    required this.pricePKR, 
    required this.features, 
    this.isPopular = false, 
    this.color = Colors.blue
  });

  // Factory to convert Supabase JSON to Plan Object
  factory Plan.fromMap(Map<String, dynamic> map) {
    return Plan(
      id: map['id'],
      name: map['name'],
      credits: map['credits'],
      priceUSD: map['price_usd'],
      pricePKR: map['price_pkr'],
      features: List<String>.from(map['features'] ?? []),
      isPopular: map['is_popular'] ?? false,
      color: Color(int.parse(map['color_hex'] ?? '0xFF2196F3')), // Parse Hex String
    );
  }
}

class PricingModal extends StatefulWidget {
  final String currentPlanId;

  const PricingModal({super.key, required this.currentPlanId});

  @override
  State<PricingModal> createState() => _PricingModalState();
}

class _PricingModalState extends State<PricingModal> {
  bool _isYearly = false;
  bool _isPakistan = false;
  bool _useLocalPayment = false; 
  bool _isLoading = true; // ⏳ Loading state

  List<Plan> _plans = []; // Empty initially, filled from DB

  @override
  void initState() {
    super.initState();
    _checkTimezone();
    _fetchPlansFromDB(); // 🚀 Fetch Live Data
  }

  // 🌍 Check Location
  void _checkTimezone() {
    final offset = DateTime.now().timeZoneOffset.inHours;
    if (offset == 5) { 
      setState(() {
        _isPakistan = true;
        _useLocalPayment = true; 
      });
    }
  }

  // 📥 Fetch Plans from Supabase
  Future<void> _fetchPlansFromDB() async {
    try {
      final data = await Supabase.instance.client
          .from('plans')
          .select()
          .order('price_pkr', ascending: true);

      if (mounted) {
        setState(() {
          _plans = data.map((json) => Plan.fromMap(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Fallback or Error handling (Optional: Show Retry Button)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to load plans: $e")));
      }
    }
  }

  void _handlePlanSelect(Plan plan) async {
    // 1. Manual Payment Logic
    if (_useLocalPayment) {
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ManualPaymentModal(
          planName: "${plan.name} (${plan.credits} Credits)",
          amount: _isYearly ? (plan.pricePKR * 12 * 0.8).round() : plan.pricePKR,
        ),
      );
    } 
    // 2. Stripe/Store Logic
    else {
      try {
        Navigator.pop(context); // Close modal first
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Processing Payment..."), duration: Duration(seconds: 2))
        );

        // Call Service
        await PaymentService().buyPlan(plan.id, isYearly: _isYearly);

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment Failed: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter logic same as before
    final visiblePlans = _isYearly 
        ? _plans.where((p) => p.id != 'mini').toList() 
        : _plans;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 1100),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2), 
              blurRadius: 20
            )
          ]
        ),
        child: _isLoading 
        ? const SizedBox(
            height: 300, 
            child: Center(child: CircularProgressIndicator())
          ) 
        : SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              
              Text("Top Up Your Credits", style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Purchase credits to generate summaries and quizzes.", style: GoogleFonts.outfit(color: Colors.grey.shade600)),
              
              const SizedBox(height: 20),

              // 🇵🇰 Pakistan Toggle
              if (_isPakistan)
                GestureDetector(
                  onTap: () => setState(() => _useLocalPayment = !_useLocalPayment),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: _useLocalPayment ? Colors.green.shade50 : Colors.white,
                      border: Border.all(color: _useLocalPayment ? Colors.green : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_useLocalPayment ? Icons.check_circle : Icons.public, color: _useLocalPayment ? Colors.green : Colors.grey),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _useLocalPayment ? "Paying in PKR (Tax Saved)" : "Switch to International (USD)",
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _useLocalPayment ? Colors.green.shade800 : Colors.black87)
                            ),
                            if(_useLocalPayment)
                              Text("Manual verification enabled", style: GoogleFonts.outfit(fontSize: 10, color: Colors.green)),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Switch(
                          value: _useLocalPayment,
                          activeTrackColor: Colors.green.shade200,
                          thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                            if (states.contains(WidgetState.selected)) return Colors.green;
                            return Colors.grey;
                          }),
                          onChanged: (val) => setState(() => _useLocalPayment = val),
                        )
                      ],
                    ),
                  ),
                ),

              // Interval Toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTimeToggle("Monthly", !_isYearly),
                    _buildTimeToggle("Yearly (-20%)", _isYearly),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Cards Layout (Responsive)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 850;
                  
                  if (_plans.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text("No plans available right now."),
                    );
                  }

                  return isMobile 
                    ? Column(children: visiblePlans.map((p) => _buildPlanCard(p, true)).toList())
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: visiblePlans.map((p) => Expanded(child: _buildPlanCard(p, false))).toList()
                      );
                },
              ),

              const SizedBox(height: 20),
              
              if (_useLocalPayment)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text("Credits are added to your account after verification.", style: GoogleFonts.outfit(fontSize: 12, color: Colors.blue.shade800)),
                    ],
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeToggle(String text, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _isYearly = text.contains("Yearly")),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1), 
              blurRadius: 4
            )
          ] : [],
        ),
        child: Text(text, style: GoogleFonts.outfit(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black : Colors.grey.shade600
        )),
      ),
    );
  }

  Widget _buildPlanCard(Plan plan, bool isMobile) {
    final isPro = plan.isPopular;
    int price = _useLocalPayment ? plan.pricePKR : plan.priceUSD;
    if (_isYearly) price = (price * 12 * 0.8).round();
    int credits = _isYearly ? plan.credits * 12 : plan.credits;

    return Container(
      margin: EdgeInsets.only(
        bottom: isMobile ? 20 : 0, 
        right: isMobile ? 0 : 16
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isPro ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isPro ? Colors.transparent : Colors.grey.shade200, 
                width: 2
              ),
              boxShadow: isPro 
                ? [BoxShadow(color: plan.color.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Text(plan.name, style: GoogleFonts.outfit(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  color: isPro ? Colors.white : plan.color
                )),
                
                const SizedBox(height: 15),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: plan.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: plan.color.withValues(alpha: 0.3))
                  ),
                  child: Text(
                    "${credits.toLocaleString()} Credits",
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold, 
                      color: isPro ? Colors.white : plan.color
                    ),
                  ),
                ),

                const SizedBox(height: 15),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _useLocalPayment ? "Rs ${price.toLocaleString()}" : "\$$price",
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 32, 
                        fontWeight: FontWeight.bold,
                        color: isPro ? Colors.white : Colors.black87
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 4),
                      child: Text(
                        _isYearly ? "/yr" : "/mo",
                        style: TextStyle(color: isPro ? Colors.grey.shade400 : Colors.grey),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                Divider(color: isPro ? Colors.white24 : Colors.grey.shade100),
                const SizedBox(height: 20),

                ...plan.features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: isPro ? Colors.greenAccent : Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(f, style: GoogleFonts.outfit(
                          color: isPro ? Colors.grey.shade300 : Colors.grey.shade700,
                          fontSize: 14
                        )),
                      ),
                    ],
                  ),
                )),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handlePlanSelect(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPro 
                          ? plan.color 
                          : (_useLocalPayment ? Colors.green.shade600 : Colors.black),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: isPro ? 8 : 0,
                    ),
                    child: Text(
                      _useLocalPayment ? "Pay via Easypaisa / JazzCash" : "Buy Credits",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (isPro)
            Positioned(
              top: -12, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [plan.color, plan.color.withValues(alpha: 0.8)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: plan.color.withValues(alpha: 0.4), blurRadius: 8)]
                  ),
                  child: const Text("MOST POPULAR", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Extension to format numbers (e.g., 2000 -> 2,000)
extension NumberParsing on int {
  String toLocaleString() {
    return toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}
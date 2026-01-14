import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// ✅ Android Specific Features
import 'package:in_app_purchase_android/in_app_purchase_android.dart'; 
import 'package:confetti/confetti.dart';

import 'package:prepvault_ai/features/subscription/services/subscription_manager.dart';

// =============================================================================
// 1️⃣ DATA MODEL
// =============================================================================
class Plan {
  final String id;
  final String googleProductId;
  final String name;
  final int credits;
  final int priceUSD;
  final String interval;
  final List<String> features;
  final bool isPopular;
  final Color color;
  final int yearlyDiscount;

  Plan({
    required this.id,
    required this.googleProductId,
    required this.name,
    required this.credits,
    required this.priceUSD,
    required this.interval,
    required this.features,
    required this.isPopular,
    required this.color,
    required this.yearlyDiscount,
  });

  factory Plan.fromMap(Map<String, dynamic> map) {
    return Plan(
      id: map['id'] ?? '',
      googleProductId: (map['google_product_id']?.toString() ?? '').trim(),
      name: map['name'] ?? 'Unknown Plan',
      credits: int.tryParse(map['credits'].toString()) ?? 0,
      priceUSD: int.tryParse(map['price_usd'].toString()) ?? 0,
      interval: map['interval'] ?? 'month',
      features: List<String>.from(map['features'] ?? []),
      isPopular: map['is_popular'] ?? false,
      color: _parseColor(map['color_hex']),
      yearlyDiscount: map['yearly_discount_percent'] ?? 0,
    );
  }

  static Color _parseColor(String? hex) {
    try {
      if (hex == null || hex.isEmpty) return const Color(0xFF2196F3);
      String cleanHex = hex.replaceAll('#', '').replaceAll('0x', '');
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
      return Color(int.parse('0x$cleanHex'));
    } catch (_) {
      return const Color(0xFF2196F3);
    }
  }
}

// =============================================================================
// 2️⃣ PRICING MODAL
// =============================================================================
class PricingModal extends StatefulWidget {
  final String currentPlanId;
  final bool isFullScreen;
  final VoidCallback? onContinueFree;

  const PricingModal({
    super.key,
    required this.currentPlanId,
    this.isFullScreen = false,
    this.onContinueFree,
  });

  @override
  State<PricingModal> createState() => _PricingModalState();
}

class _PricingModalState extends State<PricingModal> {
  bool _isYearly = false;
  bool _isLoading = true;
  String? _purchasingPlanId;
  List<Plan> _plans = [];
  String? _errorMessage;
  
  // 🔥 To store the existing subscription for Upgrade logic
  PurchaseDetails? _oldPurchaseDetails; 

  late ConfettiController _confettiController;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _fetchData();
    _listenToPurchaseStream();
    
    // 🛠️ Check for existing purchases (Needed for Upgrade/Downgrade)
    InAppPurchase.instance.restorePurchases();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  // 🔥 CUSTOM STATUS POPUP (English Only)
  void _showStatusDialog({required String title, required String message, required bool isSuccess}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: isSuccess ? Colors.green : Colors.red,
              size: 80,
            ),
            const SizedBox(height: 20),
            Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuccess ? Colors.green : Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _listenToPurchaseStream() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = InAppPurchase.instance.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _handlePurchaseUpdates(purchaseDetailsList);
    }, onDone: () => _subscription?.cancel(), onError: (error) => debugPrint("❌ [STREAM ERROR] $error"));
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint("⏳ [BILLING] Purchase Pending...");
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint("❌ [BILLING] Purchase Error: ${purchaseDetails.error}");
        _showStatusDialog(
          title: "Purchase Error",
          message: "Payment could not be completed: ${purchaseDetails.error?.message ?? 'Unknown error'}",
          isSuccess: false,
        );
      } else if (purchaseDetails.status == PurchaseStatus.restored) {
        // 🔥 Found an existing subscription! Save it for Upgrade logic.
        debugPrint("♻️ [BILLING] Found existing subscription: ${purchaseDetails.productID}");
        _oldPurchaseDetails = purchaseDetails;
      } else if (purchaseDetails.status == PurchaseStatus.purchased) {
        final String purchaseToken = purchaseDetails.verificationData.serverVerificationData;
        _verifyPurchase(purchaseToken, purchaseDetails.productID);
        if (purchaseDetails.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _verifyPurchase(String token, String productId) async {
    try {
      debugPrint("📡 [BACKEND] Calling 'payment-manager' for verification...");
      
      final response = await Supabase.instance.client.functions.invoke(
        'payment-manager',
        body: {
          'action': 'verify_mobile_receipt_native', 
          'purchaseToken': token, 
          'productId': productId, 
          'platform': 'android'
        },
      );

      if (response.status == 200 || response.status == 201) {
        debugPrint("🎉 [BACKEND SUCCESS]");
        if (mounted) {
          _confettiController.play();
          _showStatusDialog(
            title: "Success!",
            message: "Your subscription is now active and credits have been updated.",
            isSuccess: true,
          );
        }
      } else {
        throw "Server verification failed (Code: ${response.status})";
      }
    } catch (e) {
      debugPrint("❌ [VERIFICATION ERROR] $e");
      String errorMsg = "Verification failed. Please contact support.";
      if (e is SocketException) errorMsg = "Network error. Please check your internet connection.";
      
      _showStatusDialog(title: "Verification Failed", message: errorMsg, isSuccess: false);
    }
  }

  Future<void> _fetchData() async {
    try {
      final response = await Supabase.instance.client.from('plans').select().order('price_usd', ascending: true);
      if (mounted) {
        final List<dynamic> data = response as List<dynamic>;
        setState(() {
          _plans = data.map((json) => Plan.fromMap(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = "Failed to load plans. Please try again."; });
    }
  }

  // 🔥 UPDATED: Logic to handle Upgrade/Downgrade
  void _handlePlanSelect(Plan plan) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous == true) { _showLoginAlert(); return; }
    if (_purchasingPlanId != null) return;

    setState(() => _purchasingPlanId = plan.id);
    
    try {
      // 1. Get Product Details from Google Play first
      final Set<String> ids = {plan.googleProductId};
      final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(ids);
      
      if (response.notFoundIDs.isNotEmpty) {
        throw "Product not found on Store. Check Google Console configuration.";
      }

      final ProductDetails productDetails = response.productDetails.first;

      // 2. Prepare Purchase Parameters
      PurchaseParam purchaseParam;

      if (Platform.isAndroid && _oldPurchaseDetails != null) {
        debugPrint("🔄 [UPGRADE] Detected active subscription. Upgrading from: ${_oldPurchaseDetails!.productID}");
        
        // ✅ FIX: Using correct GooglePlayPurchaseParam without prorationMode (Auto-handled)
        purchaseParam = GooglePlayPurchaseParam(
          productDetails: productDetails,
          changeSubscriptionParam: ChangeSubscriptionParam(
            oldPurchaseDetails: _oldPurchaseDetails! as GooglePlayPurchaseDetails,
            // ❌ REMOVED prorationMode (It causes errors, Google handles it automatically)
          ),
        );
      } else {
        // Normal Purchase
        purchaseParam = PurchaseParam(productDetails: productDetails);
      }

      // 3. Initiate Purchase
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
      
    } catch (e) {
      debugPrint("❌ [PURCHASE ERROR] $e");
      String msg = e.toString();
      if (e is SocketException) msg = "Internet connection error.";
      _showStatusDialog(title: "Error", message: msg, isSuccess: false);
    } finally {
      if (mounted) setState(() => _purchasingPlanId = null);
    }
  }

  void _showLoginAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Account Required"),
        content: const Text("Please login to subscribe."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () { Navigator.pop(ctx); context.push('/auth'); }, child: const Text("Login")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visiblePlans = _plans.where((p) {
      if (_isYearly) return p.interval == 'year';
      return p.interval == 'month' || p.interval == 'week';
    }).toList();

    int maxDiscount = 0;
    try {
      final yearlyPlan = _plans.firstWhere((p) => p.interval == 'year', orElse: () => _plans[0]);
      maxDiscount = yearlyPlan.yearlyDiscount;
    } catch (_) {}

    Widget contentBody = Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey.shade50,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 28),
                      onPressed: widget.onContinueFree ?? () => context.pop(),
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? Center(child: Text(_errorMessage!))
                          : SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                children: [
                                  Text("Upgrade Your Study", style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 20),
                                  _buildToggle(maxDiscount),
                                  const SizedBox(height: 30),
                                  ...visiblePlans.map((p) => _buildPlanCard(p)),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
          ),
        ),
      ],
    );

    if (widget.isFullScreen) return contentBody;
    return Dialog(insetPadding: EdgeInsets.zero, child: contentBody);
  }

  Widget _buildToggle(int maxDiscount) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTimeToggle("Monthly", !_isYearly),
          _buildTimeToggle("Yearly ${maxDiscount > 0 ? '(-$maxDiscount%)' : ''}", _isYearly),
        ],
      ),
    );
  }

  Widget _buildTimeToggle(String text, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _isYearly = text.contains("Yearly")),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
        ),
        child: Text(text, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildPlanCard(Plan plan) {
    final bool isThisLoading = _purchasingPlanId == plan.id;
    String intervalText = plan.interval == 'year' ? "/yr" : (plan.interval == 'week' ? "/wk" : "/mo");

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: plan.isPopular ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: plan.isPopular ? plan.color : Colors.grey.shade200, width: 2),
        // ✅ UPDATED: withValues instead of withOpacity
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          if (plan.isPopular)
             Padding(
               padding: const EdgeInsets.only(bottom: 8.0),
               child: Text("MOST POPULAR", style: TextStyle(color: plan.color, fontSize: 12, fontWeight: FontWeight.bold)),
             ),
          Text(plan.name, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: plan.isPopular ? Colors.white : Colors.black)),
          const SizedBox(height: 10),
          Text("\$${plan.priceUSD}$intervalText", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 15),
          ...plan.features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [
              const Icon(Icons.check, size: 16, color: Colors.green),
              const SizedBox(width: 5),
              Expanded(child: Text(f, style: TextStyle(color: plan.isPopular ? Colors.white70 : Colors.black87)))
            ]),
          )),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: plan.color,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _purchasingPlanId != null ? null : () => _handlePlanSelect(plan),
              child: isThisLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Subscribe Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
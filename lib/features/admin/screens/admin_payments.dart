import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybudy_ai/features/admin/services/admin_service.dart';

class AdminPayments extends StatefulWidget {
  const AdminPayments({super.key});

  @override
  State<AdminPayments> createState() => _AdminPaymentsState();
}

class _AdminPaymentsState extends State<AdminPayments> {
  final AdminService _service = AdminService();
  List<dynamic> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final data = await _service.getPendingPayments();
      
      if (mounted) {
        setState(() {
          _requests = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load: $e";
        });
      }
    }
  }

  Future<void> _processRequest(String id, String status) async {
    // Optimistic Update: UI se foran hata do taake fast lage
    final originalList = List.from(_requests);
    setState(() {
      _requests.removeWhere((req) => req['id'] == id);
    });

    try {
      await _service.processPayment(id, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Request $status successfully"),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      // Agar fail ho jaye to wapis list mein daal do
      if (mounted) {
        setState(() => _requests = originalList);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Payment Approvals", style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: _loadRequests,
                  icon: const Icon(Icons.refresh),
                  tooltip: "Refresh Data",
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                  ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                  : _requests.isEmpty 
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _requests.length,
                        itemBuilder: (context, index) {
                          final req = _requests[index];
                          return _buildRequestCard(req);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No Pending Approvals", style: GoogleFonts.spaceGrotesk(fontSize: 20, color: Colors.grey)),
          const SizedBox(height: 8),
          Text("All payments have been processed.", style: GoogleFonts.outfit(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildRequestCard(dynamic req) {
    final method = req['payment_method'] ?? 'Unknown';
    final amount = req['amount'] ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: method.toString().toLowerCase().contains('jazz') ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                color: method.toString().toLowerCase().contains('jazz') ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("TRX: ${req['transaction_id'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Monospace')),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text("Rs $amount", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const Text(" • "),
                      Text(req['plan_id']?.toString().toUpperCase() ?? 'PLAN', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                  onPressed: () => _processRequest(req['id'], 'approved'),
                  tooltip: "Approve Payment",
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                  onPressed: () => _processRequest(req['id'], 'rejected'),
                  tooltip: "Reject Payment",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
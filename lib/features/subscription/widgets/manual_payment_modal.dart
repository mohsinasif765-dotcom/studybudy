import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
// ❌ Unused import removed

class ManualPaymentModal extends StatefulWidget {
  final String planName;
  final int amount;

  const ManualPaymentModal({
    super.key,
    required this.planName,
    required this.amount,
  });

  @override
  State<ManualPaymentModal> createState() => _ManualPaymentModalState();
}

class _ManualPaymentModalState extends State<ManualPaymentModal> {
  final TextEditingController _trxController = TextEditingController();
  String _selectedMethod = 'easypaisa';
  bool _isLoading = false;
  bool _submitted = false;

  // Dummy Payment Details
  final Map<String, Map<String, String>> _methods = {
    'easypaisa': {
      'title': 'Easypaisa',
      'account': '0300-1234567',
      'name': 'StudyBuddy Official',
      'color': '4CAF50' // Green Hex approx
    },
    'jazzcash': {
      'title': 'JazzCash',
      'account': '0321-7654321',
      'name': 'StudyBuddy Official',
      'color': 'F44336' // Red Hex approx
    }
  };

  void _handleCopy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account number copied!")));
  }

  void _handleSubmit() async {
    if (_trxController.text.isEmpty) return;

    setState(() => _isLoading = true);
    // Simulate API Call
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isLoading = false;
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            Text("Request Sent!", style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Admin will verify TRX ID: ${_trxController.text}\nCredits will be added shortly.", textAlign: TextAlign.center),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
              child: const Text("Close"),
            )
          ],
        ),
      );
    }

    final methodData = _methods[_selectedMethod]!;
    // ❌ Unused 'isJazz' variable removed

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: 40, height: 4, 
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Local Payment (PKR)", style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
              ],
            ),
            
            const SizedBox(height: 20),

            // Amount Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  const Text("Total Amount to Send", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  Text("Rs. ${widget.amount}", style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                  Text("For ${widget.planName} Plan", style: const TextStyle(fontSize: 12, color: Colors.green)),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Method Selector
            Row(
              children: [
                Expanded(child: _buildMethodCard('easypaisa', 'Easypaisa', Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _buildMethodCard('jazzcash', 'JazzCash', Colors.red)),
              ],
            ),

            const SizedBox(height: 20),

            // Account Details Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(methodData['account']!, style: GoogleFonts.sourceCodePro(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(methodData['name']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () => _handleCopy(methodData['account']!),
                  )
                ],
              ),
            ),

            const SizedBox(height: 30),

            // TRX Input
            TextField(
              controller: _trxController,
              decoration: InputDecoration(
                labelText: "Transaction ID (TID)",
                hintText: "e.g. 8421XXXXXX",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Verify Payment"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodCard(String id, String name, Color color) {
    final isSelected = _selectedMethod == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          // 👇 FIX: withOpacity -> withValues(alpha: ...)
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          border: Border.all(color: isSelected ? color : Colors.grey.shade200, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(name, style: TextStyle(
            color: isSelected ? color : Colors.grey,
            fontWeight: FontWeight.bold,
          )),
        ),
      ),
    );
  }
}
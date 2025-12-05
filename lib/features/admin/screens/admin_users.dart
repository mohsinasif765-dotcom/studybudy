import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybudy_ai/features/admin/services/admin_service.dart';

class AdminUsers extends StatefulWidget {
  const AdminUsers({super.key});

  @override
  State<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
  final AdminService _service = AdminService();
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _service.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 NEW: MANAGE USER DIALOG (God Mode)
  void _showManageUserDialog(Map<String, dynamic> user) {
    final creditController = TextEditingController();
    
    // Initial Values
    String selectedPlan = user['plan_id'] ?? 'free';
    bool isVip = user['is_vip'] ?? false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text((user['full_name']?[0] ?? 'U').toUpperCase()),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Manage User", style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(user['full_name'] ?? 'Unknown', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  
                  // 1. CHANGE PLAN
                  Text("Subscription Plan", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedPlan,
                        isExpanded: true,
                        items: ['free', 'mini', 'basic', 'pro'].map((String plan) {
                          return DropdownMenuItem<String>(
                            value: plan,
                            child: Text(plan.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setStateDialog(() => selectedPlan = val);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // 2. VIP ACCESS SWITCH
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Grant VIP Access", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Bypass limits & ads"),
                    value: isVip,
                    activeColor: Colors.purple,
                    onChanged: (val) {
                      setStateDialog(() => isVip = val);
                    },
                  ),

                  const Divider(),

                  // 3. GIFT CREDITS
                  Text("Gift Credits (Optional)", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 5),
                  TextField(
                    controller: creditController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: "Enter amount (e.g. 1000)",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      prefixIcon: Icon(Icons.volunteer_activism, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(context); // Close Dialog
                  
                  // 1. Update Plan & VIP
                  await _service.updateUserPlan(user['id'], planId: selectedPlan, isVip: isVip);

                  // 2. Gift Credits (if entered)
                  if (creditController.text.isNotEmpty) {
                    await _service.giftCredits(user['id'], int.parse(creditController.text));
                  }

                  // 3. Refresh UI
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User updated successfully!")));
                  _loadUsers(); 
                },
                child: const Text("Save Changes"),
              ),
            ],
          );
        },
      ),
    );
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
                Text("User Management", style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(onPressed: _loadUsers, icon: const Icon(Icons.refresh), tooltip: "Refresh List"),
              ],
            ),
            const SizedBox(height: 20),
            
            // User Table
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView( // Horizontal scroll for mobile
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20,
                          headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                          columns: const [
                            DataColumn(label: Text("User Info")),
                            DataColumn(label: Text("Credits")),
                            DataColumn(label: Text("Plan")),
                            DataColumn(label: Text("VIP")),
                            DataColumn(label: Text("Actions")),
                          ],
                          rows: _users.map((user) {
                            final isVip = user['is_vip'] ?? false;
                            
                            return DataRow(cells: [
                              // Name & Email
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(user['full_name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(user['email'] ?? '-', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              // Credits
                              DataCell(Text(user['credits_total'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                              // Plan Badge
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: user['plan_id'] == 'pro' ? Colors.purple.shade50 : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: user['plan_id'] == 'pro' ? Colors.purple.shade100 : Colors.blue.shade100),
                                  ),
                                  child: Text(
                                    (user['plan_id'] ?? 'free').toUpperCase(), 
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: user['plan_id'] == 'pro' ? Colors.purple : Colors.blue)
                                  ),
                                )
                              ),
                              // VIP Status
                              DataCell(
                                isVip 
                                ? const Icon(Icons.diamond, color: Colors.purple, size: 18) 
                                : const Icon(Icons.circle_outlined, color: Colors.grey, size: 18)
                              ),
                              // Actions
                              DataCell(
                                Row(
                                  children: [
                                    // Edit / Manage Button 🛠️
                                    IconButton(
                                      icon: const Icon(Icons.edit_note, color: Colors.blue),
                                      onPressed: () => _showManageUserDialog(user),
                                      tooltip: "Manage User",
                                    ),
                                  ],
                                )
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybudy_ai/core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // 📦 Plans Data
  List<Map<String, dynamic>> _plans = [];

  // 🤖 AI Config Data
  String _selectedAiProvider = 'gemini';
  final TextEditingController _modelNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchPlans(),
      _fetchAiConfig(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  // 📥 1. Fetch Plans
  Future<void> _fetchPlans() async {
    try {
      final data = await _supabase
          .from('plans')
          .select()
          .order('price_pkr', ascending: true);
      
      if (mounted) {
        _plans = List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint("Error loading plans: $e");
    }
  }

  // 🤖 2. Fetch AI Config
  Future<void> _fetchAiConfig() async {
    try {
      // Fetch Provider
      final providerRes = await _supabase.from('app_config').select('value').eq('key', 'active_ai_provider').maybeSingle();
      if (providerRes != null) {
        _selectedAiProvider = providerRes['value'];
      }

      // Fetch Model
      final modelRes = await _supabase.from('app_config').select('value').eq('key', 'active_ai_model').maybeSingle();
      if (modelRes != null) {
        _modelNameController.text = modelRes['value'];
      } else {
        _setDefaultModelName(_selectedAiProvider);
      }
    } catch (e) {
      debugPrint("Error loading AI config: $e");
    }
  }

  void _setDefaultModelName(String provider) {
    if (_modelNameController.text.isNotEmpty) return;
    
    if (provider == 'gemini') _modelNameController.text = 'gemini-1.5-flash';
    else if (provider == 'openai') _modelNameController.text = 'gpt-4o-mini';
    else if (provider == 'deepseek') _modelNameController.text = 'deepseek-chat';
  }

  // 💾 SAVE EVERYTHING
  Future<void> _saveAllChanges() async {
    setState(() => _isLoading = true);
    try {
      // 1. Save Plans
      for (var plan in _plans) {
        await _supabase.from('plans').update({
          'name': plan['name'],
          'price_pkr': plan['price_pkr'],
          'price_usd': plan['price_usd'],
          'credits': plan['credits'],
          'is_popular': plan['is_popular'],
        }).eq('id', plan['id']);
      }

      // 2. Save AI Config
      await _supabase.from('app_config').upsert({
        'key': 'active_ai_provider', 
        'value': _selectedAiProvider
      });
      
      await _supabase.from('app_config').upsert({
        'key': 'active_ai_model', 
        'value': _modelNameController.text.trim()
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All Configurations Updated Successfully! 🚀"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Save failed: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings, size: 28, color: AppColors.primaryStart),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("System Configuration", style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text("Control Plans & AI Brain", style: GoogleFonts.outfit(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // 🤖 AI CONFIG SECTION
                  Text("AI Brain Settings", style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                      border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.psychology, color: Colors.purple),
                            const SizedBox(width: 10),
                            Text("Active Provider", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _selectedAiProvider,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.purple.withValues(alpha: 0.05),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'gemini', child: Text("Google Gemini (Recommended)")),
                            DropdownMenuItem(value: 'openai', child: Text("OpenAI (GPT-4 / 3.5)")),
                            DropdownMenuItem(value: 'deepseek', child: Text("DeepSeek (Cost Effective)")),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedAiProvider = val!;
                              _setDefaultModelName(val);
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        Row(
                          children: [
                            const Icon(Icons.model_training, color: Colors.purple),
                            const SizedBox(width: 10),
                            Text("Model Name", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: _modelNameController,
                          decoration: InputDecoration(
                            hintText: "e.g. gemini-1.5-flash",
                            helperText: "Enter the exact model ID for the API",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 📦 PLANS SECTION
                  Text("Subscription Plans", style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  if (_plans.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                      child: const Text("⚠️ No plans found in Database. Please run the SQL setup script."),
                    )
                  else
                    ..._plans.map((plan) => _buildEditablePlanCard(plan)).toList(),

                  const SizedBox(height: 40),

                  // SAVE BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveAllChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryStart,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 5,
                      ),
                      icon: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Icon(Icons.save_rounded, size: 28),
                      label: Text(
                        _isLoading ? "SAVING..." : "UPDATE CONFIGURATION", 
                        style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildEditablePlanCard(Map<String, dynamic> plan) {
    Color cardColor;
    if (plan['id'] == 'pro') cardColor = Colors.purple;
    else if (plan['id'] == 'mini') cardColor = Colors.orange;
    else cardColor = Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardColor.withValues(alpha: 0.1), width: 1),
          gradient: LinearGradient(
            colors: [Colors.white, cardColor.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.stars, color: cardColor),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan['id'].toString().toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        SizedBox(
                          width: 180,
                          child: TextFormField(
                            initialValue: plan['name'],
                            style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none),
                            onChanged: (val) => plan['name'] = val,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text("Popular?", style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey)),
                    Switch(
                      value: plan['is_popular'] ?? false,
                      activeColor: Colors.amber,
                      onChanged: (val) => setState(() => plan['is_popular'] = val),
                    ),
                  ],
                )
              ],
            ),
            const Divider(height: 30),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildInputField(
                    label: "Credits", icon: Icons.bolt, initialValue: plan['credits'].toString(), color: Colors.amber.shade700,
                    onChanged: (val) => plan['credits'] = int.tryParse(val) ?? plan['credits'],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildInputField(
                    label: "Price (PKR)", icon: Icons.payments_outlined, initialValue: plan['price_pkr'].toString(), color: Colors.green, prefixText: "Rs ",
                    onChanged: (val) => plan['price_pkr'] = int.tryParse(val) ?? plan['price_pkr'],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildInputField(
                    label: "USD", icon: Icons.attach_money, initialValue: plan['price_usd'].toString(), color: Colors.blueGrey,
                    onChanged: (val) => plan['price_usd'] = int.tryParse(val) ?? plan['price_usd'],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label, required IconData icon, required String initialValue, required Color color, String? prefixText, required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initialValue,
          keyboardType: TextInputType.number,
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 16),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            prefixIcon: prefixText == null 
              ? Icon(icon, size: 18, color: color)
              : Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: color), const SizedBox(width: 4), Text(prefixText, style: TextStyle(color: color, fontWeight: FontWeight.bold))]),
                ),
            prefixIconConstraints: const BoxConstraints(minWidth: 40, maxHeight: 40),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: 2)),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
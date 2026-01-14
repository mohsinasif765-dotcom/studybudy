import 'package:flutter/material.dart';
import 'package:prepvault_ai/core/widgets/smart_banner_ad.dart'; // Apka banner widget

class MainLayout extends StatelessWidget {
  final Widget body; // Screen ka asli content
  final String? title; // AppBar title (Optional)
  final List<Widget>? actions; // AppBar actions (Optional)
  final Widget? floatingActionButton; // FAB (Optional)
  final bool showAd; // Agar kisi screen par ad nahi dikhana to false karden

  const MainLayout({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.showAd = true, // By default Ad dikhaye ga
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      
      // 1. Common AppBar (Har screen par same style)
      appBar: title != null 
          ? AppBar(
              title: Text(title!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              iconTheme: const IconThemeData(color: Colors.black),
              actions: actions,
            )
          : null, // Agar title nahi dia to AppBar gayab

      // 2. Body + Ad Logic
      body: Column(
        children: [
          // Screen ka Content (Expanded taakay full jagah lay)
          Expanded(child: body),

          // 👇 MAGIC: Banner Ad yahan automatically aa jaye ga
          if (showAd) 
            const SafeArea(
              top: false, 
              child: SmartBannerAd()
            ),
        ],
      ),

      floatingActionButton: floatingActionButton,
    );
  }
}
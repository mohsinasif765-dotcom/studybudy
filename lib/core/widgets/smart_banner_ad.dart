import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:prepvault_ai/core/services/ad_service.dart';

class SmartBannerAd extends StatefulWidget {
  const SmartBannerAd({super.key});

  @override
  State<SmartBannerAd> createState() => _SmartBannerAdState();
}

class _SmartBannerAdState extends State<SmartBannerAd> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    // 1. Check hata diya, direct create function call karein.
    // AdService andar khud check karega ke user VIP hai ya nahi.
    
    _bannerAd = AdService().createBannerAd((ad) {
      debugPrint("✅ Banner Ad Loaded Successfully!");
      if (mounted) {
        setState(() => _isAdLoaded = true);
      }
    });

    // 2. Load Request bhejo
    if (_bannerAd != null) {
      debugPrint("⏳ Requesting Banner Ad...");
      _bannerAd!.load();
    } else {
      debugPrint("🚫 Banner Ad Skip hua (VIP User ya Web)");
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 3. Agar load nahi hua, to jagah mat ghero
    if (_bannerAd == null || !_isAdLoaded) {
      return const SizedBox.shrink(); 
    }

    return Container(
      color: Colors.transparent,
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
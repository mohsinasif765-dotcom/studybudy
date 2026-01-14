import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // --- IDs UPDATED ---
  // Note: Web aur iOS ke liye abhi bhi Test IDs hain taake crash na ho.
  // Sirf Android section mein Real IDs lagayi hain.

  final String _bannerId = kIsWeb 
      ? 'ca-app-pub-3940256099942544/6300978111' 
      : Platform.isAndroid 
          ? 'ca-app-pub-4146695109116626/9635612519' // ✅ REAL BANNER ID
          : 'ca-app-pub-3940256099942544/2934735716';

  final String _rewardedId = kIsWeb 
      ? 'ca-app-pub-3940256099942544/5224354917' 
      : Platform.isAndroid 
          ? 'ca-app-pub-4146695109116626/4455438027' // ✅ REAL REWARDED ID
          : 'ca-app-pub-3940256099942544/1712485313';

  final String _interstitialId = kIsWeb 
      ? 'ca-app-pub-3940256099942544/1033173712' 
      : Platform.isAndroid 
          ? 'ca-app-pub-4146695109116626/4702850037' // ✅ REAL INTERSTITIAL ID
          : 'ca-app-pub-3940256099942544/4411468910';

  final ValueNotifier<bool> isFreeUserNotifier = ValueNotifier<bool>(true);

  bool get isFreeUser => isFreeUserNotifier.value;

  // --- 1. SUBSCRIPTION CHECK ---
  Future<void> updateSubscriptionStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('profiles')
          .select('plan_id, is_vip')
          .eq('id', userId)
          .single();

      final String planId = response['plan_id'] ?? 'free';
      final bool isVip = response['is_vip'] ?? false;

      bool status = (planId == 'free') && !isVip;

      isFreeUserNotifier.value = status;
      
      debugPrint("📢 [AD SERVICE] Is Free User (Notifier Updated): $status");

    } catch (e) {
      isFreeUserNotifier.value = true; 
    }
  }

  // --- 2. INTERSTITIAL AD ---
  InterstitialAd? _interstitialAd;
  
  void loadInterstitialAd() {
    if (kIsWeb || !isFreeUser) return; 

    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  void showInterstitialAd({required VoidCallback onAdClosed}) {
    if (kIsWeb || !isFreeUser || _interstitialAd == null) {
      onAdClosed();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        onAdClosed(); 
        loadInterstitialAd(); 
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        onAdClosed();
        loadInterstitialAd();
      }
    );

    _interstitialAd!.show();
    _interstitialAd = null;
  }

  // --- 3. REWARDED AD ---
  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;

  void loadRewardedAd() {
    if (kIsWeb) return;
    if (_isRewardedLoading) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("✅ Rewarded Ad Loaded");
          _rewardedAd = ad;
          _isRewardedLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint("❌ Rewarded Ad Failed: $error");
          _rewardedAd = null;
          _isRewardedLoading = false;
        },
      ),
    );
  }

  Future<bool> showRewardedAd() async {
    final Completer<bool> completer = Completer<bool>();

    if (kIsWeb) return true; 

    if (_rewardedAd == null) {
      debugPrint("⚠️ Ad not ready. Loading now...");
      loadRewardedAd(); 
      return false; 
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        if (!completer.isCompleted) completer.complete(true);
      },
    );

    _rewardedAd = null;
    return completer.future;
  }

  // --- 4. BANNER AD ---
  BannerAd? createBannerAd(Function(Ad) onLoaded) {
    if (kIsWeb || !isFreeUser) return null;
    
    return BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
  }
}
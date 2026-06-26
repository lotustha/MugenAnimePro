import 'dart:async';

import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'remote_settings_service.dart';

/// Centralizes ad loading/showing behind a provider switch driven by Remote
/// Config (`mugenpro_ads_provider`). Currently only AdMob is implemented;
/// `none` disables ads, and the abstraction leaves room for another provider
/// (e.g. Unity) without touching call sites.
class AdsService extends GetxService {
  RemoteSettingsService get _settings => Get.find<RemoteSettingsService>();

  bool _mobileAdsReady = false;

  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;

  RewardedAd? _rewarded;
  bool _loadingRewarded = false;

  bool get _admobActive => _settings.adsProvider.value == 'admob';

  /// True when any ad provider is active (used to show/hide native ad cells).
  bool get enabled => _settings.adsProvider.value != 'none';

  String get nativeAdUnitId => _settings.admobNativeId.value;

  /// Whether native (in-feed) ads can be shown — AdMob only.
  bool get nativeEnabled => _admobActive && nativeAdUnitId.isNotEmpty;

  Future<AdsService> init() async {
    try {
      await MobileAds.instance.initialize();
      _mobileAdsReady = true;
    } catch (_) {
      return this; // Play Services / SDK unavailable — app runs without ads.
    }
    if (_admobActive) {
      _loadInterstitial();
      _loadRewarded();
    }
    return this;
  }

  // ─── Interstitial ───────────────────────────────────────────────────────────

  void _loadInterstitial() {
    if (!_mobileAdsReady ||
        _loadingInterstitial ||
        _interstitial != null ||
        !_admobActive) {
      return;
    }
    final id = _settings.admobInterstitialId.value;
    if (id.isEmpty) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: id,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitial = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitial = null;
              _loadInterstitial(); // preload the next one
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitial = null;
              _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _loadingInterstitial = false;
          _interstitial = null;
        },
      ),
    );
  }

  /// Show the interstitial immediately if one is loaded; preload otherwise.
  /// (Called on every non-locked episode open.)
  void showInterstitialNow() {
    if (!_admobActive) return;
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial(); // not ready (e.g. just consumed) — preload next
      return;
    }
    _interstitial = null;
    ad.show();
  }

  // ─── Rewarded ────────────────────────────────────────────────────────────────

  void _loadRewarded() {
    if (!_mobileAdsReady ||
        _loadingRewarded ||
        _rewarded != null ||
        !_admobActive) {
      return;
    }
    final id = _settings.admobRewardedId.value;
    if (id.isEmpty) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: id,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewarded = ad;
        },
        onAdFailedToLoad: (_) {
          _loadingRewarded = false;
          _rewarded = null;
        },
      ),
    );
  }

  /// Shows a rewarded ad. Resolves true only if the user earned the reward.
  Future<bool> showRewarded() async {
    if (!_admobActive) return false;
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    final completer = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (_, __) => earned = true);
    return completer.future;
  }

  @override
  void onClose() {
    _interstitial?.dispose();
    _rewarded?.dispose();
    super.onClose();
  }
}

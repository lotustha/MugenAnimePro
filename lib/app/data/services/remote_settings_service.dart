import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/constants/api_constants.dart';
import '../providers/api_client.dart';
import 'storage_service.dart';

/// App links (support / socials / website) sourced from Firebase Remote
/// Config, with safe local defaults so the UI works before Firebase is set up.
///
/// Finish Firebase setup once `google-services.json` is available:
///   1. Drop `google-services.json` into `android/app/`.
///   2. In `android/settings.gradle.kts`, add to the plugins block:
///        id("com.google.gms.google-services") version "4.4.2" apply false
///      and in `android/app/build.gradle.kts` plugins block apply it:
///        id("com.google.gms.google-services")
///   3. In the Remote Config console create string keys:
///        support_url, facebook_url, discord_url, website_url
/// Until then this service silently keeps the (empty) defaults.
class RemoteSettingsService extends GetxService {
  static const _kSupport = 'support_url';
  static const _kFacebook = 'facebook_url';
  static const _kDiscord = 'discord_url';
  static const _kWebsite = 'website_url';
  // Anime backend provider (anivid | anizen | animelok | …). Empty = keep the
  // app's built-in default. Lets us switch providers without an app update.
  // Prefer the `mugenpro_`-prefixed key (per-app), fall back to the legacy one.
  static const _kProvider = 'anime_provider';
  static const _kProviderPrefixed = 'mugenpro_anime_provider';

  // Ad config. Keys are prefixed `mugenpro_` so this app's values are namespaced
  // separately from other apps in the shared Firebase project. Provider switch:
  // `admob` | `none` (room for `unity` later).
  static const _kAdsProvider = 'mugenpro_ads_provider';
  static const _kAdsInterstitialEvery = 'mugenpro_ads_interstitial_every';
  static const _kAdmobInterstitial = 'mugenpro_admob_interstitial_id';
  static const _kAdmobRewarded = 'mugenpro_admob_rewarded_id';
  static const _kAdmobNative = 'mugenpro_admob_native_id';
  // Streaming API host override (empty = keep the built-in default).
  static const _kApiBaseUrl = 'mugenpro_api_base_url';
  // When true, opening an episode shows a rewarded "unlock" ad (fail-open).
  static const _kRewardedUnlock = 'mugenpro_ads_rewarded_unlock';

  static const Map<String, String> _defaults = {
    _kSupport: '',
    _kFacebook: '',
    _kDiscord: '',
    _kWebsite: '',
    _kProvider: '',
    _kProviderPrefixed: '',
    _kAdsProvider: 'admob',
    _kAdsInterstitialEvery: '3',
    _kAdmobInterstitial: 'ca-app-pub-1368455939381864/1285079930',
    _kAdmobRewarded: 'ca-app-pub-1368455939381864/2798683603',
    _kAdmobNative: 'ca-app-pub-1368455939381864/4898233331',
    _kApiBaseUrl: '',
    _kRewardedUnlock: 'true',
  };

  final RxString supportUrl = ''.obs;
  final RxString facebookUrl = ''.obs;
  final RxString discordUrl = ''.obs;
  final RxString websiteUrl = ''.obs;

  // Ad config, reactive so a remote change applies without an app update.
  final RxString adsProvider = 'admob'.obs;
  final RxInt adsInterstitialEvery = 3.obs;
  final RxString admobInterstitialId = ''.obs;
  final RxString admobRewardedId = ''.obs;
  final RxString admobNativeId = ''.obs;
  final RxBool rewardedUnlock = true.obs;
  // Streaming provider in use (Remote-Config driven), reactive so the Settings
  // "Streaming source" row updates when the console changes it.
  final RxString animeProvider = ApiConstants.provider.obs;

  Future<RemoteSettingsService> init() async {
    _apply(_defaults);
    // Don't block startup on the network; the UI is reactive and fills in once
    // the remote values arrive (or stays on defaults if Firebase isn't set up).
    _loadRemote();
    return this;
  }

  Future<void> _loadRemote() async {
    try {
      await Firebase.initializeApp();
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // Debug: fetch fresh almost every launch so console changes (provider,
        // ad config, …) apply within seconds while testing. Release keeps a
        // 1-hour cache to limit network.
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 1),
      ));
      await rc.setDefaults(_defaults);
      await rc.fetchAndActivate();
      _readFrom(rc);
    } catch (_) {
      // Firebase not configured yet (no google-services.json) — keep defaults.
    }
  }

  /// Re-fetch on demand (Settings pull-to-refresh).
  Future<void> refresh() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.fetchAndActivate();
      _readFrom(rc);
    } catch (_) {}
  }

  void _readFrom(FirebaseRemoteConfig rc) {
    _apply({
      _kSupport: rc.getString(_kSupport),
      _kFacebook: rc.getString(_kFacebook),
      _kDiscord: rc.getString(_kDiscord),
      _kWebsite: rc.getString(_kWebsite),
      _kAdsProvider: rc.getString(_kAdsProvider),
      _kAdsInterstitialEvery: rc.getString(_kAdsInterstitialEvery),
      _kAdmobInterstitial: rc.getString(_kAdmobInterstitial),
      _kAdmobRewarded: rc.getString(_kAdmobRewarded),
      _kAdmobNative: rc.getString(_kAdmobNative),
      _kApiBaseUrl: rc.getString(_kApiBaseUrl),
      _kRewardedUnlock: rc.getString(_kRewardedUnlock),
    });
    // Override the anime provider if the console specifies one (prefixed wins).
    final prefixed = rc.getString(_kProviderPrefixed).trim();
    final legacy = rc.getString(_kProvider).trim();
    final p = prefixed.isNotEmpty ? prefixed : legacy;
    if (p.isNotEmpty && p != ApiConstants.provider) {
      ApiConstants.provider = p;
      animeProvider.value = p;
      // Swap favorites/history to the new provider's namespace (kept, not wiped).
      if (Get.isRegistered<StorageService>()) {
        Get.find<StorageService>().reloadForProvider();
      }
    }
  }

  void _apply(Map<String, String> v) {
    supportUrl.value = v[_kSupport] ?? '';
    facebookUrl.value = v[_kFacebook] ?? '';
    discordUrl.value = v[_kDiscord] ?? '';
    websiteUrl.value = v[_kWebsite] ?? '';
    // Ads (only overwrite when the key is present so partial maps don't clobber).
    final provider = v[_kAdsProvider]?.trim();
    if (provider != null && provider.isNotEmpty) adsProvider.value = provider;
    final every = int.tryParse(v[_kAdsInterstitialEvery] ?? '');
    if (every != null) adsInterstitialEvery.value = every;
    final inter = v[_kAdmobInterstitial];
    if (inter != null && inter.isNotEmpty) admobInterstitialId.value = inter;
    final rew = v[_kAdmobRewarded];
    if (rew != null && rew.isNotEmpty) admobRewardedId.value = rew;
    final nat = v[_kAdmobNative];
    if (nat != null && nat.isNotEmpty) admobNativeId.value = nat;
    final unlock = v[_kRewardedUnlock]?.trim().toLowerCase();
    if (unlock != null && unlock.isNotEmpty) {
      rewardedUnlock.value = unlock == 'true' || unlock == '1';
    }
    // API host override: update the constant (for clients built later) and the
    // already-constructed Dio client (for clients built before this arrived).
    final api = v[_kApiBaseUrl]?.trim();
    if (api != null && api.isNotEmpty) {
      ApiConstants.baseUrl = api;
      if (Get.isRegistered<ApiClient>()) Get.find<ApiClient>().setBaseUrl(api);
    }
  }
}

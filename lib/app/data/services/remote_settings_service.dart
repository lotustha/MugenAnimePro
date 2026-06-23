import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:get/get.dart';

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

  static const Map<String, String> _defaults = {
    _kSupport: '',
    _kFacebook: '',
    _kDiscord: '',
    _kWebsite: '',
  };

  final RxString supportUrl = ''.obs;
  final RxString facebookUrl = ''.obs;
  final RxString discordUrl = ''.obs;
  final RxString websiteUrl = ''.obs;

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
        minimumFetchInterval: const Duration(hours: 1),
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

  void _readFrom(FirebaseRemoteConfig rc) => _apply({
        _kSupport: rc.getString(_kSupport),
        _kFacebook: rc.getString(_kFacebook),
        _kDiscord: rc.getString(_kDiscord),
        _kWebsite: rc.getString(_kWebsite),
      });

  void _apply(Map<String, String> v) {
    supportUrl.value = v[_kSupport] ?? '';
    facebookUrl.value = v[_kFacebook] ?? '';
    discordUrl.value = v[_kDiscord] ?? '';
    websiteUrl.value = v[_kWebsite] ?? '';
  }
}

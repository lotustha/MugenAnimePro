import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/api_constants.dart';
import '../../data/services/remote_settings_service.dart';
import '../../data/services/storage_service.dart';

class SettingsController extends GetxController {
  final RemoteSettingsService settings = Get.find();
  final StorageService _storage = Get.find();

  /// Playback preferences (mirrors of the persisted storage values).
  final RxBool preferDub = false.obs;
  final RxBool newestFirst = false.obs;

  /// App version string for the About section.
  final RxnString appVersion = RxnString();

  @override
  void onInit() {
    super.onInit();
    preferDub.value = _storage.preferDub;
    newestFirst.value = !_storage.episodesAscending; // newest first = descending
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion.value = '${info.version} (${info.buildNumber})';
    } catch (_) {
      appVersion.value = null;
    }
  }

  /// Default audio: true = English (Dub), false = Japanese (Sub).
  void setPreferDub(bool value) {
    preferDub.value = value;
    _storage.preferDub = value;
  }

  /// Episode list order: true = newest first (descending).
  void setNewestFirst(bool value) {
    newestFirst.value = value;
    _storage.episodesAscending = !value;
  }

  /// Streaming provider currently in use (set via Remote Config).
  String get providerName => ApiConstants.provider;

  int get continueWatchingCount => _storage.continueWatching.length;

  void clearContinueWatching() {
    _storage.clearAllProgress();
    Get.snackbar('Cleared', 'Your continue-watching list was removed.',
        snackPosition: SnackPosition.BOTTOM);
  }

  /// Open [url] in the external browser/app. Shows a hint if it isn't set.
  Future<void> open(String url) async {
    if (url.isEmpty) {
      Get.snackbar('Unavailable', 'This link isn\'t available yet.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.snackbar('Couldn\'t open', url);
    }
  }
}

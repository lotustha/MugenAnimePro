import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/api_constants.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/push_service.dart';
import '../../data/services/remote_settings_service.dart';
import '../../data/services/storage_service.dart';

class SettingsController extends GetxController {
  final RemoteSettingsService settings = Get.find();
  final StorageService _storage = Get.find();

  /// Playback preferences (mirrors of the persisted storage values).
  final RxBool preferDub = false.obs;
  final RxBool newestFirst = false.obs;

  /// Notification preferences (mirrors of the persisted storage values).
  final RxBool notifAll = true.obs;
  final RxBool notifEpisodes = true.obs;
  final RxBool notifFavoritesOnly = true.obs;
  final RxBool notifWallpapers = true.obs;
  final RxBool notifNews = true.obs;

  /// App version string for the About section.
  final RxnString appVersion = RxnString();

  @override
  void onInit() {
    super.onInit();
    preferDub.value = _storage.preferDub;
    newestFirst.value = !_storage.episodesAscending; // newest first = descending
    notifAll.value = _storage.notifAll;
    notifEpisodes.value = _storage.notifEpisodes;
    notifFavoritesOnly.value = _storage.notifEpisodesFavoritesOnly;
    notifWallpapers.value = _storage.notifWallpapers;
    notifNews.value = _storage.notifNews;
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

  // ─────────────────────────────────────────────────────── notifications
  /// Master switch. Turning it on (re)requests the OS permission; off cancels
  /// every topic + scheduled reminder.
  Future<void> setNotifAll(bool value) async {
    notifAll.value = value;
    _storage.notifAll = value;
    if (value && Get.isRegistered<NotificationService>()) {
      await Get.find<NotificationService>().requestPermission();
    }
    await _applyNotifications();
  }

  void setNotifEpisodes(bool value) {
    notifEpisodes.value = value;
    _storage.notifEpisodes = value;
    _applyNotifications();
  }

  /// Anime episode alerts: favourites-only (per-anime topics) vs all (broadcast).
  void setNotifFavoritesOnly(bool value) {
    notifFavoritesOnly.value = value;
    _storage.notifEpisodesFavoritesOnly = value;
    _applyNotifications();
  }

  void setNotifWallpapers(bool value) {
    notifWallpapers.value = value;
    _storage.notifWallpapers = value;
    _applyNotifications();
  }

  void setNotifNews(bool value) {
    notifNews.value = value;
    _storage.notifNews = value;
    _applyNotifications();
  }

  /// Push the current notification prefs to FCM topics + local reminders.
  Future<void> _applyNotifications() async {
    if (Get.isRegistered<PushService>()) {
      await Get.find<PushService>().applyTopicSubscriptions();
    }
    if (Get.isRegistered<NotificationService>()) {
      final ns = Get.find<NotificationService>();
      if (notifAll.value && notifEpisodes.value) {
        ns.rescheduleAll();
      } else {
        ns.cancelAllReminders();
      }
    }
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

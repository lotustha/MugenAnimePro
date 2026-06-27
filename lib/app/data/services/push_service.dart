import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/constants/api_constants.dart';
import '../../core/notifications/notification_router.dart';
import 'notification_service.dart';
import 'storage_service.dart';

/// Top-level FCM background handler. Required to be registered, but does no UI
/// work: messages that carry a `notification` block are rendered in the system
/// tray by Android automatically, and the tap is routed via
/// [FirebaseMessaging.onMessageOpenedApp] / [getInitialMessage] once the app
/// is foregrounded.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op. Kept so the plugin has a registered background entry point.
}

/// Receives push notifications from mugenstream.fun:
///   - new_episodes   → "🆕 New Episode" (channel: episodes)
///   - new_posts      → "📰 New Article" (channel: posts)
///   - new_wallpapers → "🖼️ New Wallpaper" (channel: wallpapers)
///
/// Subscribes via FCM topics (no per-device targeting needed) and also
/// registers the device token with the website so it can be targeted directly.
class PushService extends GetxService {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Message that cold-started the app via a notification tap, if any. Flushed
  /// by [flushInitialMessage] once the first frame is on screen.
  RemoteMessage? _initialMessage;

  Future<PushService> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Topic subscriptions — content broadcasts, gated by the user's settings.
      await applyTopicSubscriptions();

      // Device token registration (best-effort).
      final token = await messaging.getToken();
      debugPrint('[push] FCM token: ${token == null ? "null" : "${token.substring(0, 12)}…"}');
      if (token != null) await _registerToken(token);
      messaging.onTokenRefresh.listen(_registerToken);

      // Foreground: show our own local notification (FCM doesn't display one).
      FirebaseMessaging.onMessage.listen(_onForeground);

      // Background tap (app alive but backgrounded).
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);

      // Cold start via notification tap.
      _initialMessage = await messaging.getInitialMessage();

      // Firebase In-App Messaging — campaigns authored in the Firebase console.
      // The SDK shows them automatically; trigger an app_open event so
      // event-triggered campaigns can fire on launch.
      await FirebaseInAppMessaging.instance.setAutomaticDataCollectionEnabled(true);
      await FirebaseInAppMessaging.instance.triggerEvent('app_open');
    } catch (_) {
      // Firebase not configured / no Play Services — app still works without push.
    }
    return this;
  }

  /// Subscribe/unsubscribe the content-broadcast topics to match the user's
  /// notification settings (master switch + per-category). Called on init and
  /// whenever a Settings toggle changes.
  ///
  /// Anime new-episode delivery has two modes:
  ///   • "All"        → the general `new_episodes` broadcast.
  ///   • "Favourites" → unsubscribe the broadcast and instead subscribe a
  ///     per-anime topic for each favourite (see [animeTopic]); the server
  ///     sends each new episode to that topic too, so only favouriters get it.
  Future<void> applyTopicSubscriptions() async {
    try {
      final s = Get.find<StorageService>();
      final m = FirebaseMessaging.instance;
      final all = s.notifAll;
      final episodes = all && s.notifEpisodes;
      final favOnly = episodes && s.notifEpisodesFavoritesOnly;
      // Episode topics are scoped to the active provider so you only get alerts
      // for the API you're currently using. News/wallpapers are website content
      // (provider-independent) so they stay global.
      await _setTopic(
          m, 'new_episodes_${ApiConstants.provider}', episodes && !favOnly);
      await _setTopic(m, 'new_posts', all && s.notifNews);
      await _setTopic(m, 'new_wallpapers', all && s.notifWallpapers);
      // Per-anime favourite topics (current provider): subscribed in faves mode.
      for (final a in s.favorites) {
        await _setTopic(m, animeTopic(a.title), favOnly);
      }
    } catch (_) {
      // Offline / Firebase not configured — retried on the next launch.
    }
  }

  Future<void> _setTopic(FirebaseMessaging m, String topic, bool on) =>
      on ? m.subscribeToTopic(topic) : m.unsubscribeFromTopic(topic);

  /// Stable, provider-scoped FCM topic for an anime, derived from its name. The
  /// website push code MUST sanitize the name the same way to target it:
  ///   lowercase → non-alphanumerics to `_` → collapse/trim `_` → cap 180 →
  ///   prefix `anime_<provider>_`. (FCM topics allow `[a-zA-Z0-9-_.~%]`.)
  static String animeTopic(String name, [String? provider]) {
    final p = provider ?? ApiConstants.provider;
    var s = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (s.length > 180) s = s.substring(0, 180);
    return 'anime_${p}_$s';
  }

  /// Switching the API provider: drop the previous provider's episode topics
  /// (so you stop getting its alerts) and re-apply for the new one.
  Future<void> onProviderChanged(String oldProvider) async {
    try {
      final m = FirebaseMessaging.instance;
      final s = Get.find<StorageService>();
      await m.unsubscribeFromTopic('new_episodes_$oldProvider');
      for (final a in s.favoritesFor(oldProvider)) {
        await m.unsubscribeFromTopic(animeTopic(a.title, oldProvider));
      }
    } catch (_) {}
    await applyTopicSubscriptions();
  }

  /// Subscribe/unsubscribe a single anime's topic — called when a favourite is
  /// added/removed (no-op unless episode notifications are in favourites mode).
  Future<void> syncAnimeTopic(String name, {required bool subscribe}) async {
    try {
      final s = Get.find<StorageService>();
      if (!(s.notifAll && s.notifEpisodes && s.notifEpisodesFavoritesOnly)) {
        return;
      }
      await _setTopic(FirebaseMessaging.instance, animeTopic(name),
          subscribe);
    } catch (_) {}
  }

  /// Call once the navigation stack is ready (e.g. RootView first frame).
  void flushInitialMessage() {
    final msg = _initialMessage;
    _initialMessage = null;
    if (msg != null) NotificationRouter.route(_dataOf(msg));
  }

  void _onForeground(RemoteMessage message) {
    // Respect the master switch (topics are also unsubscribed, but a message may
    // already be in flight when the user turns notifications off).
    try {
      if (!Get.find<StorageService>().notifAll) return;
    } catch (_) {}
    final data = _dataOf(message);
    debugPrint('[push] foreground message: type=${data['type']} id=${data['id']}');
    final n = message.notification;
    final title = n?.title ?? data['title']?.toString() ?? 'Mugenstream';
    final body = n?.body ?? data['body']?.toString() ?? '';
    if (body.isEmpty && n == null) return;

    Get.find<NotificationService>().showRemote(
      title: title,
      body: body,
      channelId: _channelFor(data['type']?.toString()),
      payload: NotificationRouter.encodePayload(data),
    );
  }

  void _onOpened(RemoteMessage message) => NotificationRouter.route(_dataOf(message));

  Map<String, dynamic> _dataOf(RemoteMessage m) =>
      m.data.map((k, v) => MapEntry(k, v));

  String _channelFor(String? type) {
    switch (type) {
      case 'episode':
        return 'episodes';
      case 'post':
        return 'posts';
      case 'wallpaper':
        return 'wallpapers';
      default:
        return 'general';
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await _dio.post(ApiConstants.notifications(),
          data: {'token': token, 'platform': 'android'});
    } catch (_) {/* best-effort */}
  }
}

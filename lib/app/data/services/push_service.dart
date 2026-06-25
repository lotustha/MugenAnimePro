import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/constants/api_constants.dart';
import '../../core/notifications/notification_router.dart';
import 'notification_service.dart';

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
  static const _topics = <String>['new_episodes', 'new_posts', 'new_wallpapers'];

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

      // Topic subscriptions — content broadcasts.
      for (final t in _topics) {
        await messaging.subscribeToTopic(t);
      }
      debugPrint('[push] subscribed to topics: $_topics');

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

  /// Call once the navigation stack is ready (e.g. RootView first frame).
  void flushInitialMessage() {
    final msg = _initialMessage;
    _initialMessage = null;
    if (msg != null) NotificationRouter.route(_dataOf(msg));
  }

  void _onForeground(RemoteMessage message) {
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

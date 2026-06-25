import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../routes/app_pages.dart';

/// Routes a notification tap (from FCM or a local notification) to the right
/// place in the app.
///
/// The `data` map is the FCM message data payload (see the website's
/// push-notifications.ts). Episodes/anime open the in-app detail screen;
/// posts and wallpapers have no in-app screen yet, so they open the website.
class NotificationRouter {
  NotificationRouter._();

  /// Handle a parsed FCM/local-notification payload.
  static Future<void> route(Map<String, dynamic> data) async {
    final type = (data['type'] ?? '').toString();
    final id = (data['id'] ?? '').toString();
    final slug = (data['slug'] ?? '').toString();
    debugPrint('[router] routing type=$type id=$id slug=$slug');

    switch (type) {
      case 'episode':
      case 'anime':
        if (id.isNotEmpty) Get.toNamed(Routes.detail, arguments: id);
        return;

      case 'post':
        final s = slug.isNotEmpty ? slug : id;
        if (s.isNotEmpty) Get.toNamed(Routes.newsDetail, arguments: s);
        return;

      case 'wallpaper':
        if (id.isNotEmpty) Get.toNamed(Routes.wallpaperDetail, arguments: id);
        return;

      default:
        // Fall back to any http(s) deep link the payload carried.
        final deepLink = (data['deepLink'] ?? '').toString();
        if (deepLink.startsWith('http')) await _openWeb(deepLink);
        return;
    }
  }

  /// Convenience for a local-notification tap, whose payload is a single string.
  /// We encode the FCM data map as `type|id|slug` when showing local notifs.
  static Future<void> routePayload(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    final parts = payload.split('|');
    await route({
      'type': parts.isNotEmpty ? parts[0] : '',
      'id': parts.length > 1 ? parts[1] : '',
      'slug': parts.length > 2 ? parts[2] : '',
    });
  }

  /// Encode an FCM data map into the `type|id|slug` payload string carried by a
  /// local notification (flutter_local_notifications only passes a String).
  static String encodePayload(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    final id = (data['id'] ?? '').toString();
    final slug = (data['slug'] ?? '').toString();
    return '$type|$id|$slug';
  }

  static Future<void> _openWeb(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {/* ignore */}
  }
}

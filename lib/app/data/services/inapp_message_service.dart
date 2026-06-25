import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/api_constants.dart';

/// Fetches active in-app messages from mugenstream.fun on launch and shows the
/// highest-priority one as a themed overlay. Messages are authored in the
/// website admin ("in-app message form") and delivered by polling — no FCM.
///
/// Endpoint: GET /api/in-app-messages?deviceId={id}
/// Tracking: POST /api/in-app-messages/track { messageId, event, deviceId }
class InAppMessageService extends GetxService {
  static const _deviceKey = 'inapp_device_id';

  final _box = GetStorage();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  late final String _deviceId;

  Future<InAppMessageService> init() async {
    var id = _box.read<String>(_deviceKey);
    if (id == null || id.isEmpty) {
      id = 'dev-${DateTime.now().microsecondsSinceEpoch}-${hashCode & 0xffff}';
      await _box.write(_deviceKey, id);
    }
    _deviceId = id;
    return this;
  }

  /// Call once the navigator is ready (e.g. RootView first frame).
  Future<void> maybeShowOnLaunch() async {
    try {
      final res = await _dio.get(
        ApiConstants.inAppMessages(),
        queryParameters: {'deviceId': _deviceId},
      );
      final list = res.data;
      if (list is! List || list.isEmpty) return;
      final msg = list.first as Map<String, dynamic>;
      await _show(msg);
    } catch (_) {/* offline / no messages — ignore */}
  }

  Future<void> _track(String messageId, String event) async {
    try {
      await _dio.post(ApiConstants.inAppMessagesTrack(),
          data: {'messageId': messageId, 'event': event, 'deviceId': _deviceId});
    } catch (_) {}
  }

  Future<void> _show(Map<String, dynamic> m) async {
    final id = (m['id'] ?? '').toString();
    if (id.isEmpty) return;

    final title = (m['title'] ?? '').toString();
    final body = (m['body'] ?? '').toString();
    final imageUrl = (m['imageUrl'] ?? '').toString();
    final buttonText = (m['buttonText'] ?? '').toString();
    final buttonUrl = (m['buttonUrl'] ?? '').toString();
    final cancelable = m['cancelable'] != false;

    _track(id, 'impression');

    await Get.dialog(
      _InAppDialog(
        title: title,
        body: body,
        imageUrl: imageUrl,
        buttonText: buttonText,
        cancelable: cancelable,
        onButton: buttonUrl.isEmpty
            ? null
            : () async {
                _track(id, 'click');
                if (Get.isDialogOpen ?? false) Get.back();
                await _open(buttonUrl);
              },
        onClose: () {
          if (Get.isDialogOpen ?? false) Get.back();
        },
      ),
      barrierDismissible: cancelable,
    );
  }

  Future<void> _open(String url) async {
    try {
      final uri = Uri.parse(url);
      // mugenstream:// deep links are handled in-app by NotificationRouter;
      // everything else opens externally.
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

class _InAppDialog extends StatelessWidget {
  final String title;
  final String body;
  final String imageUrl;
  final String buttonText;
  final bool cancelable;
  final VoidCallback? onButton;
  final VoidCallback onClose;

  const _InAppDialog({
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.buttonText,
    required this.cancelable,
    required this.onButton,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8B5CF6);
    return Dialog(
      backgroundColor: const Color(0xFF0F0A1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0x338B5CF6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(
                imageUrl,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (cancelable)
                      GestureDetector(
                        onTap: onClose,
                        child: const Icon(Icons.close, color: Colors.white38, size: 20),
                      ),
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(body,
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
                if (onButton != null && buttonText.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onButton,
                      child: Text(buttonText,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

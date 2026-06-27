import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/theme/app_theme.dart';
import '../data/services/ads_service.dart';
import '../data/services/remote_settings_service.dart';

/// "Support us" card — watch a rewarded ad to support the app. Mirrors the
/// Settings entry and renders nothing when ads are disabled (provider = none).
class SupportUsTile extends StatelessWidget {
  const SupportUsTile({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<RemoteSettingsService>()) {
      return const SizedBox.shrink();
    }
    final settings = Get.find<RemoteSettingsService>();
    return Obx(() {
      if (settings.adsProvider.value == 'none') return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Material(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _support,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.card_giftcard, color: AppTheme.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Support us',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text('Watch a short ad to support the app',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.play_circle_outline, color: Colors.white38),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Future<void> _support() async {
    if (!Get.isRegistered<AdsService>()) return;
    final earned = await Get.find<AdsService>().showRewarded();
    Get.snackbar(
      earned ? 'Thank you!' : 'No ad available',
      earned
          ? 'Your support keeps the app running. 💛'
          : 'Please try again in a moment.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.surface,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
    );
  }
}

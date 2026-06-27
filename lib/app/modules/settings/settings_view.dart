import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/ads_service.dart';
import 'settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = controller.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: RefreshIndicator(
        onRefresh: s.refresh,
        // Cap width so the settings list doesn't stretch edge-to-edge on tablets.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
          children: [
            const _SectionLabel('Playback'),
            Obx(() => SwitchListTile(
                  secondary:
                      const Icon(Icons.translate, color: AppTheme.primary),
                  title: const Text('Prefer English dub'),
                  subtitle: Text(controller.preferDub.value
                      ? 'New anime open in Dub when available'
                      : 'New anime open in Sub (Japanese)'),
                  value: controller.preferDub.value,
                  onChanged: controller.setPreferDub,
                )),
            Obx(() => SwitchListTile(
                  secondary: const Icon(Icons.sort, color: AppTheme.primary),
                  title: const Text('Newest episodes first'),
                  subtitle: const Text('Order the episode list newest → oldest'),
                  value: controller.newestFirst.value,
                  onChanged: controller.setNewestFirst,
                )),
            const _SectionLabel('Notifications'),
            Obx(() => SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined,
                      color: AppTheme.primary),
                  title: const Text('All notifications'),
                  subtitle: Text(controller.notifAll.value
                      ? 'Episode, wallpaper and news alerts are on'
                      : 'All notifications are turned off'),
                  value: controller.notifAll.value,
                  onChanged: controller.setNotifAll,
                )),
            _NotifTile(
              icon: Icons.new_releases_outlined,
              title: 'New episodes',
              subtitle: 'Alerts when new episodes are released',
              valueOf: () => controller.notifEpisodes.value,
              onChanged: controller.setNotifEpisodes,
            ),
            Obx(() {
              final enabled =
                  controller.notifAll.value && controller.notifEpisodes.value;
              return SwitchListTile(
                secondary: Icon(Icons.favorite_outline,
                    color: enabled ? AppTheme.primary : Colors.white24),
                title: const Text('Only my favorites'),
                subtitle: const Text(
                    'Episode alerts only for anime you favorited (else: all)'),
                value: enabled && controller.notifFavoritesOnly.value,
                onChanged:
                    enabled ? controller.setNotifFavoritesOnly : null,
              );
            }),
            _NotifTile(
              icon: Icons.wallpaper,
              title: 'Wallpapers',
              subtitle: 'Alerts when new wallpapers are added',
              valueOf: () => controller.notifWallpapers.value,
              onChanged: controller.setNotifWallpapers,
            ),
            _NotifTile(
              icon: Icons.article_outlined,
              title: 'News',
              subtitle: 'Alerts when new articles are posted',
              valueOf: () => controller.notifNews.value,
              onChanged: controller.setNotifNews,
            ),
            const _SectionLabel('Library'),
            Obx(() {
              final count = controller.continueWatchingCount;
              return ListTile(
                leading: const Icon(Icons.history, color: AppTheme.primary),
                title: const Text('Clear continue watching'),
                subtitle: Text('$count item${count == 1 ? '' : 's'}'),
                trailing:
                    const Icon(Icons.delete_outline, color: Colors.white38),
                onTap: count == 0 ? null : controller.clearContinueWatching,
              );
            }),
            const _SectionLabel('Community & Support'),
            Obx(() => _LinkTile(
                  icon: Icons.public,
                  title: 'Website',
                  url: s.websiteUrl.value,
                  onTap: controller.open,
                )),
            Obx(() => _LinkTile(
                  icon: Icons.support_agent,
                  title: 'Support',
                  url: s.supportUrl.value,
                  onTap: controller.open,
                )),
            Obx(() => _LinkTile(
                  icon: Icons.facebook,
                  title: 'Facebook',
                  url: s.facebookUrl.value,
                  onTap: controller.open,
                )),
            Obx(() => _LinkTile(
                  icon: Icons.forum,
                  title: 'Discord',
                  url: s.discordUrl.value,
                  onTap: controller.open,
                )),
            // Rewarded "support" ad — only when an ad provider is active.
            Obx(() {
              if (s.adsProvider.value == 'none') return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.card_giftcard, color: AppTheme.primary),
                title: const Text('Support us'),
                subtitle: const Text('Watch a short ad to support the app'),
                trailing: const Icon(Icons.play_circle_outline,
                    color: Colors.white38),
                onTap: () async {
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
                },
              );
            }),
            const _SectionLabel('About'),
            Obx(() => ListTile(
                  leading:
                      const Icon(Icons.info_outline, color: AppTheme.primary),
                  title: const Text('Version'),
                  subtitle: Text(controller.appVersion.value ?? '—'),
                )),
            Obx(() => ListTile(
                  leading:
                      const Icon(Icons.dns_outlined, color: AppTheme.primary),
                  title: const Text('Streaming source'),
                  subtitle: Text(s.animeProvider.value),
                )),
            const SizedBox(height: 24),
          ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String url;
  final void Function(String url) onTap;

  const _LinkTile({
    required this.icon,
    required this.title,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final available = url.isNotEmpty;
    return ListTile(
      leading: Icon(icon, color: available ? AppTheme.primary : Colors.white38),
      title: Text(title),
      subtitle: Text(
        available ? url : 'Not available yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: available ? Colors.white60 : Colors.white38),
      ),
      trailing: Icon(Icons.open_in_new,
          size: 18, color: available ? Colors.white54 : Colors.white24),
      onTap: () => onTap(url),
    );
  }
}

/// A per-category notification switch that follows the master "All
/// notifications" toggle — greyed out and forced off when the master is off.
class _NotifTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool Function() valueOf;
  final ValueChanged<bool> onChanged;

  const _NotifTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.valueOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();
    return Obx(() {
      final enabled = controller.notifAll.value;
      return SwitchListTile(
        secondary:
            Icon(icon, color: enabled ? AppTheme.primary : Colors.white24),
        title: Text(title),
        subtitle: Text(subtitle),
        value: enabled && valueOf(),
        onChanged: enabled ? onChanged : null,
      );
    });
  }
}

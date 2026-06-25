import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
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
            const _SectionLabel('About'),
            Obx(() => ListTile(
                  leading:
                      const Icon(Icons.info_outline, color: AppTheme.primary),
                  title: const Text('Version'),
                  subtitle: Text(controller.appVersion.value ?? '—'),
                )),
            ListTile(
              leading: const Icon(Icons.dns_outlined, color: AppTheme.primary),
              title: const Text('Streaming source'),
              subtitle: Text(controller.providerName),
            ),
            const SizedBox(height: 24),
          ],
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

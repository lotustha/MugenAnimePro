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

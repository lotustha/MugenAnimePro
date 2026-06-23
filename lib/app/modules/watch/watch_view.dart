import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/episode.dart';
import '../../widgets/state_views.dart';
import 'watch_controller.dart';

class WatchView extends GetView<WatchController> {
  const WatchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _player(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _titleBar(),
                  _navRow(),
                  _serverSelection(),
                  _audioSelection(),
                  const Divider(height: 1),
                  _episodesHeader(),
                  _episodeList(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 16:9 WebView player pinned to the top, with overlays.
  Widget _player() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            WebViewWidget(controller: controller.webViewController),
            Obx(() {
              if (controller.error.value != null) {
                return Container(
                  color: Colors.black87,
                  child: ErrorRetryView(
                    message: controller.error.value!,
                    onRetry: controller.retry,
                  ),
                );
              }
              if (controller.loading.value || controller.playerLoading.value) {
                return Container(
                  color: Colors.black45,
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              return const SizedBox.shrink();
            }),
            Positioned(
              top: 0,
              left: 0,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black38,
                ),
                onPressed: Get.back,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleBar() {
    return Obx(() {
      final ep = controller.current.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (ep != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Episode ${ep.number}${ep.title.isNotEmpty ? ' • ${ep.title}' : ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
          ],
        ),
      );
    });
  }

  /// Previous / Next episode buttons.
  Widget _navRow() {
    return Obx(() {
      controller.current.value; // react to episode change
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.hasPrevious ? controller.playPrevious : null,
                icon: const Icon(Icons.skip_previous),
                label: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: controller.hasNext ? controller.playNext : null,
                icon: const Icon(Icons.skip_next),
                label: const Text('Next'),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _serverSelection() {
    return Obx(() {
      final servers = controller.servers;
      if (servers.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Server', style: _sectionStyle),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: servers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = controller.selectedServer.value == i;
                return ChoiceChip(
                  label: Text(servers[i].name),
                  selected: selected,
                  onSelected: (_) => controller.selectServer(i),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _audioSelection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          const Text('Audio', style: _sectionStyle),
          const SizedBox(width: 16),
          Obx(() => ToggleButtons(
                isSelected: [
                  !controller.dubSelected.value,
                  controller.dubSelected.value,
                ],
                onPressed: (i) => controller.setDub(i == 1),
                borderRadius: BorderRadius.circular(8),
                constraints:
                    const BoxConstraints(minHeight: 34, minWidth: 56),
                children: const [Text('SUB'), Text('DUB')],
              )),
        ],
      ),
    );
  }

  Widget _episodesHeader() {
    // episodes is a fixed list (not reactive) — no Obx needed.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text('Episodes (${controller.episodes.length})',
          style: _sectionStyle),
    );
  }

  Widget _episodeList() {
    return Obx(() {
      final eps = controller.episodes;
      final currentId = controller.current.value?.id;
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: eps.length,
        itemBuilder: (_, i) {
          final Episode ep = eps[i];
          final isCurrent = ep.id == currentId;
          return ListTile(
            onTap: isCurrent ? null : () => controller.playEpisode(ep),
            leading: CircleAvatar(
              backgroundColor:
                  isCurrent ? AppTheme.primary : AppTheme.surfaceVariant,
              child: Text('${ep.number}',
                  style: const TextStyle(fontSize: 13, color: Colors.white)),
            ),
            title: Text(ep.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: ep.isFiller
                ? const Text('Filler',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 12))
                : null,
            trailing: Icon(
              isCurrent ? Icons.play_arrow : Icons.play_circle_outline,
              color: isCurrent ? AppTheme.primary : null,
            ),
          );
        },
      );
    });
  }

  static const _sectionStyle =
      TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
}

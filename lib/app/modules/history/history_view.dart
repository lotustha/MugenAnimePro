import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/watch_progress.dart';
import '../../data/services/storage_service.dart';
import '../../routes/app_pages.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/state_views.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = Get.find<StorageService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch History'),
        actions: [
          Obx(() => storage.continueWatching.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear all',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () => _confirmClear(context, storage),
                )),
        ],
      ),
      body: Obx(() {
        final history = storage.continueWatching;
        if (history.isEmpty) {
          return const EmptyView(
            message: 'No watch history yet',
            icon: Icons.history,
          );
        }
        return ListView.separated(
          itemCount: history.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 96),
          itemBuilder: (_, i) => _row(context, storage, history[i]),
        );
      }),
    );
  }

  Widget _row(BuildContext context, StorageService storage, WatchProgress p) {
    return Dismissible(
      key: ValueKey('${p.anime.id}-${p.episodeId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent.withValues(alpha: 0.8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => storage.removeProgress(p.anime.id),
      child: ListTile(
        onTap: () => Get.toNamed(Routes.detail, arguments: p.anime.id),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PosterImage(url: p.anime.image),
                if (p.fraction > 0)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: LinearProgressIndicator(
                      value: p.fraction,
                      minHeight: 3,
                      backgroundColor: Colors.black54,
                      valueColor:
                          const AlwaysStoppedAnimation(AppTheme.primary),
                    ),
                  ),
              ],
            ),
          ),
        ),
        title: Text(p.anime.title,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'Episode ${p.episodeNumber}'
          '${p.isFinished ? ' • Finished' : ' • ${(p.fraction * 100).round()}%'}',
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
        trailing: const Icon(Icons.play_circle_outline),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, StorageService storage) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This removes all watch history and progress.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) storage.clearAllProgress();
  }
}

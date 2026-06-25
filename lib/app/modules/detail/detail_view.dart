import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/anime.dart';
import '../../data/models/anime_info.dart';
import '../../routes/app_pages.dart';
import '../category/category_args.dart';
import '../../widgets/anime_card.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/state_views.dart';
import 'detail_controller.dart';

class DetailView extends GetView<DetailController> {
  const DetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        if (controller.loading.value) return const LoadingView();
        if (controller.error.value != null) {
          return ErrorRetryView(
            message: controller.error.value!,
            onRetry: controller.load,
          );
        }
        final info = controller.info.value;
        if (info == null) {
          return const EmptyView(message: 'No data');
        }
        return CustomScrollView(
          slivers: [
            _appBar(context, info),
            SliverToBoxAdapter(child: _header(info)),
            SliverToBoxAdapter(child: _actions(context, info)),
            SliverToBoxAdapter(child: _nextEpisode()),
            SliverToBoxAdapter(child: _meta(info)),
            if (info.relations.isNotEmpty)
              SliverToBoxAdapter(child: _rail('Related', info.relations)),
            if (info.recommendations.isNotEmpty)
              SliverToBoxAdapter(
                  child: _rail('Recommended', info.recommendations)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      }),
    );
  }

  Widget _appBar(BuildContext context, AnimeInfo info) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            PosterImage(url: info.image),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.background.withValues(alpha: 0.6),
                    AppTheme.background,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AnimeInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(info.title,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (info.japaneseTitle != null && info.japaneseTitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(info.japaneseTitle!,
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (info.type.isNotEmpty) _tag(info.type),
              if (info.status.isNotEmpty) _tag(info.status),
              if (info.season.isNotEmpty) _tag(info.season),
              if (info.duration.isNotEmpty) _tag(info.duration),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, AnimeInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: controller.resumeOrStart,
              icon: const Icon(Icons.play_arrow),
              label: Text(
                controller.resumeEpisodeNumber != null
                    ? 'Resume E${controller.resumeEpisodeNumber}'
                    : 'Play',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Obx(() {
            controller.info.value; // react to favorite refresh
            final fav = controller.isFavorite;
            return IconButton.filledTonal(
              onPressed: controller.toggleFavorite,
              icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                  color: fav ? Colors.redAccent : null),
            );
          }),
        ],
      ),
    );
  }

  /// Live countdown to the next airing episode (currently-airing anime only).
  Widget _nextEpisode() {
    return Obx(() {
      controller.nowTick.value; // re-tick the countdown each minute
      final next = controller.nextAiring.value;
      if (next == null) return const SizedBox.shrink();
      final left = next.timeUntil();
      if (left.isNegative) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 20, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('NEXT EPISODE',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      'Episode ${next.episode} • in ${_formatCountdown(left)}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: controller.notifyOn
                    ? 'Reminder on'
                    : 'Remind me when it airs',
                onPressed: controller.toggleNotify,
                icon: Icon(
                  controller.notifyOn
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                  color:
                      controller.notifyOn ? AppTheme.primary : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Compact remaining-time label, e.g. `3d 12h`, `12h 40m`, `40m`.
  static String _formatCountdown(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  Widget _meta(AnimeInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.genres.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: info.genres
                  .map((g) => ActionChip(
                        label: Text(g),
                        onPressed: () => Get.toNamed(
                          Routes.category,
                          arguments: CategoryArgs(
                            title: g,
                            kind: CategoryKind.genre,
                            value: AppConstants.genreSlug(g),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          if (info.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ExpandableText(text: info.description),
          ],
        ],
      ),
    );
  }

  Widget _rail(String title, List<Anime> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => AnimeCard(
              anime: items[i],
              onTap: () => controller.openRelated(items[i].id),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );
}

class _ExpandableText extends StatefulWidget {
  final String text;
  const _ExpandableText({required this.text});
  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: Text(
          widget.text,
          maxLines: _expanded ? null : 4,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
      ),
    );
  }
}

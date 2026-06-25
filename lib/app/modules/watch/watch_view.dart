import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/episode.dart';
import '../../widgets/state_views.dart';
import 'watch_controller.dart';

class WatchView extends GetView<WatchController> {
  const WatchView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Back exits fullscreen first; otherwise leaves the page.
        if (!controller.exitFullscreen()) Get.back();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: LayoutBuilder(
              builder: (context, constraints) {
                // On wide landscape screens put player + details side-by-side.
                final wide = constraints.maxWidth >= 720 &&
                    constraints.maxWidth > constraints.maxHeight;
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: Center(child: _player())),
                      Expanded(flex: 2, child: _details()),
                    ],
                  );
                }
                return Column(
                  children: [
                    _player(),
                    Expanded(child: _details()),
                  ],
                );
              },
            ),
          ),
        ),
    );
  }

  /// Scrollable episode metadata, server / audio controls and episode list.
  ///
  /// A single virtualised [ListView.builder] renders the header rows (title,
  /// nav, language, server, episodes bar) followed by the episodes, so only the
  /// rows on screen are built — long series (e.g. One Piece) no longer lag.
  Widget _details() {
    const headerCount = 6;
    return Obx(() {
      final eps = controller.visibleEpisodes; // tracks query + sort
      final currentId = controller.current.value?.id; // tracks current
      final watched = controller.watchedEpisodes.toSet(); // tracks watched
      final bodyCount = eps.isEmpty ? 1 : eps.length;
      return ListView.builder(
        controller: controller.episodeScroll,
        padding: EdgeInsets.zero,
        // header rows + episode rows (or the "no match" row) + trailing spacer
        itemCount: headerCount + bodyCount + 1,
        itemBuilder: (context, i) {
          switch (i) {
            case 0:
              return _titleBar();
            case 1:
              return _navRow();
            case 2:
              return _languageSelection();
            case 3:
              return _serverSelection();
            case 4:
              return const Divider(height: 1);
            case 5:
              return _episodesBar(eps.length);
          }
          final listIndex = i - headerCount;
          if (listIndex >= bodyCount) return const SizedBox(height: 16);
          if (eps.isEmpty) return _noEpisodeMatch();
          return _episodeTile(eps[listIndex], currentId, watched);
        },
      );
    });
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
            InAppWebView(
              initialSettings: controller.webSettings,
              initialUserScripts: controller.userScripts,
              onWebViewCreated: controller.onWebViewCreated,
              onLoadStart: (_, url) => controller.onLoadStart(url),
              onLoadStop: (_, url) => controller.onLoadStop(url),
              onReceivedError: (_, request, __) {
                if (request.isForMainFrame ?? false) {
                  controller.onMainFrameError();
                }
              },
              shouldOverrideUrlLoading: (_, action) => controller.shouldOverride(
                  action.request.url, action.isForMainFrame),
              onCreateWindow: (_, __) => controller.onCreateWindow(),
              onPermissionRequest: (_, request) =>
                  controller.onPermissionRequest(request.resources),
              onEnterFullscreen: (_) => controller.onEnterFullscreen(),
              onExitFullscreen: (_) => controller.onExitFullscreen(),
            ),
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
                style: IconButton.styleFrom(backgroundColor: Colors.black38),
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
                  _episodeLabel(ep),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
          ],
        ),
      );
    });
  }

  /// `Episode N • Title`, dropping a redundant generic title like "Episode 5".
  static String _episodeLabel(Episode ep) {
    final t = ep.title.trim();
    final generic = t.isEmpty ||
        t.toLowerCase() == 'episode' ||
        t.toLowerCase() == 'episode ${ep.number}';
    return generic ? 'Episode ${ep.number}' : 'Episode ${ep.number} • $t';
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
                  label: Text(servers[i].displayName),
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

  /// Horizontal chips for every audio language the episode exposes.
  Widget _languageSelection() {
    return Obx(() {
      final langs = controller.availableLanguages;
      if (langs.length < 2) return const SizedBox.shrink();
      final selected = controller.selectedLanguage.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Audio language', style: _sectionStyle),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: langs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final lang = langs[i];
                return ChoiceChip(
                  label: Text(_langLabel(lang)),
                  selected: selected == lang,
                  onSelected: (_) => controller.setLanguage(lang),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  static String _langLabel(String lang) {
    switch (lang) {
      case 'japanese':
        return 'Japanese (Sub)';
      case 'english':
        return 'English (Dub)';
      case '':
        return 'Default';
      default:
        return lang[0].toUpperCase() + lang.substring(1);
    }
  }

  /// Episodes section header: count + sort toggle + a search box. Used as a row
  /// inside the virtualised list so it scrolls with the content.
  Widget _episodesBar(int shown) {
    final total = controller.episodes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  shown == total
                      ? 'Episodes ($total)'
                      : 'Episodes ($shown of $total)',
                  style: _sectionStyle,
                ),
              ),
              Obx(() {
                final asc = controller.episodesAscending.value;
                return TextButton.icon(
                  onPressed: controller.toggleEpisodeSort,
                  icon: Icon(asc ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 18),
                  label: Text(asc ? 'Oldest' : 'Newest'),
                );
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: controller.episodeSearchCtrl,
            focusNode: controller.episodeSearchFocus,
            onChanged: controller.setEpisodeQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search by number or title',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: Obx(() => controller.episodeQuery.value.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: controller.clearEpisodeQuery,
                    )),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _noEpisodeMatch() => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('No episodes match your search',
              style: TextStyle(color: Colors.white54)),
        ),
      );

  Widget _episodeTile(Episode ep, String? currentId, Set<int> watched) {
    final isCurrent = ep.id == currentId;
    final isWatched = watched.contains(ep.number);
    return ListTile(
      onTap: isCurrent ? null : () => controller.playEpisode(ep),
      leading: CircleAvatar(
        backgroundColor: isCurrent ? AppTheme.primary : AppTheme.surfaceVariant,
        child: Text('${ep.number}',
            style: const TextStyle(fontSize: 13, color: Colors.white)),
      ),
      title: Text(ep.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: ep.isFiller
          ? const Text('Filler',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 12))
          : null,
      trailing: Icon(
        isCurrent
            ? Icons.play_arrow
            : isWatched
                ? Icons.check_circle
                : Icons.play_circle_outline,
        color: isCurrent
            ? AppTheme.primary
            : isWatched
                ? AppTheme.primary.withValues(alpha: 0.6)
                : null,
      ),
    );
  }

  static const _sectionStyle =
      TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
}

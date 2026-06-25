import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/wallpaper.dart';
import '../../routes/app_pages.dart';

/// Grid card for a wallpaper. Tapping opens the detail screen. Shared by the
/// gallery grid and the search results grid. Video wallpapers preview as a
/// muted, looping clip; still images show their picture.
class WallpaperCard extends StatelessWidget {
  final Wallpaper wallpaper;
  const WallpaperCard({super.key, required this.wallpaper});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(Routes.wallpaperDetail, arguments: wallpaper.id),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (wallpaper.isVideo)
              _VideoPreview(url: wallpaper.fileUrl)
            else
              CachedNetworkImage(
                imageUrl: wallpaper.fileUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppTheme.surface),
                errorWidget: (_, __, ___) =>
                    Container(color: AppTheme.surfaceVariant),
              ),
            if (wallpaper.isVideo)
              const Positioned(
                bottom: 6,
                right: 6,
                child: Icon(Icons.videocam, color: Colors.white70, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

/// Looping, muted in-grid preview of a video wallpaper. The controller is tied
/// to this card's lifecycle: the grid only builds visible cards, so off-screen
/// cards dispose their player (only the handful on screen ever decode at once).
class _VideoPreview extends StatefulWidget {
  final String url;
  const _VideoPreview({required this.url});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller = c;
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_ready && c != null && c.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: VideoPlayer(c),
        ),
      );
    }
    return Container(
      color: AppTheme.surfaceVariant,
      alignment: Alignment.center,
      child: const Icon(Icons.play_circle_outline,
          color: Colors.white54, size: 32),
    );
  }
}

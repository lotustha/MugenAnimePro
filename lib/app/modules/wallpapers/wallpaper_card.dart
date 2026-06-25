import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/wallpaper.dart';
import '../../routes/app_pages.dart';

/// Grid card for a wallpaper. Tapping opens the detail screen. Shared by the
/// gallery grid and the search results grid.
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
              Container(
                color: AppTheme.surfaceVariant,
                alignment: Alignment.center,
                child: const Icon(Icons.play_circle_outline,
                    color: Colors.white54, size: 32),
              )
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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Cached poster/banner image with consistent placeholder + error states.
class PosterImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  const PosterImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _fallback();
    // Decode and cache at roughly the displayed pixel size instead of the full
    // source resolution. A 600×900 poster shown in a 130px slot otherwise costs
    // ~2MB of RAM per copy and thrashes the image cache; this cuts it ~10×.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = width != null ? (width! * dpr).round() : null;
    final cacheH =
        (width == null && height != null) ? (height! * dpr).round() : null;
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheW,
      memCacheHeight: cacheH,
      maxWidthDiskCache: cacheW,
      maxHeightDiskCache: cacheH,
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: AppTheme.surfaceVariant,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() => Container(
        width: width,
        height: height,
        color: AppTheme.surfaceVariant,
        child: const Icon(Icons.broken_image_outlined,
            color: Colors.white24, size: 32),
      );
}

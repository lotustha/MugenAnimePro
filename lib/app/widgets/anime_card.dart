import 'package:flutter/material.dart';

import '../data/models/anime.dart';
import 'poster_image.dart';

/// Vertical poster card used in grids and horizontal rails.
class AnimeCard extends StatelessWidget {
  final Anime anime;
  final VoidCallback onTap;
  final double width;
  final double? progress; // 0..1 continue-watching bar, null to hide

  const AnimeCard({
    super.key,
    required this.anime,
    required this.onTap,
    this.width = 130,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster fills the space left after the title so the card never
            // overflows its bounded height (e.g. the 230px-tall rails).
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PosterImage(url: anime.image, width: width),
                    if (anime.type.isNotEmpty)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: _badge(anime.type),
                      ),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Row(
                        children: [
                          if (anime.sub > 0) _pill(Icons.subtitles, anime.sub),
                          if (anime.dub > 0) ...[
                            const SizedBox(width: 4),
                            _pill(Icons.mic, anime.dub),
                          ],
                        ],
                      ),
                    ),
                    if (progress != null && progress! > 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 10, color: Colors.white)),
      );

  Widget _pill(IconData icon, int count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: Colors.white),
            const SizedBox(width: 2),
            Text('$count',
                style: const TextStyle(fontSize: 10, color: Colors.white)),
          ],
        ),
      );
}

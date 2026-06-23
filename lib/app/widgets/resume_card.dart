import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/models/watch_progress.dart';
import 'poster_image.dart';

/// Compact "resume playback" bar shown floating above the Home content.
///
/// Replaces the old extended FAB: shows a small poster, the anime title, the
/// episode label and a thin watched-progress bar, with a play affordance.
class ResumeCard extends StatelessWidget {
  final WatchProgress progress;
  final bool busy;
  final VoidCallback onTap;

  const ResumeCard({
    super.key,
    required this.progress,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        elevation: 6,
        shadowColor: Colors.black54,
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 44,
                        height: 60,
                        child: PosterImage(url: progress.anime.image),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'CONTINUE WATCHING',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            progress.anime.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Episode ${progress.episodeNumber}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: busy
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow,
                              color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              if (progress.fraction > 0)
                LinearProgressIndicator(
                  value: progress.fraction,
                  minHeight: 3,
                  backgroundColor: Colors.white12,
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

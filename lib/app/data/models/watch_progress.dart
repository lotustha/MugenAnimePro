import 'anime.dart';

/// A "continue watching" record persisted locally. Keyed by [Anime.id].
class WatchProgress {
  final Anime anime;
  final String episodeId;
  final int episodeNumber;
  final int positionMs;
  final int durationMs;
  final int updatedAt; // epoch millis

  const WatchProgress({
    required this.anime,
    required this.episodeId,
    required this.episodeNumber,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
  });

  double get fraction =>
      durationMs <= 0 ? 0 : (positionMs / durationMs).clamp(0.0, 1.0);

  /// Treat as "finished" past 92% so it can roll over to the next episode.
  bool get isFinished => fraction >= 0.92;

  factory WatchProgress.fromJson(Map<String, dynamic> json) => WatchProgress(
        anime: Anime.fromJson(Map<String, dynamic>.from(json['anime'] as Map)),
        episodeId: '${json['episodeId'] ?? ''}',
        episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
        positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'anime': anime.toJson(),
        'episodeId': episodeId,
        'episodeNumber': episodeNumber,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'updatedAt': updatedAt,
      };
}

/// The upcoming episode for a currently-airing anime, sourced from AniList's
/// `Media.nextAiringEpisode`.
class NextAiringEpisode {
  final int episode;

  /// Local-time moment the episode airs (converted from AniList's UTC unix
  /// timestamp).
  final DateTime airingAt;

  const NextAiringEpisode({required this.episode, required this.airingAt});

  factory NextAiringEpisode.fromJson(Map<String, dynamic> json) {
    final secs = (json['airingAt'] as num?)?.toInt() ?? 0;
    return NextAiringEpisode(
      episode: (json['episode'] as num?)?.toInt() ?? 0,
      airingAt: DateTime.fromMillisecondsSinceEpoch(secs * 1000),
    );
  }

  /// Time remaining until the episode airs; negative once it has aired.
  Duration timeUntil() => airingAt.difference(DateTime.now());
}

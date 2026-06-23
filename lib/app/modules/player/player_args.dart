import '../../data/models/anime.dart';
import '../../data/models/episode.dart';

/// Arguments passed to the player route.
class PlayerArgs {
  final Anime anime;
  final List<Episode> episodes;
  final Episode startEpisode;
  final bool preferDub;

  const PlayerArgs({
    required this.anime,
    required this.episodes,
    required this.startEpisode,
    this.preferDub = false,
  });
}

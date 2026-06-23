import '../../data/models/anime.dart';
import '../../data/models/episode.dart';

/// Arguments passed to the watch route.
class WatchArgs {
  final Anime anime;
  final List<Episode> episodes;
  final Episode startEpisode;
  final bool preferDub;

  const WatchArgs({
    required this.anime,
    required this.episodes,
    required this.startEpisode,
    this.preferDub = false,
  });
}

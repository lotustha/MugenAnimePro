import '../../core/constants/api_constants.dart';
import '../models/anime.dart';
import '../models/anime_info.dart';
import '../models/paged_result.dart';
import '../models/schedule_item.dart';
import '../models/spotlight_item.dart';
import '../models/watch_response.dart';
import '../providers/api_client.dart';

/// Maps API responses into domain models. The single source of truth for all
/// remote anime data.
class AnimeRepository {
  final ApiClient _client;

  AnimeRepository(this._client);

  Future<List<SpotlightItem>> spotlight() async {
    final json = await _client.getObject(ApiConstants.spotlight());
    final results = (json['results'] as List?) ?? const [];
    return results
        .whereType<Map>()
        .map((e) => SpotlightItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<PagedResult<Anime>> recentEpisodes({int page = 1}) async {
    final json = await _client.getObject(
      ApiConstants.recentEpisodes(),
      query: {'page': page},
    );
    return PagedResult.fromJson(json, Anime.fromJson);
  }

  Future<PagedResult<Anime>> search(String query, {int page = 1}) async {
    final json = await _client.getObject(
      ApiConstants.search(query),
      query: {'page': page},
    );
    return PagedResult.fromJson(json, Anime.fromJson);
  }

  Future<AnimeInfo> info(String id) async {
    final json = await _client.getObject(ApiConstants.info(id));
    return AnimeInfo.fromJson(json);
  }

  /// Streaming sources for an episode. By default fetches EVERY audio language
  /// the episode exposes (`?type=all`) so the player can offer a language
  /// selector (japanese/english/hindi/tamil/telugu/…). Pass a specific [type]
  /// (e.g. `sub`, `dub`, `hindi`) to fetch just that track.
  Future<WatchResponse> watch(String episodeId, {String type = 'all'}) async {
    final json = await _client.getObject(
      ApiConstants.watch(episodeId),
      query: {'type': type},
    );
    return WatchResponse.fromJson(json);
  }

  /// Airing schedule for a given day. [date] must be `YYYY-MM-DD`.
  Future<List<ScheduleItem>> schedule(String date) async {
    final json = await _client.getObject(ApiConstants.schedule(date));
    final results = (json['results'] as List?) ?? const [];
    return results
        .whereType<Map>()
        .map((e) => ScheduleItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Paged category feed: `movies`, `tv`, `ova`, `completed`.
  Future<PagedResult<Anime>> category(String kind, {int page = 1}) async {
    final json = await _client.getObject(
      ApiConstants.category(kind),
      query: {'page': page},
    );
    return PagedResult.fromJson(json, Anime.fromJson);
  }

  /// Paged feed for a genre slug (e.g. `martial-arts`).
  Future<PagedResult<Anime>> genre(String slug, {int page = 1}) async {
    final json = await _client.getObject(
      ApiConstants.genre(slug),
      query: {'page': page},
    );
    return PagedResult.fromJson(json, Anime.fromJson);
  }
}

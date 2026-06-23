import 'package:dio/dio.dart';

import '../models/next_airing.dart';

/// Minimal GraphQL client for AniList, used only to resolve the next airing
/// episode for currently-airing anime (the primary API exposes no such field).
class AniListClient {
  static const _endpoint = 'https://graphql.anilist.co';

  final Dio _dio;

  AniListClient([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              responseType: ResponseType.json,
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ));

  static const _query = r'''
query ($idMal: Int) {
  Media(idMal: $idMal, type: ANIME) {
    nextAiringEpisode { airingAt episode }
  }
}''';

  /// The next airing episode for the anime with the given MyAnimeList id, or
  /// null if it isn't currently airing or the lookup fails. This is a
  /// supplementary call, so any error degrades silently to null.
  Future<NextAiringEpisode?> nextAiring(int malId) async {
    try {
      final res = await _dio.post(
        _endpoint,
        data: {
          'query': _query,
          'variables': {'idMal': malId},
        },
      );
      final media = ((res.data as Map?)?['data'] as Map?)?['Media'] as Map?;
      final next = media?['nextAiringEpisode'];
      if (next is Map) {
        return NextAiringEpisode.fromJson(Map<String, dynamic>.from(next));
      }
    } catch (_) {
      // Ignore — the countdown is optional UI.
    }
    return null;
  }
}

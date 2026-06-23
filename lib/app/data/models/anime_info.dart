import 'anime.dart';
import 'episode.dart';

/// Full detail payload from `GET /anime/anizen/info/{id}`.
class AnimeInfo {
  final String id;
  final String title;
  final String? japaneseTitle;
  final String image;
  final String description;
  final String type;
  final int totalEpisodes;
  final String status;
  final String season;
  final String duration;
  final String? malId;
  final String? anilistId;
  final bool hasSub;
  final bool hasDub;
  final String subOrDub;
  final List<String> genres;
  final List<Anime> recommendations;
  final List<Anime> relations;
  final List<Episode> episodes;

  const AnimeInfo({
    required this.id,
    required this.title,
    required this.image,
    this.japaneseTitle,
    this.description = '',
    this.type = '',
    this.totalEpisodes = 0,
    this.status = '',
    this.season = '',
    this.duration = '',
    this.malId,
    this.anilistId,
    this.hasSub = true,
    this.hasDub = false,
    this.subOrDub = 'sub',
    this.genres = const [],
    this.recommendations = const [],
    this.relations = const [],
    this.episodes = const [],
  });

  factory AnimeInfo.fromJson(Map<String, dynamic> json) {
    List<Anime> parseAnimeList(dynamic raw) => ((raw as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Anime.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return AnimeInfo(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? 'Unknown'}',
      japaneseTitle: json['japaneseTitle'] as String?,
      image: '${json['image'] ?? ''}',
      description: '${json['description'] ?? ''}',
      type: '${json['type'] ?? ''}',
      totalEpisodes: _toInt(json['totalEpisodes']),
      status: '${json['status'] ?? ''}',
      season: '${json['season'] ?? ''}',
      duration: '${json['duration'] ?? ''}',
      malId: json['malId']?.toString(),
      anilistId: json['anilistId']?.toString(),
      hasSub: json['hasSub'] != false,
      hasDub: json['hasDub'] == true,
      subOrDub: '${json['subOrDub'] ?? 'sub'}',
      genres: ((json['genres'] as List?) ?? const []).map((e) => '$e').toList(),
      recommendations: parseAnimeList(json['recommendations']),
      relations: parseAnimeList(json['relations']),
      episodes: ((json['episodes'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Episode.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  /// A compact [Anime] representation, e.g. to persist a favorite.
  Anime toAnime() => Anime(
        id: id,
        title: title,
        image: image,
        japaneseTitle: japaneseTitle,
        type: type,
        episodes: totalEpisodes,
      );

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}

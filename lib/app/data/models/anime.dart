/// A lightweight anime card used across search results, recent episodes,
/// recommendations and relations. Different feeds spell the poster field
/// differently (`image` vs `banner`), so [fromJson] accepts both.
class Anime {
  final String id;
  final String title;
  final String? japaneseTitle;
  final String image;
  final String type;
  final int sub;
  final int dub;
  final int episodes;

  /// Present only on `relations` items (e.g. "Sequel", "Prequel").
  final String? relationType;

  const Anime({
    required this.id,
    required this.title,
    required this.image,
    this.japaneseTitle,
    this.type = '',
    this.sub = 0,
    this.dub = 0,
    this.episodes = 0,
    this.relationType,
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      id: '${json['id'] ?? ''}',
      title: _decode('${json['title'] ?? 'Unknown'}'),
      japaneseTitle: json['japaneseTitle'] as String?,
      image: '${json['image'] ?? json['banner'] ?? json['poster'] ?? ''}',
      type: '${json['type'] ?? ''}',
      sub: _toInt(json['sub']),
      dub: _toInt(json['dub']),
      episodes: _toInt(json['episodes']),
      relationType: json['relationType'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'japaneseTitle': japaneseTitle,
        'image': image,
        'type': type,
        'sub': sub,
        'dub': dub,
        'episodes': episodes,
        'relationType': relationType,
      };

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  // The API leaves some HTML entities un-decoded (e.g. "&amp;").
  static String _decode(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&apos;', "'");
}

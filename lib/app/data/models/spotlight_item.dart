/// Hero item from `GET /anime/anizen/spotlight`. Carries a wide banner image
/// and a synopsis for the home carousel.
class SpotlightItem {
  final String id;
  final String title;
  final String? japaneseTitle;
  final String banner;
  final String type;
  final List<String> genres;
  final String releaseDate;
  final String quality;
  final int sub;
  final int dub;
  final String description;

  const SpotlightItem({
    required this.id,
    required this.title,
    required this.banner,
    this.japaneseTitle,
    this.type = '',
    this.genres = const [],
    this.releaseDate = '',
    this.quality = '',
    this.sub = 0,
    this.dub = 0,
    this.description = '',
  });

  factory SpotlightItem.fromJson(Map<String, dynamic> json) {
    return SpotlightItem(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? 'Unknown'}',
      japaneseTitle: json['japaneseTitle'] as String?,
      banner: '${json['banner'] ?? json['image'] ?? ''}',
      type: '${json['type'] ?? ''}',
      genres: ((json['genres'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      releaseDate: '${json['releaseDate'] ?? ''}',
      quality: '${json['quality'] ?? ''}',
      sub: _toInt(json['sub']),
      dub: _toInt(json['dub']),
      description: '${json['description'] ?? ''}',
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}

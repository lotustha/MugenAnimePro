/// A single episode entry from an anime's `info.episodes` list.
///
/// The [id] is an opaque token like `naruto-eybxz$ep=1$token=...` that is
/// passed verbatim (URL-encoded by the API client) to the watch endpoint.
class Episode {
  final String id;
  final int number;
  final String title;
  final bool isFiller;
  final bool isSubbed;
  final bool isDubbed;

  const Episode({
    required this.id,
    required this.number,
    required this.title,
    this.isFiller = false,
    this.isSubbed = true,
    this.isDubbed = false,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: '${json['id'] ?? ''}',
      number: _toInt(json['number']),
      title: '${json['title'] ?? 'Episode'}',
      isFiller: json['isFiller'] == true,
      isSubbed: json['isSubbed'] != false,
      isDubbed: json['isDubbed'] == true,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}

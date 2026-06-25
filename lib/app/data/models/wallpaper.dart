/// A wallpaper from the Mugenstream website (/api/wallpapers).
class Wallpaper {
  final String id;
  final String title;
  final String? description;
  final String fileUrl;
  final bool isVideo;
  final int downloadsCount;
  final List<String> categories;
  final List<String> tags;

  const Wallpaper({
    required this.id,
    required this.title,
    required this.fileUrl,
    this.description,
    this.isVideo = false,
    this.downloadsCount = 0,
    this.categories = const [],
    this.tags = const [],
  });

  factory Wallpaper.fromJson(Map<String, dynamic> j) {
    final type = '${j['type'] ?? 'IMAGE'}'.toUpperCase();
    return Wallpaper(
      id: '${j['id'] ?? ''}',
      title: '${j['title'] ?? 'Wallpaper'}',
      description: j['description'] as String?,
      fileUrl: '${j['fileUrl'] ?? j['file_url'] ?? ''}',
      isVideo: type == 'VIDEO',
      downloadsCount: _toInt(j['downloadsCount'] ?? j['downloads_count']),
      categories: _names(j['categories']),
      tags: _names(j['tags']),
    );
  }

  static List<String> _names(dynamic v) {
    if (v is! List) return const [];
    return v
        .whereType<Map>()
        .map((e) => '${e['name'] ?? ''}')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}

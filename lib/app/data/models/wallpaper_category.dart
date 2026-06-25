/// A wallpaper category from the website (/api/wallpaper-categories).
class WallpaperCategory {
  final String id;
  final String name;
  final String slug;
  final int count;

  const WallpaperCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.count = 0,
  });

  factory WallpaperCategory.fromJson(Map<String, dynamic> j) {
    return WallpaperCategory(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? ''}',
      slug: '${j['slug'] ?? ''}',
      count: (j['count'] is num) ? (j['count'] as num).toInt() : 0,
    );
  }
}

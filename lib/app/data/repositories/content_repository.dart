import '../../core/constants/api_constants.dart';
import '../models/post.dart';
import '../models/wallpaper.dart';
import '../models/wallpaper_category.dart';
import '../providers/site_client.dart';

/// Website content (news posts + wallpapers) from mugenstream.fun.
class ContentRepository {
  final SiteClient _client;

  ContentRepository(this._client);

  // ── Wallpapers ─────────────────────────────────────────────────────────────

  Future<List<Wallpaper>> wallpapers({
    int page = 1,
    int limit = 30,
    String? type,
    String? category,
  }) async {
    final list = await _client.getList(ApiConstants.wallpapers, query: {
      'page': page,
      'limit': limit,
      if (type != null) 'type': type,
      if (category != null && category.isNotEmpty) 'category': category,
    });
    return list.map(Wallpaper.fromJson).toList();
  }

  Future<Wallpaper> wallpaper(String id) async {
    final json = await _client.getObject(ApiConstants.wallpaper(id));
    return Wallpaper.fromJson(json);
  }

  Future<List<WallpaperCategory>> wallpaperCategories() async {
    final list = await _client.getList(ApiConstants.wallpaperCategories);
    return list.map(WallpaperCategory.fromJson).toList();
  }

  Future<List<Wallpaper>> searchWallpapers(String query, {int limit = 30, String? type}) async {
    if (query.trim().isEmpty) return [];
    final list = await _client.getList(ApiConstants.wallpaperSearch, query: {
      'q': query.trim(),
      'limit': limit,
      if (type != null) 'type': type,
    });
    return list.map(Wallpaper.fromJson).toList();
  }

  // ── News posts ─────────────────────────────────────────────────────────────

  Future<List<Post>> posts({int page = 1, int limit = 20}) async {
    final list = await _client.getList(ApiConstants.posts, query: {
      'page': page,
      'limit': limit,
    });
    return list.map(Post.fromJson).toList();
  }

  Future<Post> post(String slug) async {
    final json = await _client.getObject(ApiConstants.post(slug));
    return Post.fromJson(json);
  }
}

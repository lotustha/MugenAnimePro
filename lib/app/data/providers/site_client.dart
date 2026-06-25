import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import 'api_client.dart' show ApiException;

/// Dio wrapper for the Mugenstream website API (posts, wallpapers, in-app
/// messages). Separate from [ApiClient], which targets the anime streaming API.
class SiteClient {
  final Dio _dio;

  SiteClient([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConstants.siteUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              responseType: ResponseType.json,
              headers: const {
                'User-Agent': 'AnimeStream/1.0 (Flutter)',
                'Accept': 'application/json',
              },
            ));

  /// GET a path returning a JSON array.
  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final data = await _get(path, query: query);
    final list = _extractList(data);
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// The website wraps lists in different envelopes:
  ///   /api/wallpapers → { wallpapers: [...] }
  ///   /api/posts      → { posts: [...] }
  ///   (others)        → bare array, or { results: [...] } / { data: [...] }
  List _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in const ['wallpapers', 'posts', 'results', 'data', 'items']) {
        if (data[key] is List) return data[key] as List;
      }
      // Fallback: first list-valued field.
      for (final v in data.values) {
        if (v is List) return v;
      }
    }
    return const [];
  }

  /// GET a path returning a JSON object.
  Future<Map<String, dynamic>> getObject(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final data = await _get(path, query: query);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ApiException('Expected a JSON object from $path');
  }

  Future<dynamic> _get(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get(path, queryParameters: query);
      return res.data;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404) throw ApiException('Not found.', statusCode: 404);
      throw ApiException(
        e.message ?? 'Could not reach the server.',
        statusCode: code,
      );
    }
  }
}

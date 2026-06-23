import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';

/// Thin Dio wrapper around the Cooren API. Exposes typed `getJson` helpers and
/// normalises errors into [ApiException].
class ApiClient {
  final Dio _dio;

  ApiClient([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConstants.baseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              responseType: ResponseType.json,
              headers: const {
                'User-Agent': 'AnimeStream/1.0 (Flutter)',
                'Accept': 'application/json',
              },
            ));

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
      final data = res.data;
      // Some error responses come back as { "message": "..." } with 2xx-ish
      // handling upstream; surface them as exceptions.
      if (data is Map && data['message'] != null && data['results'] == null &&
          data['episodes'] == null && data['id'] == null) {
        throw ApiException('${data['message']}');
      }
      return data;
    } on DioException catch (e) {
      throw ApiException(_describe(e), statusCode: e.response?.statusCode);
    }
  }

  String _describe(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Check your internet and try again.';
      case DioExceptionType.connectionError:
        return 'Could not reach the server. Check your connection.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 404) return 'Not found.';
        return 'Server error${code != null ? ' ($code)' : ''}.';
      default:
        return e.message ?? 'Something went wrong.';
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

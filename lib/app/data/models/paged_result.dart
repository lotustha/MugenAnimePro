/// Generic wrapper for the API's paginated list responses
/// (`search`, `recent-episodes`), which share the shape:
/// `{ currentPage, hasNextPage, totalPages, results: [...] }`.
class PagedResult<T> {
  final int currentPage;
  final bool hasNextPage;
  final int totalPages;
  final List<T> results;

  const PagedResult({
    required this.currentPage,
    required this.hasNextPage,
    required this.totalPages,
    required this.results,
  });

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    final rawResults = (json['results'] as List?) ?? const [];
    return PagedResult<T>(
      currentPage: _toInt(json['currentPage'], fallback: 1),
      hasNextPage: json['hasNextPage'] == true,
      totalPages: _toInt(json['totalPages'], fallback: 1),
      results: rawResults
          .whereType<Map>()
          .map((e) => itemParser(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? fallback;
  }
}

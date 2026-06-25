/// Response from `GET /anime/anizen/watch/{episodeId}`.
///
/// Shape:
/// ```
/// { isDub, intro:[s,e], outro:[s,e], results:[ WatchServer ] }
/// ```
class WatchResponse {
  final bool isDub;
  final List<WatchServer> servers;
  final List<String> languages; // e.g. [japanese, english, hindi, tamil, …]
  final TimeRange? intro;
  final TimeRange? outro;

  const WatchResponse({
    this.isDub = false,
    this.servers = const [],
    this.languages = const [],
    this.intro,
    this.outro,
  });

  factory WatchResponse.fromJson(Map<String, dynamic> json) {
    final servers = ((json['results'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => WatchServer.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    // Prefer the explicit `languages` field; fall back to the distinct langs
    // present on the server results.
    var langs = ((json['languages'] as List?) ?? const [])
        .map((e) => '$e'.toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    if (langs.isEmpty) {
      langs = servers
          .map((s) => s.lang)
          .where((l) => l.isNotEmpty)
          .toSet()
          .toList();
    }
    return WatchResponse(
      isDub: json['isDub'] == true,
      servers: servers,
      languages: langs,
      intro: TimeRange.fromList(json['intro']),
      outro: TimeRange.fromList(json['outro']),
    );
  }

  /// The first server that exposes a directly-playable (non-iframe) source.
  WatchServer? get playableServer {
    for (final s in servers) {
      if (s.hlsSource != null) return s;
    }
    return servers.isNotEmpty ? servers.first : null;
  }
}

class WatchServer {
  final String name;
  final String lang; // audio language of this server, lowercase (e.g. "hindi")
  final String? iframe;
  final List<StreamSource> sources;
  final List<Subtitle> subtitles;
  final Map<String, String> headers;

  const WatchServer({
    required this.name,
    this.lang = '',
    this.iframe,
    this.sources = const [],
    this.subtitles = const [],
    this.headers = const {},
  });

  factory WatchServer.fromJson(Map<String, dynamic> json) {
    return WatchServer(
      name: '${json['name'] ?? 'Server'}',
      lang: '${json['lang'] ?? ''}'.toLowerCase(),
      iframe: json['iframe'] as String?,
      sources: ((json['sources'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => StreamSource.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      subtitles: ((json['subtitles'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Subtitle.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      headers: ((json['headers'] as Map?) ?? const {})
          .map((k, v) => MapEntry('$k', '$v')),
    );
  }

  /// Compact label for the server chip: drops the `Anizen ` provider prefix
  /// and the trailing `(HardSub)` / `(Dub)` qualifier, since audio is chosen
  /// separately. e.g. `Anizen VidCloud-1 (HardSub)` -> `VidCloud-1`.
  String get displayName {
    var n = name
        .replaceFirst(
            RegExp(r'^(anizen|animelok|anivid)\s+', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '')
        .trim();
    return n.isEmpty ? name : n;
  }

  /// First HLS (.m3u8) source, if any. Sources of `type:iframe` are skipped
  /// because they are not directly playable by media_kit.
  StreamSource? get hlsSource {
    for (final s in sources) {
      if (s.type.toLowerCase() == 'hls') return s;
    }
    return null;
  }

  /// URL of the embeddable HTML player for this server, loaded into a WebView.
  /// Prefers the explicit [iframe], falling back to a `type:iframe` source.
  String? get embedUrl {
    if (iframe != null && iframe!.isNotEmpty) return iframe;
    for (final s in sources) {
      if (s.type.toLowerCase() == 'iframe' && s.file.isNotEmpty) return s.file;
    }
    return null;
  }
}

class StreamSource {
  final String file;
  final String type;

  const StreamSource({required this.file, this.type = ''});

  factory StreamSource.fromJson(Map<String, dynamic> json) => StreamSource(
        file: '${json['file'] ?? json['url'] ?? ''}',
        type: '${json['type'] ?? ''}',
      );
}

class Subtitle {
  final String url;
  final String lang;
  final String type;

  const Subtitle({required this.url, this.lang = '', this.type = ''});

  factory Subtitle.fromJson(Map<String, dynamic> json) => Subtitle(
        url: '${json['url'] ?? json['file'] ?? ''}',
        lang: '${json['lang'] ?? json['label'] ?? ''}',
        type: '${json['type'] ?? ''}',
      );

  bool get isEnglish => lang.toLowerCase().contains('english');
}

/// Intro/outro marker, expressed as `[startSeconds, endSeconds]`.
class TimeRange {
  final int start;
  final int end;

  const TimeRange(this.start, this.end);

  static TimeRange? fromList(dynamic raw) {
    if (raw is List && raw.length >= 2) {
      final s = _toInt(raw[0]);
      final e = _toInt(raw[1]);
      if (e > s) return TimeRange(s, e);
    }
    return null;
  }

  bool contains(int seconds) => seconds >= start && seconds < end;

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}

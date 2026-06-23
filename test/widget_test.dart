// Basic unit tests for AnimeStream models.
//
// Full widget tests would require initializing GetStorage and media_kit, so
// these keep to fast, dependency-free checks of the parsing layer.

import 'package:flutter_test/flutter_test.dart';

import 'package:anime_stream/app/data/models/anime.dart';
import 'package:anime_stream/app/data/models/watch_response.dart';

void main() {
  test('Anime.fromJson uses banner fallback and decodes HTML entities', () {
    final a = Anime.fromJson({
      'id': 'naruto-eybxz',
      'title': 'Rock Lee &amp; His Ninja Pals',
      'banner': 'https://example.com/p.jpg',
      'type': 'TV',
      'sub': 220,
      'dub': 220,
    });

    expect(a.id, 'naruto-eybxz');
    expect(a.title, contains('&'));
    expect(a.image, 'https://example.com/p.jpg');
    expect(a.sub, 220);
  });

  test('WatchResponse picks the first HLS server and parses intro/outro', () {
    final w = WatchResponse.fromJson({
      'isDub': false,
      'intro': [0, 106],
      'outro': [1317, 1379],
      'results': [
        {
          'name': 'Anizen VidCloud-1 (HardSub)',
          'sources': [
            {'file': 'https://cdn.example.com/master.m3u8', 'type': 'hls'}
          ],
          'subtitles': [
            {'url': 'https://example.com/eng.vtt', 'lang': 'English'}
          ],
          'headers': {'Referer': 'https://megaplay.buzz/'}
        }
      ],
    });

    expect(w.playableServer, isNotNull);
    expect(w.playableServer!.hlsSource!.file, endsWith('.m3u8'));
    expect(w.playableServer!.headers['Referer'], 'https://megaplay.buzz/');
    expect(w.intro!.contains(50), isTrue);
    expect(w.outro!.contains(1350), isTrue);
  });
}

// ignore_for_file: avoid_print
//
// Standalone smoke test for the data layer against the live Cooren API.
// Runs on the Dart VM (no Flutter / Visual Studio needed):
//   dart run tool/api_smoke.dart
//
// Exercises: Dio client, JSON parsing, repository, and the episodeId
// URL-encoding path through to a real .m3u8 stream URL.

import 'package:anime_stream/app/data/providers/api_client.dart';
import 'package:anime_stream/app/data/repositories/anime_repository.dart';

Future<void> main() async {
  final repo = AnimeRepository(ApiClient());
  var failures = 0;

  Future<void> step(String label, Future<void> Function() body) async {
    try {
      await body();
      print('  [PASS] $label');
    } catch (e) {
      failures++;
      print('  [FAIL] $label -> $e');
    }
  }

  print('== Cooren API smoke test (anizen) ==');

  await step('spotlight returns items', () async {
    final s = await repo.spotlight();
    if (s.isEmpty) throw 'empty';
    print('         e.g. "${s.first.title}" (${s.length} items)');
  });

  await step('recent-episodes paginates', () async {
    final r = await repo.recentEpisodes();
    if (r.results.isEmpty) throw 'empty';
    print('         page ${r.currentPage}, ${r.results.length} items, '
        'hasNext=${r.hasNextPage}');
  });

  String? firstId;
  await step('search "naruto"', () async {
    final r = await repo.search('naruto');
    if (r.results.isEmpty) throw 'no results';
    firstId = r.results.first.id;
    print('         top hit: ${r.results.first.title} ($firstId)');
  });

  String? episodeId;
  await step('info(id) returns episodes', () async {
    final info = await repo.info(firstId ?? 'naruto-eybxz');
    if (info.episodes.isEmpty) throw 'no episodes';
    episodeId = info.episodes.first.id;
    print('         ${info.title}: ${info.episodes.length} eps, '
        'genres=${info.genres.take(3).toList()}');
  });

  await step('watch(episodeId) yields a playable HLS source', () async {
    final w = await repo.watch(episodeId ?? 'naruto-eybxz\$ep=1');
    final server = w.playableServer;
    final src = server?.hlsSource;
    if (src == null) throw 'no HLS source';
    print('         server "${server!.name}" referer='
        '${server.headers['Referer']}');
    print('         stream: ${src.file}');
    print('         subs=${server.subtitles.length} '
        'intro=${w.intro != null} outro=${w.outro != null}');
  });

  print(failures == 0
      ? '\nAll data-layer checks passed.'
      : '\n$failures check(s) failed.');
}

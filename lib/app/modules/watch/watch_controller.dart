import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../data/models/anime.dart';
import '../../data/models/episode.dart';
import '../../data/models/watch_progress.dart';
import '../../data/models/watch_response.dart';
import '../../data/repositories/anime_repository.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/storage_service.dart';
import 'watch_args.dart';

class WatchController extends GetxController {
  final AnimeRepository _repo = Get.find();
  final StorageService _storage = Get.find();
  final NotificationService _notifications = Get.find();

  late final Anime anime;
  late final List<Episode> episodes;

  late final WebViewController webViewController;

  /// Whether the watch metadata (server list) is being fetched.
  final RxBool loading = true.obs;

  /// Whether the embedded player page itself is still loading.
  final RxBool playerLoading = false.obs;
  final RxnString error = RxnString();

  final Rx<Episode?> current = Rx<Episode?>(null);

  /// Servers returned for the current episode.
  final RxList<WatchServer> servers = <WatchServer>[].obs;
  final RxInt selectedServer = 0.obs;

  /// false = SUB, true = DUB.
  final RxBool dubSelected = false.obs;

  /// Episode numbers the user has already opened, for the watched indicator.
  final RxSet<int> watchedEpisodes = <int>{}.obs;

  /// Host of the currently embedded player; used to block ad redirects.
  String? _embedHost;

  /// The native fullscreen video view surfaced by the WebView (HTML5
  /// fullscreen). Non-null while a video is playing fullscreen.
  final Rxn<Widget> fullscreenWidget = Rxn<Widget>();

  /// Callback handed to us by the WebView to dismiss the fullscreen view.
  void Function()? _exitFullscreen;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as WatchArgs;
    anime = args.anime;
    episodes = args.episodes;
    dubSelected.value = args.preferDub;
    watchedEpisodes.addAll(_storage.watchedEpisodeNumbers(anime.id));

    // Keep the screen on while in the player.
    WakelockPlus.enable();

    // Don't let episode reminders pop over the video while watching.
    _notifications.suppress();

    webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      // Swallow popup-style JS dialogs that ad scripts spam.
      ..setOnJavaScriptAlertDialog((_) async {})
      ..setOnJavaScriptConfirmDialog((_) async => false)
      ..setOnJavaScriptTextInputDialog((_) async => '')
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigation,
          onPageStarted: (_) => playerLoading.value = true,
          onPageFinished: (_) => playerLoading.value = false,
          onWebResourceError: (e) {
            // Sub-resource failures inside the player page are noisy and
            // expected; only surface a hard navigation failure.
            if (e.isForMainFrame ?? false) {
              error.value = 'Player failed to load: ${e.description}';
              playerLoading.value = false;
            }
          },
        ),
      );

    // Allow the embedded video to autoplay WITH sound. Android WebView blocks
    // media playback until a user gesture by default, which starts it muted.
    final platform = webViewController.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
      // When a video enters HTML5 fullscreen, the WebView hands us a native
      // view to display edge-to-edge. Rotate to landscape while it's shown
      // and restore portrait when the user exits.
      platform.setCustomWidgetCallbacks(
        onShowCustomWidget: (widget, onHide) {
          _exitFullscreen = onHide;
          fullscreenWidget.value = widget;
          SystemChrome.setPreferredOrientations(const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        },
        onHideCustomWidget: () {
          _exitFullscreen = null;
          fullscreenWidget.value = null;
          SystemChrome.setPreferredOrientations(const [
            DeviceOrientation.portraitUp,
          ]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        },
      );
    }

    _loadEpisode(args.startEpisode);
  }

  /// Exit fullscreen video (driven by the Android back button).
  bool exitFullscreen() {
    final exit = _exitFullscreen;
    if (exit == null) return false;
    exit();
    return true;
  }

  /// Block top-level navigations away from the player host (ad pop-ups /
  /// redirects) while allowing the player's own sub-resources to load.
  NavigationDecision _onNavigation(NavigationRequest request) {
    if (!request.isMainFrame) return NavigationDecision.navigate;
    final host = Uri.tryParse(request.url)?.host ?? '';
    final embed = _embedHost;
    if (embed == null ||
        host.isEmpty ||
        host == embed ||
        host.endsWith('.$embed') ||
        embed.endsWith('.$host')) {
      return NavigationDecision.navigate;
    }
    return NavigationDecision.prevent;
  }

  /// Whether the current episode offers a subtitled / dubbed track.
  bool get subAvailable => current.value?.isSubbed ?? true;
  bool get dubAvailable => current.value?.isDubbed ?? false;

  int get _currentIndex {
    final c = current.value;
    if (c == null) return -1;
    return episodes.indexWhere((e) => e.id == c.id);
  }

  bool get hasNext => _currentIndex >= 0 && _currentIndex < episodes.length - 1;
  bool get hasPrevious => _currentIndex > 0;

  Future<void> playNext() async {
    if (!hasNext) return;
    await _loadEpisode(episodes[_currentIndex + 1]);
  }

  Future<void> playPrevious() async {
    if (!hasPrevious) return;
    await _loadEpisode(episodes[_currentIndex - 1]);
  }

  Future<void> playEpisode(Episode ep) => _loadEpisode(ep);

  /// Switch to a different server for the current episode.
  void selectServer(int index) {
    if (index < 0 || index >= servers.length) return;
    selectedServer.value = index;
    _loadEmbed(servers[index]);
  }

  void setDub(bool value) {
    if (dubSelected.value == value) return;
    // Ignore a switch to a track this episode doesn't provide.
    if (value && !dubAvailable) return;
    if (!value && !subAvailable) return;
    dubSelected.value = value;
    _storage.preferDub = value;
    final ep = current.value;
    if (ep != null) _loadEpisode(ep);
  }

  Future<void> _loadEpisode(Episode ep) async {
    loading.value = true;
    error.value = null;
    current.value = ep;
    servers.clear();
    // Constrain the requested audio to what this episode actually offers,
    // and keep the toggle in sync with the resolved choice.
    final wantDub = (dubSelected.value && ep.isDubbed) || !ep.isSubbed;
    dubSelected.value = wantDub && ep.isDubbed;
    try {
      final watch = await _repo.watch(ep.id, dub: dubSelected.value);
      final playable =
          watch.servers.where((s) => s.embedUrl != null).toList();
      if (playable.isEmpty) {
        throw 'No playable server for this episode.';
      }
      servers.assignAll(playable);
      selectedServer.value = 0;
      loading.value = false;
      _saveProgress(ep);
      _storage.markEpisodeWatched(anime.id, ep.number);
      watchedEpisodes.add(ep.number);
      _loadEmbed(playable.first);
    } catch (e) {
      error.value = '$e';
      loading.value = false;
    }
  }

  void _loadEmbed(WatchServer server) {
    final url = server.embedUrl;
    if (url == null) return;
    _embedHost = Uri.tryParse(url)?.host;
    playerLoading.value = true;
    webViewController.loadRequest(
      Uri.parse(url),
      headers: server.headers,
    );
  }

  /// Record the episode for "continue watching". The iframe player is
  /// cross-origin, so an exact position is unavailable — we track at
  /// episode granularity so the series can be resumed at the right episode.
  void _saveProgress(Episode ep) {
    final existing = _storage.progressFor(anime.id);
    _storage.saveProgress(WatchProgress(
      anime: anime,
      episodeId: ep.id,
      episodeNumber: ep.number,
      // Preserve any prior position if resuming the same episode, else 0.
      positionMs:
          (existing != null && existing.episodeId == ep.id) ? existing.positionMs : 0,
      durationMs:
          (existing != null && existing.episodeId == ep.id) ? existing.durationMs : 0,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void retry() {
    final ep = current.value;
    if (ep != null) _loadEpisode(ep);
  }

  @override
  void onClose() {
    WakelockPlus.disable();
    // Re-arm episode reminders now that the user has stopped watching.
    _notifications.resume();
    // Make sure we never leave the rest of the app stuck in landscape /
    // immersive mode if the user backs out mid-fullscreen.
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.onClose();
  }
}

import 'dart:async';

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

  /// Servers for the CURRENTLY SELECTED language (filtered view shown as chips).
  final RxList<WatchServer> servers = <WatchServer>[].obs;
  final RxInt selectedServer = 0.obs;

  /// Every server across all languages for the current episode (pre-filter).
  List<WatchServer> _allServers = const [];

  /// Audio languages available for the current episode and the selected one.
  final RxList<String> availableLanguages = <String>[].obs;
  final RxString selectedLanguage = ''.obs;

  /// Episode numbers the user has already opened, for the watched indicator.
  final RxSet<int> watchedEpisodes = <int>{}.obs;

  /// Episode-list search query + sort order. For long series (e.g. One Piece's
  /// 1167 episodes) these let the user jump to an episode and flip the order.
  final RxString episodeQuery = ''.obs;
  /// Remembered across all anime via [StorageService.episodesAscending].
  final RxBool episodesAscending = true.obs;
  final ScrollController episodeScroll = ScrollController();
  final TextEditingController episodeSearchCtrl = TextEditingController();
  final FocusNode episodeSearchFocus = FocusNode();

  /// Episodes filtered by [episodeQuery] (matches number or title) and ordered
  /// by [episodesAscending]. The view renders this through a virtualised
  /// builder, so only on-screen rows are built — no lag on huge lists.
  List<Episode> get visibleEpisodes {
    final q = episodeQuery.value.trim().toLowerCase();
    final list = q.isEmpty
        ? List<Episode>.of(episodes)
        : episodes
            .where((e) =>
                e.number.toString().contains(q) ||
                e.title.toLowerCase().contains(q))
            .toList();
    list.sort((a, b) => episodesAscending.value
        ? a.number.compareTo(b.number)
        : b.number.compareTo(a.number));
    return list;
  }

  void setEpisodeQuery(String q) => episodeQuery.value = q;
  void toggleEpisodeSort() {
    episodesAscending.value = !episodesAscending.value;
    _storage.episodesAscending = episodesAscending.value; // remember globally
  }
  void clearEpisodeQuery() {
    episodeSearchCtrl.clear();
    episodeQuery.value = '';
  }

  /// Host of the currently embedded player; used to block ad redirects.
  String? _embedHost;

  /// Auto-failover: if the active server's page errors or never finishes
  /// loading within this window, advance to the next server for the episode.
  /// (webview_flutter can only see page load failure/hangs — not whether the
  /// video inside a cross-origin iframe actually started — so this covers
  /// dead/blocked embeds, not a frame that loads then fails to play.)
  Timer? _loadTimeout;
  static const Duration _serverTimeout = Duration(seconds: 20);

  /// The native fullscreen video view surfaced by the WebView (HTML5
  /// fullscreen). Non-null while a video is playing fullscreen.
  final Rxn<Widget> fullscreenWidget = Rxn<Widget>();

  /// Callback handed to us by the WebView to dismiss the fullscreen view.
  void Function()? _exitFullscreen;

  /// Injected into every player page to suppress the free hosts' ads. Since
  /// webview_flutter can't intercept network requests, this runs in-page.
  ///
  /// IMPORTANT: it must never touch the player. The video lives in a
  /// cross-origin iframe, so the parent document can't see the <video> inside
  /// it — any DOM-mutation heuristic that removes iframes or hides "big" boxes
  /// ends up hiding the player itself (audio keeps playing, picture goes black).
  /// So we only do non-destructive popup/redirect suppression here:
  ///   - neutralise window.open / JS dialogs (pop-ups, "you won" alerts),
  ///   - strip target="_blank" so ad links can't spawn new tabs,
  ///   - widen the layout viewport so the player's own control bar (≈9 buttons
  ///     + timecode) has room and stops overlapping in the narrow portrait
  ///     WebView (the page is laid out at a virtual width, then scaled to fit).
  /// and rely on the native navigation delegate + custom-widget callbacks to
  /// keep the user on the player host. No iframe removal, no display:none.
  static const String _adBlockJs = r'''
(function(){
  if(window.__mab) return; window.__mab=1;
  try{
    window.open=function(){return null;};
    window.alert=function(){};window.confirm=function(){return false;};window.prompt=function(){return null;};
    // Ad scripts use Notification permission prompts for spam — auto-deny.
    try{ if(window.Notification){ window.Notification.requestPermission=function(){ return Promise.resolve('denied'); }; } }catch(e){}
    function fixViewport(){
      try{
        var vp=document.querySelector('meta[name="viewport"]');
        if(!vp){vp=document.createElement('meta');vp.setAttribute('name','viewport');(document.head||document.documentElement).appendChild(vp);}
        var want='width=600, user-scalable=no';
        if(vp.getAttribute('content')!==want) vp.setAttribute('content',want);
      }catch(e){}
    }
    function strip(){
      try{
        [].forEach.call(document.querySelectorAll('a[target="_blank"]'),function(a){ a.removeAttribute('target'); });
        // Surgically drop the FirePlayer / as-cdn pop-under overlay: ".pppx" is a
        // transparent full-screen click-sink that pop-opens an ad on the first
        // tap. It is an ad-only class (never the player), so removing it both
        // kills the pop and lets the first tap reach the real play button.
        [].forEach.call(document.querySelectorAll('.pppx'),function(el){ el.remove(); });
      }catch(e){}
    }
    fixViewport(); strip(); setInterval(function(){fixViewport();strip();},1000);
  }catch(e){}
})();
''';

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as WatchArgs;
    anime = args.anime;
    episodes = args.episodes;
    // Initial language preference: last-used, else dub→english / sub→japanese.
    selectedLanguage.value =
        _storage.preferredLanguage ?? (args.preferDub ? 'english' : 'japanese');
    watchedEpisodes.addAll(_storage.watchedEpisodeNumbers(anime.id));
    episodesAscending.value = _storage.episodesAscending; // remembered globally

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
          onPageStarted: (_) {
            playerLoading.value = true;
            webViewController.runJavaScript(_adBlockJs);
          },
          onPageFinished: (url) {
            playerLoading.value = false;
            // The real embed loaded — cancel the failover timer (the blank
            // reset page also fires this, so only the real URL counts).
            if (url != 'about:blank') _loadTimeout?.cancel();
            webViewController.runJavaScript(_adBlockJs);
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame ?? false) _onServerFailed();
          },
        ),
      );

    // Allow the embedded video to autoplay WITH sound.
    final platform = webViewController.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
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
    // Our own reset between embeds.
    if (request.url == 'about:blank') return NavigationDecision.navigate;
    final uri = Uri.tryParse(request.url);
    final scheme = uri?.scheme ?? '';
    // Block app-launch / store-redirect ads (intent://, market://, tg://,
    // whatsapp://, …) that try to kick the user out of the player.
    if (scheme != 'http' && scheme != 'https') {
      return NavigationDecision.prevent;
    }
    final host = uri?.host ?? '';
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

  /// Pick the language to show: keep the current one if still available, else
  /// the stored preference, else japanese → english → first available.
  void _resolveSelectedLanguage() {
    final avail = availableLanguages;
    if (avail.isEmpty) return;
    if (selectedLanguage.value.isNotEmpty &&
        avail.contains(selectedLanguage.value)) {
      return;
    }
    final stored = _storage.preferredLanguage;
    selectedLanguage.value = (stored != null && avail.contains(stored))
        ? stored
        : avail.contains('japanese')
            ? 'japanese'
            : avail.contains('english')
                ? 'english'
                : avail.first;
  }

  /// Filter [_allServers] down to the selected language's servers.
  void _applyLanguageFilter() {
    final lang = selectedLanguage.value;
    var list = _allServers.where((s) => s.lang == lang).toList();
    if (list.isEmpty) list = _allServers; // no per-lang tag → show everything
    servers.assignAll(list);
    selectedServer.value = 0;
  }

  /// Switch audio language (no refetch — all languages are already loaded).
  void setLanguage(String lang) {
    if (selectedLanguage.value == lang) return;
    selectedLanguage.value = lang;
    _storage.preferredLanguage = lang;
    if (lang == 'english') {
      _storage.preferDub = true;
    } else if (lang == 'japanese') {
      _storage.preferDub = false;
    }
    _applyLanguageFilter();
    if (servers.isNotEmpty) _playServer(0);
  }

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

  /// Switch to a different server for the current episode (user tap).
  void selectServer(int index) {
    if (index < 0 || index >= servers.length) return;
    _playServer(index);
  }

  /// Select [index] as the active server and load its embed.
  void _playServer(int index) {
    selectedServer.value = index;
    _loadEmbed(servers[index]);
  }

  /// The active server failed — its page errored or never finished loading.
  /// Fall back to the next server for this episode, or surface an error once
  /// every server has been tried.
  void _onServerFailed({bool timedOut = false}) {
    _loadTimeout?.cancel();
    final failedIndex = selectedServer.value;
    final next = failedIndex + 1;
    if (next < servers.length) {
      final from = servers[failedIndex].displayName;
      final to = servers[next].displayName;
      _playServer(next);
      Get.rawSnackbar(
        message: '$from ${timedOut ? "timed out" : "failed"} — trying $to',
        duration: const Duration(seconds: 2),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        borderRadius: 8,
      );
    } else {
      playerLoading.value = false;
      error.value =
          "Couldn't play any server for this episode. Try another audio "
          'language or episode.';
    }
  }

  Future<void> _loadEpisode(Episode ep) async {
    loading.value = true;
    error.value = null;
    current.value = ep;
    servers.clear();
    try {
      final watch = await _repo.watch(ep.id);
      _allServers = watch.servers.where((s) => s.embedUrl != null).toList();
      if (_allServers.isEmpty) {
        throw 'No playable server for this episode.';
      }
      availableLanguages.assignAll(watch.languages);
      _resolveSelectedLanguage();
      _applyLanguageFilter();
      loading.value = false;
      _saveProgress(ep);
      _storage.markEpisodeWatched(anime.id, ep.number);
      watchedEpisodes.add(ep.number);
      if (servers.isNotEmpty) _playServer(0);
    } catch (e) {
      error.value = '$e';
      loading.value = false;
    }
  }

  void _loadEmbed(WatchServer server) {
    final url = server.embedUrl;
    if (url == null) return;
    _embedHost = Uri.tryParse(url)?.host;
    error.value = null;
    playerLoading.value = true;
    _loadTimeout?.cancel();
    // Reset the WebView before loading the new player so the previous <video>'s
    // surface is released (otherwise the new stream can render black on switch).
    webViewController.loadRequest(Uri.parse('about:blank'));
    Future.delayed(const Duration(milliseconds: 150), () {
      // Arm the failover timer only for the real embed (not the blank reset);
      // onPageFinished for the real URL cancels it.
      _loadTimeout = Timer(_serverTimeout, () {
        if (playerLoading.value) _onServerFailed(timedOut: true);
      });
      webViewController.loadRequest(Uri.parse(url), headers: server.headers);
    });
  }

  /// Record the episode for "continue watching".
  void _saveProgress(Episode ep) {
    final existing = _storage.progressFor(anime.id);
    _storage.saveProgress(WatchProgress(
      anime: anime,
      episodeId: ep.id,
      episodeNumber: ep.number,
      positionMs: (existing != null && existing.episodeId == ep.id)
          ? existing.positionMs
          : 0,
      durationMs: (existing != null && existing.episodeId == ep.id)
          ? existing.durationMs
          : 0,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void retry() {
    final ep = current.value;
    if (ep != null) _loadEpisode(ep);
  }

  @override
  void onClose() {
    _loadTimeout?.cancel();
    episodeScroll.dispose();
    episodeSearchCtrl.dispose();
    episodeSearchFocus.dispose();
    WakelockPlus.disable();
    _notifications.resume();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.onClose();
  }
}

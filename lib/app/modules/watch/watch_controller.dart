import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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

  /// The InAppWebView controller, available once the widget is created.
  InAppWebViewController? _web;

  /// A player URL queued before the WebView controller was ready.
  String? _pendingUrl;
  Map<String, String> _pendingHeaders = const {};

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

  /// Host of the currently embedded player; used to block ad redirects.
  String? _embedHost;

  /// Whether an HTML5 video is currently in native fullscreen.
  bool _isFullscreen = false;

  /// Network-level ad blocking: drop requests to known ad / pop-under networks
  /// before they load, across every frame. This is what kills the modal/banner
  /// ads the free players inject (webview_flutter's JS injection couldn't reach
  /// them inside cross-origin sub-frames).
  static final List<ContentBlocker> adBlockers = [
    for (final p in _adUrlPatterns)
      ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: p),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
  ];

  static const List<String> _adUrlPatterns = [
    r".*doubleclick\.net.*",
    r".*googlesyndication\.com.*",
    r".*googleadservices\.com.*",
    r".*popads\.net.*",
    r".*popcash.*",
    r".*propellerads.*",
    r".*propu\..*",
    r".*adsterra.*",
    r".*exoclick.*",
    r".*exosrv.*",
    r".*juicyads.*",
    r".*hilltopads.*",
    r".*clickadu.*",
    r".*mgid\..*",
    r".*monetag.*",
    r".*adcash.*",
    r".*onclickads.*",
    r".*popunder.*",
    r".*bidgear.*",
    r".*a-ads\..*",
    r".*adnxs\.com.*",
    r".*histats.*",
    r".*pushvio.*",
    r".*vidoomy.*",
    r".*adservice.*",
    r".*adskeeper.*",
    r".*adsterranet.*",
    r".*highperformanceformat.*",
    r".*pemsrv.*",
    r".*tsyndicate.*",
    r".*sw\.js.*push.*",
  ];

  /// Extra in-page hardening injected into each player page: kill popups, strip
  /// `_blank` redirect links, and hide any leftover overlay ad boxes — while
  /// protecting the real player iframe (matched by host) and any <video>.
  static const String _hardenJs = '''
(function(){
  if(window.__mab) return; window.__mab=1;
  try{
    window.open=function(){return null;};
    window.alert=function(){};window.confirm=function(){return false;};window.prompt=function(){return null;};
    var PLAYER=/vidnest|megaplay|zephyrflick|videasy|vidwish|streamzone|uwucdn|anvod|as-cdn|short\\.icu|animelok/i;
    function isPlayer(el){
      if(el.querySelector && el.querySelector('video')) return true;
      var f = el.tagName==='IFRAME'? el : (el.querySelector? el.querySelector('iframe') : null);
      return !!(f && PLAYER.test(f.src||''));
    }
    function clean(){
      try{
        var W=window.innerWidth, H=window.innerHeight;
        [].forEach.call(document.querySelectorAll('a[target="_blank"]'),function(a){ a.removeAttribute('target'); });
        [].forEach.call(document.querySelectorAll('body *'),function(el){
          var s=getComputedStyle(el);
          if(s.position!=='fixed' && s.position!=='absolute') return;
          if((parseInt(s.zIndex)||0) < 5) return;
          var w=el.offsetWidth, h=el.offsetHeight;
          var banner = w>W*0.5 && h>H*0.08 && h<H*0.85;
          var big = w>W*0.4 && h>H*0.4;
          if((banner||big) && !isPlayer(el) && !(el.querySelector&&el.querySelector('video'))){
            el.style.setProperty('display','none','important');
          }
        });
      }catch(e){}
    }
    clean(); setInterval(clean,1000);
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

    // Keep the screen on while in the player.
    WakelockPlus.enable();

    // Don't let episode reminders pop over the video while watching.
    _notifications.suppress();

    _loadEpisode(args.startEpisode);
  }

  // ── WebView wiring (called from the view) ─────────────────────────────────

  void onWebViewCreated(InAppWebViewController controller) {
    _web = controller;
    final url = _pendingUrl;
    if (url != null) {
      _pendingUrl = null;
      _web!.loadUrl(
        urlRequest: URLRequest(url: WebUri(url), headers: _pendingHeaders),
      );
    }
  }

  void onLoadStart() {
    playerLoading.value = true;
  }

  void onLoadStop(InAppWebViewController controller) {
    playerLoading.value = false;
    controller.evaluateJavascript(source: _hardenJs);
  }

  void onReceivedError(WebResourceError err, bool isForMainFrame) {
    if (isForMainFrame) {
      error.value = 'Player failed to load: ${err.description}';
      playerLoading.value = false;
    }
  }

  /// Block top-level navigations away from the player host (ad pop-ups /
  /// redirects) while allowing the player's own sub-resources to load.
  Future<NavigationActionPolicy?> shouldOverride(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    if (!action.isForMainFrame) return NavigationActionPolicy.ALLOW;
    final host = action.request.url?.host ?? '';
    final embed = _embedHost;
    if (embed == null ||
        host.isEmpty ||
        host == embed ||
        host.endsWith('.$embed') ||
        embed.endsWith('.$host')) {
      return NavigationActionPolicy.ALLOW;
    }
    return NavigationActionPolicy.CANCEL;
  }

  /// Block the free players' attempts to open new windows / pop-unders.
  Future<bool> onCreateWindow(
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    return false;
  }

  void onEnterFullscreen() {
    _isFullscreen = true;
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void onExitFullscreen() {
    _isFullscreen = false;
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// Whether a fullscreen video is active (native back exits it on its own).
  bool get isFullscreen => _isFullscreen;

  // ── Language / server selection ───────────────────────────────────────────

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
    if (servers.isNotEmpty) _loadEmbed(servers.first);
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

  /// Switch to a different server for the current episode.
  void selectServer(int index) {
    if (index < 0 || index >= servers.length) return;
    selectedServer.value = index;
    _loadEmbed(servers[index]);
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
      if (servers.isNotEmpty) _loadEmbed(servers.first);
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
    final headers = server.headers;
    final web = _web;
    if (web == null) {
      // The WebView isn't ready yet — queue it for onWebViewCreated.
      _pendingUrl = url;
      _pendingHeaders = headers;
      return;
    }
    // Reset before loading the new player so the previous <video>'s surface is
    // released (otherwise the new stream can render as a black frame on switch).
    web.loadUrl(urlRequest: URLRequest(url: WebUri('about:blank')));
    Future.delayed(const Duration(milliseconds: 150), () {
      _web?.loadUrl(
        urlRequest: URLRequest(url: WebUri(url), headers: headers),
      );
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
    WakelockPlus.disable();
    _notifications.resume();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.onClose();
  }
}

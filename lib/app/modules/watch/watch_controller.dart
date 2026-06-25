import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

  /// Set once the InAppWebView is created (see [onWebViewCreated]).
  InAppWebViewController? _web;

  /// Whether the watch metadata (server list) is being fetched.
  final RxBool loading = true.obs;

  /// Whether the embedded player page itself is still loading.
  final RxBool playerLoading = false.obs;
  final RxnString error = RxnString();

  final Rx<Episode?> current = Rx<Episode?>(null);

  /// True while the embed's HTML5 video is in fullscreen (inappwebview shows it
  /// natively; we only flip orientation/system UI here).
  final RxBool isFullscreen = false.obs;

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

  /// Server queued to load before the WebView exists yet (onInit fetches and
  /// picks a server before [onWebViewCreated] fires).
  WatchServer? _pendingServer;

  /// Auto-failover: if the active server's page errors or never finishes
  /// loading within this window, advance to the next server for the episode.
  Timer? _loadTimeout;
  static const Duration _serverTimeout = Duration(seconds: 20);

  // ─── Ad blocking ───────────────────────────────────────────────────────────

  /// Network-level blocklist for known pop-ad / ad-network hosts. Because
  /// flutter_inappwebview supports content blockers, these requests are dropped
  /// before they load — the real fix plain webview_flutter couldn't do.
  static const List<String> _adHostPatterns = [
    // Throwaway TLDs used by the rotating banner/pop ad networks in these
    // embeds. The ad hosts have random names that change every session, but
    // they all sit on these cheap TLDs — and no legitimate video resource here
    // uses them (the player/CDNs are .fun/.top/.buzz/ani.zip/thetvdb.com), so
    // blocking the whole TLD is safe and survives the rotation.
    r'\.cfd', r'\.cyou', r'\.sbs', r'\.shop', r'\.bond', r'\.quest', r'\.click',
    // Stable ad hosts observed in the resource log / earlier analysis.
    r'lacisaboma\.com', r'casteschagoma\.com', r'firevideoplayer\.com',
    // Known pop-ad / ad networks (belt-and-suspenders).
    r'popads', r'popcash', r'poptm', r'popunder',
    r'propellerads', r'propu\.', r'pushwhy',
    r'adsterra', r'hilltopads', r'onclicka', r'onclckbn',
    r'monetag', r'clickadu', r'adnium', r'adskeeper',
    r'highperformanceformat', r'profitabledisplay', r'effectivegate',
    r'a-ads', r'adnxs', r'adservme', r'adsco\.re',
  ];

  static final List<ContentBlocker> adBlockers = [
    for (final p in _adHostPatterns)
      ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: '.*$p.*'),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
  ];

  /// Injected at document start into EVERY frame (forMainFrameOnly: false) — so
  /// it also runs inside the cross-origin player/ad iframe that the previous
  /// webview_flutter setup could never reach. Non-destructive: it neutralises
  /// pop-ups and the FirePlayer/as-cdn ad handshake without touching the video.
  static const String _adBlockJs = r'''
(function(){
  if(window.__mab) return; window.__mab=1;
  try{
    window.open=function(){return null;};
    window.alert=function(){};window.confirm=function(){return false;};window.prompt=function(){return null;};
    try{ if(window.Notification){ window.Notification.requestPermission=function(){ return Promise.resolve('denied'); }; } }catch(e){}
    // Refuse the as-cdn / FirePlayer pop-ad handshake: decline instead of granting.
    try{
      window.addEventListener('message',function(e){
        var d=e&&e.data; var t=(typeof d==='string')?d:(d&&d.action);
        if(t==='as_request_ad_permission'){ try{(e.source||window).postMessage('no_ads','*');}catch(_){} }
      },true);
    }catch(e){}
    var TOP=(window.top===window);
    function fixViewport(){ if(!TOP) return; try{
      var vp=document.querySelector('meta[name="viewport"]');
      if(!vp){vp=document.createElement('meta');vp.setAttribute('name','viewport');(document.head||document.documentElement).appendChild(vp);}
      var want='width=600, user-scalable=no';
      if(vp.getAttribute('content')!==want) vp.setAttribute('content',want);
    }catch(e){} }
    function strip(){ try{
      [].forEach.call(document.querySelectorAll('a[target="_blank"]'),function(a){ a.removeAttribute('target'); });
      // FirePlayer/as-cdn transparent first-tap pop-under overlay (ad-only class).
      [].forEach.call(document.querySelectorAll('.pppx'),function(el){ el.remove(); });
    }catch(e){} }
    fixViewport(); strip(); setInterval(function(){fixViewport();strip();},1000);
  }catch(e){}
})();
''';

  InAppWebViewSettings get webSettings => InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: false, // autoplay with sound
        allowsInlineMediaPlayback: true,
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: false,
        supportMultipleWindows: false, // popups never spawn a second window
        useShouldOverrideUrlLoading: true,
        useOnLoadResource: false,
        transparentBackground: false,
        iframeAllowFullscreen: true,
        useHybridComposition: true,
        contentBlockers: adBlockers,
      );

  UnmodifiableListView<UserScript> get userScripts =>
      UnmodifiableListView<UserScript>([
        UserScript(
          source: _adBlockJs,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
      ]);

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

    WakelockPlus.enable(); // keep the screen on while watching
    _notifications.suppress(); // no reminders popping over the video

    _loadEpisode(args.startEpisode);
  }

  // ─── InAppWebView callbacks (wired from the view) ───────────────────────────

  void onWebViewCreated(InAppWebViewController c) {
    _web = c;
    final pending = _pendingServer;
    _pendingServer = null;
    if (pending != null) _loadEmbed(pending);
  }

  void onLoadStart(WebUri? url) {
    playerLoading.value = true;
  }

  void onLoadStop(WebUri? url) {
    playerLoading.value = false;
    // The real embed loaded — cancel the failover timer (the blank reset page
    // also fires this, so only the real URL counts).
    if (url != null && url.toString() != 'about:blank') _loadTimeout?.cancel();
  }

  void onMainFrameError() => _onServerFailed();

  /// Block top-level navigations away from the player host (ad pop-ups /
  /// redirects) while allowing the player's own sub-frame resources.
  Future<NavigationActionPolicy> shouldOverride(
      WebUri? url, bool isMainFrame) async {
    if (!isMainFrame || url == null) return NavigationActionPolicy.ALLOW;
    final s = url.toString();
    if (s == 'about:blank') return NavigationActionPolicy.ALLOW;
    final scheme = url.scheme;
    // Block app-launch / store-redirect ads (intent://, market://, tg://, …).
    if (scheme != 'http' && scheme != 'https') {
      return NavigationActionPolicy.CANCEL;
    }
    final host = url.host;
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

  /// Never let a page open a new window/tab — pop-ups and pop-unders die here.
  Future<bool> onCreateWindow() async => false;

  /// Deny ad-driven permission prompts (camera/mic/notification/geo) but GRANT
  /// protected-media / MIDI so any DRM embed still plays (a blanket deny would
  /// black the video).
  Future<PermissionResponse> onPermissionRequest(
      List<PermissionResourceType> resources) async {
    final keep = resources.contains(PermissionResourceType.PROTECTED_MEDIA_ID) ||
        resources.contains(PermissionResourceType.MIDI_SYSEX);
    return PermissionResponse(
      resources: resources,
      action: keep
          ? PermissionResponseAction.GRANT
          : PermissionResponseAction.DENY,
    );
  }

  void onEnterFullscreen() {
    isFullscreen.value = true;
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void onExitFullscreen() {
    isFullscreen.value = false;
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// Exit HTML5 fullscreen (driven by the Android back button). Returns true if
  /// it handled the back press.
  bool exitFullscreen() {
    if (!isFullscreen.value) return false;
    _web?.evaluateJavascript(
        source: 'try{document.exitFullscreen&&document.exitFullscreen();}catch(e){}');
    return true;
  }

  // ─── Language / server selection ────────────────────────────────────────────

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

  void _applyLanguageFilter() {
    final lang = selectedLanguage.value;
    var list = _allServers.where((s) => s.lang == lang).toList();
    if (list.isEmpty) list = _allServers; // no per-lang tag → show everything
    servers.assignAll(list);
    selectedServer.value = 0;
  }

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

  void _playServer(int index) {
    selectedServer.value = index;
    _loadEmbed(servers[index]);
  }

  /// The active server failed — fall back to the next, or surface an error once
  /// every server has been tried.
  void _onServerFailed({bool timedOut = false}) {
    _loadTimeout?.cancel();
    final failedIndex = selectedServer.value;
    final next = failedIndex + 1;
    if (next >= 0 && next < servers.length && failedIndex < servers.length) {
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
    final web = _web;
    if (web == null) {
      _pendingServer = server; // load once the WebView is created
      return;
    }
    // Reset before loading so the previous <video>'s surface is released.
    web.loadUrl(urlRequest: URLRequest(url: WebUri('about:blank')));
    Future.delayed(const Duration(milliseconds: 150), () {
      _loadTimeout = Timer(_serverTimeout, () {
        if (playerLoading.value) _onServerFailed(timedOut: true);
      });
      web.loadUrl(urlRequest: URLRequest(
        url: WebUri(url),
        headers: server.headers,
      ));
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

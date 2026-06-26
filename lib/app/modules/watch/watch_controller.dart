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
import '../../data/services/ads_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/remote_settings_service.dart';
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

  /// Stable key for the player's [InAppWebView] platform view. Keeping the same
  /// key across rebuilds stops Flutter from remounting (disposing + recreating)
  /// the native WebView when the layout changes on rotation — a remount during
  /// native HTML5 fullscreen disposes the WebView that owns the fullscreen video
  /// surface, freezing it in landscape.
  final GlobalKey playerWebViewKey = GlobalKey();

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
  /// by [episodesAscending]. Maintained by [_recomputeVisible] (wired to debounced
  /// query + sort workers in [onInit]) instead of recomputed on every rebuild —
  /// the filter+sort is O(n log n) and `episodes` can be 1000+ (One Piece), so
  /// recomputing per Next/Prev/watched tap dropped frames. The view renders this
  /// through a virtualised builder, so only on-screen rows are built.
  final RxList<Episode> visibleEpisodes = <Episode>[].obs;

  void _recomputeVisible() {
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
    visibleEpisodes.assignAll(list);
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

  // ─── Navigation containment (NOT ad blocking) ───────────────────────────────
  //
  // We no longer try to BLOCK ads. Network/JS ad-blocking proved fragile — it
  // kept catching proxied video segments and freezing playback — so ads are now
  // left to render. We only CONTAIN them: an ad tap must never navigate the
  // player away, open another app or window, or leave MugenStream / rotate it.
  // That containment is enforced natively below — `onCreateWindow => false`
  // (kills pop-ups/pop-unders), `shouldOverride` (cancels any navigation to a
  // foreign host or non-http scheme like intent://, market://, tg://), and the
  // popup-proof settings — without any ad blocklist that could touch the video.

  /// Top-frame-only viewport fix so the player's own controls don't overlap in
  /// portrait. (UI fix, unrelated to ads.)
  static const String _viewportJs = r'''
(function(){
  if(window.__mvp || window.top!==window) return; window.__mvp=1;
  function fix(){ try{
    var vp=document.querySelector('meta[name="viewport"]');
    if(!vp){vp=document.createElement('meta');vp.setAttribute('name','viewport');(document.head||document.documentElement).appendChild(vp);}
    var want='width=600, user-scalable=no';
    if(vp.getAttribute('content')!==want) vp.setAttribute('content',want);
  }catch(e){} }
  fix(); setInterval(fix,1000);
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
      );

  UnmodifiableListView<UserScript> get userScripts =>
      UnmodifiableListView<UserScript>([
        UserScript(
          source: _viewportJs,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: true,
        ),
      ]);

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as WatchArgs;
    anime = args.anime;
    episodes = args.episodes;
    // Newest episode (highest number) — always gated behind a rewarded ad.
    if (episodes.isNotEmpty) {
      _newestEpisodeId =
          episodes.reduce((a, b) => a.number >= b.number ? a : b).id;
    }
    // Initial language preference: last-used, else dub→english / sub→japanese.
    selectedLanguage.value =
        _storage.preferredLanguage ?? (args.preferDub ? 'english' : 'japanese');
    watchedEpisodes.addAll(_storage.watchedEpisodeNumbers(anime.id));
    episodesAscending.value = _storage.episodesAscending; // remembered globally

    // Maintain the filtered/sorted episode list off the rebuild path: recompute
    // only when the query (debounced) or sort order actually changes.
    _recomputeVisible();
    debounce(episodeQuery, (_) => _recomputeVisible(),
        time: const Duration(milliseconds: 200));
    ever(episodesAscending, (_) => _recomputeVisible());

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
    _loadTimeout?.cancel();
  }

  /// Safety net: some embeds finish without a reliable onLoadStop. When the
  /// main page reports full progress, treat it as loaded so the spinner can't
  /// stick over a (working) player.
  void onProgress(int progress) {
    if (progress >= 100) {
      playerLoading.value = false;
      _loadTimeout?.cancel();
    }
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void onExitFullscreen() {
    isFullscreen.value = false;
    // `manual` + all overlays reliably restores the status/nav bars and clears
    // the sticky-immersive flags (edgeToEdge alone leaves them hidden on
    // Android 15/16). The view's build() re-asserts this on the portrait frame.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    // Force back to portrait (not just allow it) so the screen rotates down on
    // its own when the user leaves fullscreen.
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
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

  /// True for providers that expose audio as Sub/Dub (anizen, anivid) instead
  /// of a `languages` array (animelok). In this mode switching audio refetches
  /// the watch endpoint with `?type=sub|dub` rather than client-side filtering.
  bool _subDubMode = false;

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
    if (lang == 'english' || lang == 'dub') {
      _storage.preferDub = true;
    } else if (lang == 'japanese' || lang == 'sub') {
      _storage.preferDub = false;
    }
    if (_subDubMode) {
      _reloadSubDubServers(lang);
    } else {
      _applyLanguageFilter();
      if (servers.isNotEmpty) _playServer(0);
    }
  }

  /// Refetch the watch endpoint for a sub/dub provider when audio is toggled.
  Future<void> _reloadSubDubServers(String type) async {
    final ep = current.value;
    if (ep == null) return;
    loading.value = true;
    error.value = null;
    servers.clear();
    try {
      final w = await _repo.watch(ep.id, type: type);
      _allServers = w.servers.where((s) => s.embedUrl != null).toList();
      if (_allServers.isEmpty) throw 'No $type server for this episode.';
      servers.assignAll(_allServers);
      selectedServer.value = 0;
      loading.value = false;
      _playServer(0);
    } catch (e) {
      error.value = '$e';
      loading.value = false;
    }
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

  /// Episodes unlocked via a rewarded ad this session (so we don't re-prompt).
  final Set<String> _unlockedEpisodes = {};

  /// Id of the newest episode — always rewarded while locking is enabled.
  String? _newestEpisodeId;

  /// Show an ad on EVERY episode open. While locking is enabled
  /// (`mugenpro_ads_rewarded_unlock`, the remote master switch):
  ///   • the newest episode ALWAYS shows a rewarded ad,
  ///   • an API-locked episode (`episode.locked`) shows a rewarded ad until the
  ///     user unlocks it this session, after which it shows an interstitial,
  ///   • every other episode shows an interstitial.
  /// With locking disabled, every open shows an interstitial. Fail-open: a
  /// no-fill ad never blocks playback.
  Future<void> _maybeShowEpisodeAd(Episode ep) async {
    if (!Get.isRegistered<AdsService>()) return;
    final ads = Get.find<AdsService>();
    final lockMode = Get.isRegistered<RemoteSettingsService>() &&
        Get.find<RemoteSettingsService>().rewardedUnlock.value;
    final isNewest = ep.id == _newestEpisodeId;
    final showReward = lockMode &&
        (isNewest || (ep.locked && !_unlockedEpisodes.contains(ep.id)));
    if (showReward) {
      final earned = await ads.showRewarded();
      // Newest stays gated forever; other locked episodes unlock once watched.
      if (earned && !isNewest) _unlockedEpisodes.add(ep.id);
    } else {
      ads.showInterstitialNow();
    }
  }

  Future<void> _loadEpisode(Episode ep) async {
    await _maybeShowEpisodeAd(ep);
    loading.value = true;
    error.value = null;
    current.value = ep;
    servers.clear();
    try {
      final watch = await _repo.watch(ep.id);
      if (watch.languages.isNotEmpty) {
        // Multi-language provider (animelok): every audio track is in this one
        // response; filter client-side by language.
        _subDubMode = false;
        _allServers = watch.servers.where((s) => s.embedUrl != null).toList();
        if (_allServers.isEmpty) throw 'No playable server for this episode.';
        availableLanguages.assignAll(watch.languages);
        _resolveSelectedLanguage();
        _applyLanguageFilter();
      } else {
        // Sub/Dub provider (anizen, anivid): type=all is the sub track; dub is a
        // separate fetch. Offer the toggle when the episode has a dub.
        _subDubMode = true;
        await _setupSubDub(ep, watch);
      }
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

  /// Configure audio options + servers for a sub/dub provider. [subWatch] is the
  /// already-fetched type=all (== sub) response.
  Future<void> _setupSubDub(Episode ep, WatchResponse subWatch) async {
    final subServers =
        subWatch.servers.where((s) => s.embedUrl != null).toList();
    final subAvail = subServers.isNotEmpty;
    final dubAvail = ep.isDubbed;
    availableLanguages.assignAll([
      if (subAvail) 'sub',
      if (dubAvail) 'dub',
    ]);
    final wantDub = _storage.preferDub && dubAvail;
    selectedLanguage.value = wantDub ? 'dub' : (subAvail ? 'sub' : 'dub');
    if (selectedLanguage.value == 'dub') {
      final dubWatch = await _repo.watch(ep.id, type: 'dub');
      _allServers = dubWatch.servers.where((s) => s.embedUrl != null).toList();
    } else {
      _allServers = subServers;
    }
    if (_allServers.isEmpty) throw 'No playable server for this episode.';
    servers.assignAll(_allServers);
    selectedServer.value = 0;
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
    // Load the embed directly. (inappwebview replaces the page itself, so the
    // webview_flutter-era about:blank double-load isn't needed — and that race
    // could leave onLoadStop unfired, sticking the spinner.)
    _loadTimeout = Timer(_serverTimeout, () {
      if (playerLoading.value) _onServerFailed(timedOut: true);
    });
    web.loadUrl(urlRequest: URLRequest(
      url: WebUri(url),
      headers: server.headers,
    ));
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    super.onClose();
  }
}

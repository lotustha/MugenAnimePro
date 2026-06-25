import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/wallpaper.dart';
import '../../data/repositories/content_repository.dart';

class WallpaperDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WallpaperDetailController>(() => WallpaperDetailController());
  }
}

class WallpaperDetailController extends GetxController {
  static const _wallpaperChannel = MethodChannel('mugen/wallpaper');

  final ContentRepository _repo = Get.find();
  final Dio _dio = Dio();

  final Rxn<Wallpaper> wallpaper = Rxn<Wallpaper>();
  final RxBool loading = true.obs;
  final RxnString error = RxnString();
  final RxBool downloading = false.obs;
  final RxBool settingWallpaper = false.obs;

  // Live (video) wallpaper preview — looping + muted via video_player (ExoPlayer).
  VideoPlayerController? videoPlayerController;
  final RxBool videoReady = false.obs;

  late final String id;

  @override
  void onInit() {
    super.onInit();
    id = (Get.arguments as String?) ?? '';
    _load();
  }

  Future<void> _load() async {
    loading.value = true;
    error.value = null;
    try {
      final w = await _repo.wallpaper(id);
      wallpaper.value = w;
      if (w.isVideo && w.fileUrl.isNotEmpty) {
        await _initVideo(w.fileUrl);
      }
    } catch (e) {
      error.value = '$e';
    } finally {
      loading.value = false;
    }
  }

  Future<void> _initVideo(String url) async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      videoPlayerController = c;
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0); // wallpaper preview is silent
      await c.play();
      videoReady.value = true;
    } catch (_) {
      videoReady.value = false;
    }
  }

  Future<void> download() async {
    final w = wallpaper.value;
    if (w == null || downloading.value) return;
    downloading.value = true;
    try {
      final has = await Gal.hasAccess();
      debugPrint('[wp] download start isVideo=${w.isVideo} hasAccess=$has');
      if (!has) {
        final granted = await Gal.requestAccess();
        debugPrint('[wp] requestAccess granted=$granted');
        if (!granted) {
          _snack('Permission needed', 'Allow gallery access to download.');
          return;
        }
      }
      if (w.isVideo) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/${w.id}.mp4';
        await _dio.download(w.fileUrl, path);
        await Gal.putVideo(path, album: 'Mugenstream');
      } else {
        final res = await _dio.get<List<int>>(
          w.fileUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = Uint8List.fromList(res.data ?? const <int>[]);
        debugPrint('[wp] downloaded ${bytes.length} bytes, saving…');
        await Gal.putImageBytes(bytes, album: 'Mugenstream');
      }
      debugPrint('[wp] saved OK');
      _snack('Saved', 'Wallpaper saved to your gallery.');
    } catch (e) {
      debugPrint('[wp] download ERROR: $e');
      _snack('Download failed', '$e');
    } finally {
      downloading.value = false;
    }
  }

  /// Set a video as a looping live wallpaper. The mp4 is downloaded to a stable
  /// app-internal path (the live-wallpaper service re-reads it on every surface
  /// create, so it must persist — not a temp dir), then the system live-
  /// wallpaper preview opens for the user to confirm.
  Future<void> setLiveWallpaper() async {
    final w = wallpaper.value;
    if (w == null || !w.isVideo || settingWallpaper.value) return;
    settingWallpaper.value = true;
    try {
      final dir = await getApplicationSupportDirectory();
      final path = '${dir.path}/live_wallpaper.mp4';
      await _dio.download(w.fileUrl, path);
      debugPrint('[wp] setLiveWallpaper path=$path');
      final ok = await _wallpaperChannel.invokeMethod<bool>(
            'setLiveWallpaper',
            {'path': path},
          ) ??
          false;
      if (!ok) {
        _snack('Failed', 'Could not open the live wallpaper picker.');
      }
      // On success the OS live-wallpaper preview is now open; the user confirms
      // there, so we don't show a "Done" snack here.
    } catch (e) {
      debugPrint('[wp] setLiveWallpaper ERROR: $e');
      _snack('Failed', '$e');
    } finally {
      settingWallpaper.value = false;
    }
  }

  /// which: 0 = home, 1 = lock, 2 = both. (Still images only.)
  Future<void> setAs(int which) async {
    final w = wallpaper.value;
    if (w == null || settingWallpaper.value) return;
    if (w.isVideo) {
      _snack('Not supported', 'Use "Set live" for video wallpapers.');
      return;
    }
    settingWallpaper.value = true;
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/wp_${w.id}.jpg';
      await _dio.download(w.fileUrl, path);
      debugPrint('[wp] setWallpaper which=$which path=$path');
      final ok = await _wallpaperChannel.invokeMethod<bool>(
            'setWallpaper',
            {'path': path, 'which': which},
          ) ??
          false;
      debugPrint('[wp] setWallpaper result=$ok');
      _snack(ok ? 'Done' : 'Failed',
          ok ? 'Wallpaper applied.' : 'Could not set the wallpaper.');
    } catch (e) {
      _snack('Failed', '$e');
    } finally {
      settingWallpaper.value = false;
    }
  }

  void _snack(String title, String msg) => Get.snackbar(
        title,
        msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.surface,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );

  @override
  void onClose() {
    videoPlayerController?.dispose();
    super.onClose();
  }
}

class WallpaperDetailView extends StatelessWidget {
  const WallpaperDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<WallpaperDetailController>();
    return Scaffold(
      body: Obx(() {
        if (c.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final w = c.wallpaper.value;
        if (w == null) {
          return _Error(message: c.error.value ?? 'Not found', onBack: Get.back);
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            if (w.isVideo)
              (c.videoReady.value && c.videoPlayerController != null)
                  ? FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: c.videoPlayerController!.value.size.width,
                        height: c.videoPlayerController!.value.size.height,
                        child: VideoPlayer(c.videoPlayerController!),
                      ),
                    )
                  : Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    )
            else
              InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: w.fileUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white38)),
                ),
              ),
            // Back button
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  onPressed: Get.back,
                ),
              ),
            ),
            // Action bar
            Align(
              alignment: Alignment.bottomCenter,
              child: _ActionBar(controller: c, wallpaper: w),
            ),
          ],
        );
      }),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final WallpaperDetailController controller;
  final Wallpaper wallpaper;
  const _ActionBar({required this.controller, required this.wallpaper});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(wallpaper.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Obx(() => FilledButton.icon(
                      onPressed: controller.downloading.value
                          ? null
                          : controller.download,
                      icon: controller.downloading.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: const Text('Download'),
                    )),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Obx(() => FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary),
                      onPressed: controller.settingWallpaper.value
                          ? null
                          : () => wallpaper.isVideo
                              ? controller.setLiveWallpaper()
                              : _chooseTarget(context),
                      icon: controller.settingWallpaper.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(wallpaper.isVideo
                              ? Icons.video_settings
                              : Icons.wallpaper),
                      label: Text(wallpaper.isVideo ? 'Set live' : 'Set'),
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _chooseTarget(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home screen'),
              onTap: () {
                Get.back();
                controller.setAs(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Lock screen'),
              onTap: () {
                Get.back();
                controller.setAs(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.smartphone),
              title: const Text('Both screens'),
              onTap: () {
                Get.back();
                controller.setAs(2);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  const _Error({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 12),
            FilledButton(onPressed: onBack, child: const Text('Go back')),
          ],
        ),
      ),
    );
  }
}

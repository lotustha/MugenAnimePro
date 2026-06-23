import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../widgets/state_views.dart';
import 'player_controller.dart';

class PlayerView extends GetView<PlayerController> {
  const PlayerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video surface with media_kit's adaptive controls.
            Positioned.fill(
              child: Video(
                controller: controller.videoController,
                controls: AdaptiveVideoControls,
              ),
            ),

            // Loading / error overlays.
            Obx(() {
              if (controller.error.value != null) {
                return Container(
                  color: Colors.black87,
                  child: ErrorRetryView(
                    message: controller.error.value!,
                    onRetry: controller.retry,
                  ),
                );
              }
              if (controller.loading.value) {
                return Container(
                  color: Colors.black45,
                  child: const LoadingView(),
                );
              }
              return const SizedBox.shrink();
            }),

            // Top bar: back + title.
            Positioned(
              top: 4,
              left: 4,
              right: 4,
              child: Obx(() {
                final ep = controller.current.value;
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: Get.back,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            controller.anime.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                            ),
                          ),
                          if (ep != null)
                            Text(
                              'E${ep.number} • ${controller.serverName.value}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),

            // Skip intro/outro button.
            Positioned(
              right: 20,
              bottom: 90,
              child: Obx(() {
                if (!controller.canSkip.value) return const SizedBox.shrink();
                return FilledButton.icon(
                  onPressed: controller.skipSegment,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Skip'),
                );
              }),
            ),

            // Previous / Next episode controls.
            Positioned(
              left: 20,
              bottom: 90,
              child: Obx(() {
                controller.current.value; // react to episode change
                return Row(
                  children: [
                    if (controller.hasPrevious)
                      _miniBtn(Icons.skip_previous, controller.playPrevious),
                    if (controller.hasNext) ...[
                      const SizedBox(width: 8),
                      _miniBtn(Icons.skip_next_outlined, controller.playNext,
                          label: 'Next'),
                    ],
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, VoidCallback onTap, {String? label}) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: label != null ? 12 : 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(color: Colors.white)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

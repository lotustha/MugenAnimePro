import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models/spotlight_item.dart';
import '../../../widgets/poster_image.dart';

/// Auto-advancing hero carousel for the home screen.
class SpotlightCarousel extends StatefulWidget {
  final List<SpotlightItem> items;
  final void Function(SpotlightItem) onTap;

  const SpotlightCarousel({super.key, required this.items, required this.onTap});

  @override
  State<SpotlightCarousel> createState() => _SpotlightCarouselState();
}

class _SpotlightCarouselState extends State<SpotlightCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!mounted || !_controller.hasClients) return;
        _page = (_page + 1) % widget.items.length;
        _controller.animateToPage(
          _page,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scale the hero with width so it isn't a wide, short band on tablets.
    // Phones keep ~260; wide screens get a taller, more intentional hero.
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.32).clamp(260.0, 360.0);
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (ctx, i) => _slide(ctx, widget.items[i]),
          ),
          Positioned(
            bottom: 12,
            left: 16,
            child: Row(
              children: List.generate(
                widget.items.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(right: 5),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? Colors.white : Colors.white38,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slide(BuildContext context, SpotlightItem item) {
    return GestureDetector(
      onTap: () => widget.onTap(item),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Banner fills the carousel width; size the decode to the screen so a
          // ~1280px source isn't kept full-res in memory for every adjacent page.
          PosterImage(url: item.banner, width: MediaQuery.sizeOf(context).width),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.95),
                ],
                stops: const [0.3, 0.7, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (item.type.isNotEmpty) _chip(item.type),
                    if (item.quality.isNotEmpty) _chip(item.quality),
                    if (item.sub > 0) _chip('SUB ${item.sub}'),
                    if (item.dub > 0) _chip('DUB ${item.dub}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11)),
      );
}

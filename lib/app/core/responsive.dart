import 'package:flutter/widgets.dart';

/// Screen-class helpers. A device is treated as a "tablet" once its shortest
/// side is ≥ 600dp (the platform breakpoint). Gating tablet styling on the
/// *shortest* side means it's stable across rotation — a phone never flips into
/// tablet mode in landscape, so layouts that must not remount (the player) stay
/// put.
extension Responsive on BuildContext {
  // Named to avoid clashing with GetX's width-based `context.isTablet` (which
  // wrongly flips true for a phone in landscape). This one is shortest-side
  // based, so it's stable across rotation.
  bool get isTabletLayout => MediaQuery.sizeOf(this).shortestSide >= 600;
}

/// Centres its child and caps the content width on large screens. A no-op on
/// phones (where the screen is narrower than [maxWidth]), so phone layouts are
/// untouched; on tablets it stops content from stretching edge-to-edge.
class MaxWidthBox extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  const MaxWidthBox({super.key, this.maxWidth = 720, required this.child});

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../utils/route_path.dart';
import 'base/polyline_animator.dart';

/// A light that travels along the route, over a dimmed copy of it. Good for a
/// "looking for a driver" wait.
///
/// It draws two polylines: the polyline itself, dimmed, and the glow on top,
/// with the ID `<id>#glow`. Google Maps has no real glow: it is a lighter and
/// wider stretch of the line.
///
/// The glow is measured in distance, so it keeps the same length on the map
/// wherever the points of the route are denser or sparser.
class PulseAnimator extends PolylineAnimator {
  /// Creates a pulse. [glowLength] is a fraction of the route, from more than 0
  /// up to 1.
  const PulseAnimator({
    this.glowLength = 0.15,
    this.glowColor,
    this.baseOpacity = 0.35,
    this.glowWidthExtra = 2,
    super.duration = const Duration(milliseconds: 1800),
    super.curve = Curves.linear,
    super.repeat = true,
    super.repeatCount,
    super.reverse,
    super.delayStart,
    super.delayEnd,
  })  : assert(glowLength > 0 && glowLength <= 1, 'glowLength is in (0, 1]'),
        assert(
            baseOpacity >= 0 && baseOpacity <= 1, 'baseOpacity is in [0, 1]');

  /// Length of the glow as a fraction of the route.
  final double glowLength;

  /// Color of the glow. If null it is a lighter version of the polyline color.
  final Color? glowColor;

  /// Opacity of the dimmed polyline under the glow, from 0 to 1.
  final double baseOpacity;

  /// How much wider than the polyline the glow is, in logical pixels.
  final int glowWidthExtra;

  /// The dimmed polyline, without the glow.
  @override
  Polyline animate(Polyline polyline, double progress) => polyline.copyWith(
        colorParam: polyline.color.withAlpha((baseOpacity * 255).round()),
      );

  @override
  List<Polyline> animateAll(Polyline polyline, double progress) {
    final base = animate(polyline, progress);
    final path = RoutePath.of(polyline.points);
    if (path == null) return [base];

    // The glow enters at the start, crosses the route and leaves at the end.
    final head = (progress.clamp(0.0, 1.0) * (1 + glowLength)).clamp(0.0, 1.0);
    final tail = (progress.clamp(0.0, 1.0) * (1 + glowLength) - glowLength)
        .clamp(0.0, 1.0);
    final points = path.slice(tail * path.length, head * path.length);
    if (points.length < 2) return [base];

    return [
      base,
      Polyline(
        polylineId: PolylineId('${polyline.polylineId.value}#glow'),
        points: points,
        color: glowColor ?? Color.lerp(polyline.color, Colors.white, 0.55)!,
        width: polyline.width + glowWidthExtra,
        zIndex: polyline.zIndex + 1,
        startCap: polyline.startCap,
        endCap: polyline.endCap,
        jointType: polyline.jointType,
      ),
    ];
  }

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is PulseAnimator &&
      glowLength == other.glowLength &&
      glowColor == other.glowColor &&
      baseOpacity == other.baseOpacity &&
      glowWidthExtra == other.glowWidthExtra;

  @override
  int get hashCode => Object.hash(
        super.hashCode,
        glowLength,
        glowColor,
        baseOpacity,
        glowWidthExtra,
      );
}

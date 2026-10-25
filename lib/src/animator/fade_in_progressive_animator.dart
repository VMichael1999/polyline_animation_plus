// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/src/animator/base/polyline_animator.dart';

/// Fades the polyline in during the first 30% of the animation and then
/// erases it from its start to its end during the remaining 70%.
class FadeInProgressiveAnimator extends PolylineAnimator {
  /// Creates a fade-in animator that repeats by default.
  const FadeInProgressiveAnimator({
    super.duration = const Duration(seconds: 5),
    super.curve = Curves.ease,
    super.repeat = true,
    super.repeatCount,
    super.reverse,
    super.delayStart,
    super.delayEnd,
  });

  @override
  Polyline animate(Polyline polyline, double progress) {
    if (progress <= 0.3) {
      return polyline.copyWith(
        colorParam: polyline.color.withAlpha(
          (progress / 0.3 * 255).round().clamp(0, 255),
        ),
      );
    } else {
      final animationProgress = (progress - 0.3) / 0.7;
      final startIndex = (polyline.points.length * animationProgress).round();
      final points = polyline.points.skip(startIndex).toList();
      return polyline.copyWith(pointsParam: points);
    }
  }
}

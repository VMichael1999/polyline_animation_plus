// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/src/animator/base/polyline_animator.dart';

class FadeInProgressiveAnimator extends PolylineAnimator {
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
        colorParam: polyline.color.withValues(alpha: progress / 0.3),
      );
    } else {
      final animationProgress = (progress - 0.3) / 0.7;
      final startIndex = (polyline.points.length * animationProgress).round();
      final points = polyline.points.skip(startIndex).toList();
      return polyline.copyWith(pointsParam: points);
    }
  }
}

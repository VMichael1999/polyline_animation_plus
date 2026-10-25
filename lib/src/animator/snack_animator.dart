// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/src/animator/base/polyline_animator.dart';

/// Draws the polyline from its start to its end during the first half of the
/// animation and erases it in the same direction during the second half, like
/// a snake crossing the route.
class SnackAnimator extends PolylineAnimator {
  /// Creates a snake-like animator that plays once by default.
  const SnackAnimator({
    super.duration = const Duration(seconds: 2),
    super.curve = Curves.easeInOut,
    super.repeat = false,
    super.repeatCount,
    super.reverse = false,
    super.delayStart,
    super.delayEnd,
  });

  @override
  Polyline animate(Polyline polyline, double progress) {
    final points = polyline.points;

    List<LatLng> visiblePoints;

    if (progress <= 0.5) {
      final index = (points.length * progress * 2).round();
      visiblePoints = points.take(index).toList();
    } else {
      final eraseProgress = (progress - 0.5) * 2;
      final startIndex = (points.length * eraseProgress).round();
      visiblePoints = points.skip(startIndex).toList();
    }

    return polyline.copyWith(pointsParam: visiblePoints);
  }
}

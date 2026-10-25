// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/src/animator/base/polyline_animator.dart';

/// Changes the color of the polyline smoothly through [colors], one after
/// the other, and back to the first one.
///
/// The points are not modified. If [colors] is empty the polyline is left
/// unchanged.
class ColorTransitionAnimation extends PolylineAnimator {
  /// Colors the polyline goes through, in order.
  final List<Color> colors;

  /// Creates a color transition through [colors].
  const ColorTransitionAnimation({
    required this.colors,
    super.duration = const Duration(seconds: 5),
    super.curve = Curves.linear,
    super.repeat = false,
    super.repeatCount,
    super.reverse,
    super.delayStart,
    super.delayEnd,
  });

  @override
  Polyline animate(Polyline polyline, double progress) {
    final totalColors = colors.length;
    if (totalColors == 0) return polyline;

    // The last stretch blends back to the first color, so a repeating
    // animation starts again without a jump.
    final scaled = progress.clamp(0.0, 1.0) * totalColors;
    final colorIndex = math.min(scaled.floor(), totalColors - 1);
    final nextColorIndex = (colorIndex + 1) % totalColors;
    final colorProgress = scaled - colorIndex;

    final interpolatedColor = Color.lerp(
      colors[colorIndex],
      colors[nextColorIndex],
      colorProgress,
    );

    return polyline.copyWith(colorParam: interpolatedColor);
  }

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is ColorTransitionAnimation &&
      listEquals(colors, other.colors);

  @override
  int get hashCode => Object.hash(super.hashCode, Object.hashAll(colors));
}

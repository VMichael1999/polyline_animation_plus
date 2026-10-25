// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/src/animator/base/polyline_animator.dart';

class ColorTransitionAnimation extends PolylineAnimator {
  final List<Color> colors;

  const ColorTransitionAnimation({
    required this.colors,
    super.duration = const Duration(seconds: 5),
    super.curve = Curves.linear,
    super.repeat = false,
  });

  @override
  Polyline animate(Polyline polyline, double progress) {
    final totalColors = colors.length;
    final colorIndex = (progress * totalColors).floor() % totalColors;
    final nextColorIndex = (colorIndex + 1) % totalColors;

    final colorProgress = (progress * totalColors) - colorIndex;

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

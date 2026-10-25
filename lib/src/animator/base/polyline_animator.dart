// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// This abstract class defines the properties needed to animate a polyline
/// on a Google Map
abstract class PolylineAnimator {
  final Duration duration;
  final Curve curve;
  final bool repeat;
  final bool reverse;

  /// Delay before the animation starts
  /// This is usefull for repeating animations where you want to wait before starting the next cycle
  final Duration delayStart;

  /// Delay after the animation ends
  /// This is useful for repeating animations where you want to wait before starting the next cycle
  final Duration delayEnd;

  /// Number of times to repeat the animation (null means infinite)
  final int? repeatCount;

  const PolylineAnimator({
    required this.duration,
    this.curve = Curves.linear,
    this.repeat = false,
    this.repeatCount,
    this.reverse = false,
    this.delayStart = Duration.zero,
    this.delayEnd = Duration.zero,
  });

  Polyline animate(Polyline polyline, double progress);

  /// Called once when the animation reaches its end.
  ///
  /// It is not called when the animation is disposed or removed before it
  /// finishes, nor for animations that repeat forever, because they never end.
  void onAnimationStop() {}

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other.runtimeType != runtimeType) {
      return false;
    }

    return other is PolylineAnimator &&
        duration == other.duration &&
        curve == other.curve &&
        repeat == other.repeat &&
        repeatCount == other.repeatCount &&
        reverse == other.reverse &&
        delayStart == other.delayStart &&
        delayEnd == other.delayEnd;
  }

  @override
  int get hashCode => Object.hash(
        duration,
        curve,
        repeat,
        repeatCount,
        reverse,
        delayStart,
        delayEnd,
      );

  @override
  String toString() {
    return 'PolylineAnimator(duration: $duration, curve: $curve, repeat: $repeat, repeatCount: $repeatCount,'
        'reverse: $reverse, delayStart: $delayStart, delayEnd: $delayEnd)';
  }
}

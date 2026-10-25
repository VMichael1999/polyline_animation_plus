// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// Describes how a polyline is animated on a Google Map.
///
/// Extend it and implement [animate] to create your own animation. The
/// controller calls [animate] on every frame with the original polyline and
/// the current progress, and draws the polyline it returns.
abstract class PolylineAnimator {
  /// Time the animation takes to go from progress 0 to 1, without the delays.
  final Duration duration;

  /// Curve applied to the progress passed to [animate].
  final Curve curve;

  /// Whether the animation starts again when it ends.
  final bool repeat;

  /// When repeating, whether the animation plays backwards on every other
  /// cycle instead of jumping back to the start.
  final bool reverse;

  /// Time to wait, with the progress at 0, before each cycle starts drawing.
  ///
  /// It is added to [duration], it does not shorten it.
  final Duration delayStart;

  /// Time to wait, with the progress at 1, after each cycle finishes drawing.
  ///
  /// It is added to [duration], it does not shorten it.
  final Duration delayEnd;

  /// Number of cycles to play when [repeat] is true. `null` means forever.
  final int? repeatCount;

  /// Creates an animator. Subclasses pass their own defaults.
  const PolylineAnimator({
    required this.duration,
    this.curve = Curves.linear,
    this.repeat = false,
    this.repeatCount,
    this.reverse = false,
    this.delayStart = Duration.zero,
    this.delayEnd = Duration.zero,
  });

  /// Returns the polyline to draw for the given [progress], between 0 and 1.
  ///
  /// [polyline] is always the original polyline, not the previous frame.
  Polyline animate(Polyline polyline, double progress);

  /// Returns every polyline to draw for the given [progress].
  ///
  /// By default it is just the polyline of [animate]. Override it for an
  /// animation made of several polylines, for example a base line and a glow
  /// on top. The extra polylines need IDs different from [polyline] (use
  /// `'${polyline.polylineId.value}#name'`): they are removed together with
  /// the animated polyline, and are not available to the app.
  List<Polyline> animateAll(Polyline polyline, double progress) => [
        animate(polyline, progress),
      ];

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

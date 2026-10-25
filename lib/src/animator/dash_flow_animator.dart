import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../utils/route_path.dart';
import 'base/polyline_animator.dart';

/// A dashed line whose dashes flow along the route. Good for a walking route
/// or the stretch "on the way to pick you up".
///
/// The dash pattern of Google Maps cannot be moved, so the movement is
/// simulated: the start of the line is cut a little more on every frame, and as
/// the pattern always starts at the first point, the dashes seem to advance.
/// The cut goes from 0 up to one `dash + gap` and starts again, which looks the
/// same, so the animation loops without a jump.
///
/// **Limitation.** `dash` and `gap` are drawn in logical pixels (that is what
/// Google Maps patterns use) but the cut is measured in meters, so the loop is
/// only smooth at the zoom level where one meter is about one pixel (around
/// zoom 17). At other zoom levels the dashes may jump when the cut starts
/// again. It has not been checked that the pattern stays anchored to the first
/// point on both Android and iOS.
class DashFlowAnimator extends PolylineAnimator {
  /// Creates a flowing dash animator.
  ///
  /// The dashes move about [speed] meters per second. Every cycle of [duration]
  /// they move a whole number of `dash + gap` (at least one), so the speed is
  /// rounded to fit: with the default one second cycle, 10 + 10 and a speed of
  /// 30 they move 40 meters per second.
  const DashFlowAnimator({
    this.dash = 10,
    this.gap = 10,
    this.speed = 30,
    super.duration = const Duration(seconds: 1),
    super.curve = Curves.linear,
    super.repeat = true,
    super.repeatCount,
    super.reverse,
    super.delayStart,
    super.delayEnd,
  })  : assert(dash > 0 && gap > 0, 'dash and gap must be positive'),
        assert(speed > 0, 'speed must be positive');

  /// Length of each dash, in logical pixels and meters (see the limitation).
  final double dash;

  /// Length of each gap, in logical pixels and meters (see the limitation).
  final double gap;

  /// How fast the dashes move, in meters per second.
  final double speed;

  @override
  Polyline animate(Polyline polyline, double progress) {
    final dashed = polyline.copyWith(
      patternsParam: [
        PatternItem.dash(dash.toDouble()),
        PatternItem.gap(gap.toDouble())
      ],
    );

    final path = RoutePath.of(polyline.points);
    if (path == null) return dashed;

    final period = dash + gap;
    final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
    final periodsPerCycle = math.max(1, (speed * seconds / period).round());
    final turns = progress.clamp(0.0, 1.0) * periodsPerCycle;
    // Only the part of a period matters: whole periods look the same.
    final offset = (turns - turns.floorToDouble()) * period;
    final points = path.slice(offset, path.length);
    // A route shorter than one dash and gap cannot be cut.
    if (points.length < 2) return dashed;

    return dashed.copyWith(pointsParam: points);
  }

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is DashFlowAnimator &&
      dash == other.dash &&
      gap == other.gap &&
      speed == other.speed;

  @override
  int get hashCode => Object.hash(super.hashCode, dash, gap, speed);
}

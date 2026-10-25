// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.

import 'dart:ui' show Color;

import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/src/animator/base/polyline_animator.dart';
import 'package:polyline_animation_plus/src/animator/segmented_animator.dart';
import 'package:polyline_animation_plus/src/model/route_segment.dart';

/// A polyline together with the animation that draws it.
class AnimatedPolyline {
  /// The polyline to draw. Its points and style are the final state.
  final Polyline polyline;

  /// How the polyline is animated. If null, the polyline is static and is
  /// drawn as it is.
  final PolylineAnimator? polylineAnimator;

  /// Creates an animated polyline, or a static one when no animator is given.
  const AnimatedPolyline({required this.polyline, this.polylineAnimator});

  /// A route drawn in several colors, for example by traffic or type of road.
  ///
  /// Every [RouteSegment] is a polyline of its own with the ID `<id>#<n>`,
  /// where `n` is its position in [segments]. The ID [id] itself is not drawn,
  /// and none of these IDs should be used for other polylines. Consecutive
  /// segments share the point where they meet, so there is no gap.
  ///
  /// [polylineAnimator] is applied to the whole route as if it were a single
  /// line: with a progressive animator the line is drawn or erased across the
  /// segments. Only the part of the route it leaves visible, and its opacity
  /// for fades, are used; the colors come from the segments. Without an
  /// animator the route is drawn at once.
  ///
  /// The parts of the route that no segment covers are not drawn. [width] is
  /// the width of every segment.
  factory AnimatedPolyline.segmented({
    required PolylineId id,
    required List<LatLng> points,
    required List<RouteSegment> segments,
    PolylineAnimator? polylineAnimator,
    int width = 5,
  }) {
    if (segments.isEmpty) {
      throw ArgumentError.value(segments, 'segments', 'Must not be empty');
    }

    return AnimatedPolyline(
      polyline: Polyline(
        polylineId: id,
        points: points,
        width: width,
        color: const Color(0xFF000000),
      ),
      polylineAnimator: SegmentedAnimator(
        segments: List.unmodifiable(segments),
        inner: polylineAnimator,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    return other is AnimatedPolyline &&
        polyline == other.polyline &&
        polylineAnimator == other.polylineAnimator;
  }

  @override
  int get hashCode => polyline.polylineId.hashCode;

  @override
  String toString() {
    return 'AnimatedPolyline{polyline: $polyline, polylineAnimator: $polylineAnimator}';
  }
}

// Internal, not exported: public API docs are only required for exported code.
// ignore_for_file: public_member_api_docs
// `Color.alpha` is deprecated on new Flutter, but `Color.a` does not exist on
// the oldest supported version.
// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../model/route_segment.dart';
import '../utils/route_path.dart';
import 'base/polyline_animator.dart';

/// Draws a route in several colors, one polyline per segment (`<id>#<n>`),
/// and animates it as if it were a single line.
///
/// The [inner] animator decides what part of the route is visible (and how
/// opaque it is), and this one splits that part among the segments. Without an
/// inner animator the whole route is drawn at once.
class SegmentedAnimator extends PolylineAnimator {
  SegmentedAnimator({required this.segments, this.inner})
      : super(
          duration: inner?.duration ?? Duration.zero,
          curve: inner?.curve ?? Curves.linear,
          repeat: inner?.repeat ?? false,
          repeatCount: inner?.repeatCount,
          reverse: inner?.reverse ?? false,
          delayStart: inner?.delayStart ?? Duration.zero,
          delayEnd: inner?.delayEnd ?? Duration.zero,
        );

  final List<RouteSegment> segments;
  final PolylineAnimator? inner;

  @override
  Polyline animate(Polyline polyline, double progress) =>
      inner?.animate(polyline, progress) ?? polyline;

  @override
  void onAnimationStop() => inner?.onAnimationStop();

  @override
  List<Polyline> animateAll(Polyline polyline, double progress) {
    final visible = animate(polyline, progress);
    final path = RoutePath.of(polyline.points);
    if (path == null) return [visible];
    if (visible.points.length < 2) return const [];

    final visibleFrom = _alongOf(path, visible.points.first);
    final visibleTo = _alongOf(path, visible.points.last);

    // Keep the opacity the inner animator gave to the line, for fades.
    final baseAlpha = polyline.color.alpha;
    final opacity = baseAlpha == 0 ? 1.0 : visible.color.alpha / baseAlpha;

    final result = <Polyline>[];
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final from = segment.from * path.length > visibleFrom
          ? segment.from * path.length
          : visibleFrom;
      final to = segment.to * path.length < visibleTo
          ? segment.to * path.length
          : visibleTo;
      if (to - from <= 1e-6) continue;

      result.add(
        Polyline(
          polylineId: PolylineId('${polyline.polylineId.value}#$i'),
          points: path.slice(from, to),
          color: segment.color.withAlpha(
            (segment.color.alpha * opacity).round().clamp(0, 255),
          ),
          width: polyline.width,
          zIndex: polyline.zIndex,
          startCap: polyline.startCap,
          endCap: polyline.endCap,
          jointType: polyline.jointType,
        ),
      );
    }
    return result;
  }

  /// Distance along the route of a point of it. The animators cut the line at
  /// its points, so it is found exactly; otherwise the closest one is used.
  static double _alongOf(RoutePath path, LatLng point) {
    final index = path.points.indexOf(point);
    if (index >= 0) return path.alongAtVertex(index);
    return path.nearest(point)!.along;
  }

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is SegmentedAnimator &&
      other.inner == inner &&
      listEquals(other.segments, segments);

  @override
  int get hashCode =>
      Object.hash(super.hashCode, inner, Object.hashAll(segments));
}

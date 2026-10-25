// Internal, not exported: public API docs are only required for exported code.
// ignore_for_file: public_member_api_docs

import 'dart:math' as math;

import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'spherical_util.dart';

/// The result of putting a position on a [RoutePath].
class RouteProjection {
  const RouteProjection({
    required this.point,
    required this.along,
    required this.distance,
    required this.segment,
  });

  /// The closest point of the route.
  final LatLng point;

  /// Meters from the start of the route to [point].
  final double along;

  /// Meters from the original position to [point].
  final double distance;

  /// Index of the segment [point] is on.
  final int segment;
}

/// A route with its cumulative distances, to find positions on it by distance.
class RoutePath {
  /// Creates a path. Consecutive equal points are dropped because they would
  /// make segments without length.
  factory RoutePath(List<LatLng> route) {
    final points = <LatLng>[];
    for (final point in route) {
      if (points.isEmpty || points.last != point) points.add(point);
    }
    if (points.length < 2) {
      throw ArgumentError.value(
        route,
        'route',
        'A route needs at least two different points',
      );
    }

    final cumulative = <double>[0];
    for (var i = 1; i < points.length; i++) {
      cumulative.add(
        cumulative.last +
            SphericalUtil.computeDistanceBetween(points[i - 1], points[i])
                .toDouble(),
      );
    }
    return RoutePath._(points, cumulative);
  }

  RoutePath._(this.points, this._cumulative);

  static final Expando<RoutePath> _cache = Expando('RoutePath');

  /// The path of [points], or `null` if they do not have two different points.
  ///
  /// It is remembered for the same list, so an animation that needs it on every
  /// frame does not measure the route again. Do not change the list afterwards.
  static RoutePath? of(List<LatLng> points) {
    final cached = _cache[points];
    if (cached != null) return cached;
    try {
      return _cache[points] = RoutePath(points);
    } on ArgumentError {
      return null;
    }
  }

  final List<LatLng> points;
  final List<double> _cumulative;

  /// Total length in meters.
  double get length => _cumulative.last;

  int get segments => points.length - 1;

  /// Meters from the start of the route to its [index]th point.
  double alongAtVertex(int index) => _cumulative[index];

  /// Index of the segment that contains [along] (clamped to the route).
  int segmentAt(double along) {
    if (along <= 0) return 0;
    if (along >= length) return segments - 1;

    var low = 0;
    var high = segments - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (_cumulative[mid] <= along) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  /// The point [along] meters from the start.
  LatLng pointAt(double along) {
    final clamped = along.clamp(0.0, length);
    final segment = segmentAt(clamped);
    final segmentLength = _cumulative[segment + 1] - _cumulative[segment];
    final fraction = (clamped - _cumulative[segment]) / segmentLength;
    if (fraction <= 0) return points[segment];
    if (fraction >= 1) return points[segment + 1];
    return SphericalUtil.interpolate(
      points[segment],
      points[segment + 1],
      fraction,
    );
  }

  /// Heading in degrees of the route at [along].
  double headingAt(double along) {
    final segment = segmentAt(along);
    return SphericalUtil.computeHeading(
      points[segment],
      points[segment + 1],
    ).toDouble();
  }

  /// The points of the route between [from] and [to] meters, including the
  /// exact start and end.
  List<LatLng> slice(double from, double to) {
    final start = from.clamp(0.0, length);
    final end = to.clamp(start, length);

    final result = <LatLng>[pointAt(start)];
    final first = segmentAt(start) + 1;
    for (var i = first; i < points.length && _cumulative[i] < end; i++) {
      if (_cumulative[i] > start) result.add(points[i]);
    }
    final last = pointAt(end);
    if (result.last != last) result.add(last);
    return result;
  }

  /// The closest point of the route to [position].
  ///
  /// With [from], only segments within [behind] meters before and [ahead]
  /// meters after that distance along the route are considered. Returns `null`
  /// when there is no segment in that range.
  RouteProjection? nearest(
    LatLng position, {
    double? from,
    double behind = 0,
    double ahead = 0,
  }) {
    var firstSegment = 0;
    var lastSegment = segments - 1;
    if (from != null) {
      firstSegment = segmentAt(from - behind);
      lastSegment = segmentAt(from + ahead);
    }

    RouteProjection? best;
    for (var i = firstSegment; i <= lastSegment; i++) {
      final candidate = _project(position, i);
      if (best == null || _isBetter(candidate, best, from)) best = candidate;
    }
    return best;
  }

  /// Prefers the closest one. When two are about as close (the route passes
  /// twice through the same place) it prefers the one nearer to [from].
  static bool _isBetter(
    RouteProjection candidate,
    RouteProjection best,
    double? from,
  ) {
    if (from != null && (candidate.distance - best.distance).abs() < 1.0) {
      return (candidate.along - from).abs() < (best.along - from).abs();
    }
    return candidate.distance < best.distance;
  }

  RouteProjection _project(LatLng position, int segment) {
    final a = points[segment];
    final b = points[segment + 1];

    // Flat approximation around the segment: fine for segments of a few
    // kilometers at most.
    final scale = math.cos(a.latitude * math.pi / 180);
    final abx = (b.longitude - a.longitude) * scale;
    final aby = b.latitude - a.latitude;
    final apx = (position.longitude - a.longitude) * scale;
    final apy = position.latitude - a.latitude;

    final squared = abx * abx + aby * aby;
    final t = squared == 0
        ? 0.0
        : ((apx * abx + apy * aby) / squared).clamp(0.0, 1.0);

    final point = t <= 0
        ? a
        : t >= 1
            ? b
            : LatLng(
                a.latitude + (b.latitude - a.latitude) * t,
                a.longitude + (b.longitude - a.longitude) * t,
              );

    final segmentLength = _cumulative[segment + 1] - _cumulative[segment];
    return RouteProjection(
      point: point,
      along: _cumulative[segment] + t * segmentLength,
      distance:
          SphericalUtil.computeDistanceBetween(position, point).toDouble(),
      segment: segment,
    );
  }
}

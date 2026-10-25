import 'dart:ui' show Color;

/// A stretch of a route with its own color, for `AnimatedPolyline.segmented`.
///
/// [from] and [to] are fractions of the length of the route, measured in
/// distance: 0 is the start and 1 is the end.
final class RouteSegment {
  /// Creates a segment. [from] must be at least 0, [to] at most 1 and [from]
  /// less than [to].
  const RouteSegment({
    required this.from,
    required this.to,
    required this.color,
  }) : assert(from >= 0 && to <= 1 && from < to, 'Needs 0 <= from < to <= 1');

  /// Where the segment starts, as a fraction of the route.
  final double from;

  /// Where the segment ends, as a fraction of the route.
  final double to;

  /// Color of the segment.
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is RouteSegment &&
      other.from == from &&
      other.to == to &&
      other.color == color;

  @override
  int get hashCode => Object.hash(from, to, color);

  @override
  String toString() => 'RouteSegment($from to $to, $color)';
}

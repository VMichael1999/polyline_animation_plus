import 'dart:ui' show Color;

import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// How a part of a tracked route is drawn.
final class RouteStyle {
  /// Creates a style. The route is not drawn at all when [visible] is false.
  const RouteStyle({required this.color, this.width = 5, this.visible = true});

  /// Color of the line.
  final Color color;

  /// Width of the line in logical pixels.
  final int width;

  /// Whether the line is drawn.
  final bool visible;

  @override
  bool operator ==(Object other) =>
      other is RouteStyle &&
      other.color == color &&
      other.width == width &&
      other.visible == visible;

  @override
  int get hashCode => Object.hash(color, width, visible);

  @override
  String toString() =>
      'RouteStyle(color: $color, width: $width, visible: $visible)';
}

/// A vehicle that follows a route, for `MapAnimationController.trackVehicle`.
///
/// The position the GPS reports is put on the route, so the marker does not
/// wander off the road. The part of the route already travelled is drawn with
/// [traveled] and the rest with [remaining].
///
/// The two lines are polylines with the IDs `<markerId>#traveled` and
/// `<markerId>#remaining`. Do not use those IDs for other polylines.
final class VehicleTracking {
  /// Creates the tracking of the vehicle whose marker is [markerId].
  ///
  /// [route] needs at least two different points.
  const VehicleTracking({
    required this.markerId,
    required this.route,
    this.traveled = const RouteStyle(color: Color(0xFF9E9E9E)),
    this.remaining = const RouteStyle(color: Color(0xFF1565C0)),
    this.snapToleranceMeters = 30,
    this.followRoute = false,
    this.consumeRoute = true,
    this.onOffRoute,
  });

  /// The marker of the vehicle. It is created at the start of the route if it
  /// does not exist yet.
  final MarkerId markerId;

  /// The route to follow, in order.
  final List<LatLng> route;

  /// Style of the part of the route already travelled. Ignored when
  /// [consumeRoute] is false.
  final RouteStyle traveled;

  /// Style of the part of the route still to travel. When [consumeRoute] is
  /// false it is used for the whole route.
  final RouteStyle remaining;

  /// How far from the route, in meters, a position can be and still be put on
  /// it. Farther positions are off route.
  final double snapToleranceMeters;

  /// Whether the marker follows the route between two positions, turning at
  /// the corners, instead of going in a straight line.
  final bool followRoute;

  /// Whether the travelled part is drawn with [traveled] (or hidden) and the
  /// rest with [remaining]. When false the whole route keeps one style.
  final bool consumeRoute;

  /// Called with the position that is farther than [snapToleranceMeters] from
  /// the route, so the app can ask for a new one. The marker goes to that
  /// position as it is.
  final void Function(LatLng position)? onOffRoute;
}

// Internal, not exported: public API docs are only required for exported code.
// ignore_for_file: public_member_api_docs

import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../utils/route_path.dart';

/// Where a reported position ended up.
class VehicleFix {
  const VehicleFix({
    required this.position,
    required this.along,
    required this.onRoute,
  });

  /// The position to show: on the route when [onRoute], otherwise the one that
  /// was reported.
  final LatLng position;

  /// Meters travelled along the route, or `null` if no position has been on
  /// the route yet.
  final double? along;

  final bool onRoute;
}

/// Puts the positions of a vehicle on its route.
///
/// It looks first around the last known distance, so a route that crosses
/// itself or runs along a parallel street does not make the vehicle jump. Only
/// if nothing is within the tolerance there does it search the whole route.
class VehicleTracker {
  VehicleTracker(this.path, {required this.toleranceMeters});

  final RoutePath path;
  final double toleranceMeters;

  /// Meters before the last distance that are searched first.
  double get behindMeters =>
      toleranceMeters * 2 < 100 ? 100 : toleranceMeters * 2;

  /// Meters after the last distance that are searched first.
  static const double aheadMeters = 1000;

  double? _along;

  /// Meters travelled at the last position that was on the route.
  double? get along => _along;

  VehicleFix update(LatLng position) {
    RouteProjection? best;
    final last = _along;
    if (last != null) {
      best = path.nearest(
        position,
        from: last,
        behind: behindMeters,
        ahead: aheadMeters,
      );
    }
    if (best == null || best.distance > toleranceMeters) {
      // Nothing close by: search the whole route.
      best = path.nearest(
        position,
        from: last,
        behind: path.length,
        ahead: path.length,
      );
    }

    if (best != null && best.distance <= toleranceMeters) {
      _along = best.along;
      return VehicleFix(position: best.point, along: best.along, onRoute: true);
    }
    return VehicleFix(position: position, along: _along, onRoute: false);
  }
}

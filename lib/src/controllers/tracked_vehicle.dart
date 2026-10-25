// Internal, not exported: public API docs are only required for exported code.
// ignore_for_file: public_member_api_docs

import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../model/vehicle_tracking.dart';
import '../utils/route_path.dart';
import 'vehicle_tracker.dart';

/// The state of one tracked vehicle: its route, where it is on it and what is
/// drawn.
class TrackedVehicle {
  TrackedVehicle(this.tracking, this.baseMarker)
      : path = RoutePath(tracking.route) {
    tracker = VehicleTracker(
      path,
      toleranceMeters: tracking.snapToleranceMeters,
    );
  }

  final VehicleTracking tracking;
  final RoutePath path;
  late final VehicleTracker tracker;

  /// The marker with the style the app gave it. Its position and rotation are
  /// replaced while the vehicle moves.
  final Marker baseMarker;

  /// Distance of the marker as it is shown, which can be behind the last
  /// position that arrived while the marker is still moving.
  double shownAlong = 0;

  /// Distance for which the route lines were last drawn.
  double? drawnAlong;

  MarkerId get markerId => tracking.markerId;

  PolylineId get traveledId => PolylineId('${markerId.value}#traveled');
  PolylineId get remainingId => PolylineId('${markerId.value}#remaining');

  Set<PolylineId> get polylineIds => {traveledId, remainingId};

  /// The lines to draw when the vehicle is [along] meters along the route.
  ///
  /// A line that is not drawn (hidden or empty) is `null`.
  ({Polyline? traveled, Polyline? remaining}) linesAt(double along) {
    if (!tracking.consumeRoute) {
      return (
        traveled: null,
        remaining: _line(remainingId, tracking.remaining, path.points)
      );
    }

    final travelledPoints = path.slice(0, along);
    final remainingPoints = path.slice(along, path.length);
    return (
      traveled: travelledPoints.length < 2
          ? null
          : _line(traveledId, tracking.traveled, travelledPoints),
      remaining: remainingPoints.length < 2
          ? null
          : _line(remainingId, tracking.remaining, remainingPoints),
    );
  }

  Polyline? _line(PolylineId id, RouteStyle style, List<LatLng> points) {
    if (!style.visible) return null;
    return Polyline(
      polylineId: id,
      points: points,
      color: style.color,
      width: style.width,
    );
  }
}

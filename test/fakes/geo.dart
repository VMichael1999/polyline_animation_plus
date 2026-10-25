import 'dart:math';

import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/src/utils/spherical_util.dart';

/// A point [east] and [north] meters from the origin, on the equator where a
/// degree is about the same in both directions.
LatLng at(double east, double north) {
  const degreesPerMeter = 180 / (pi * SphericalUtil.earthRadius);
  return LatLng(north * degreesPerMeter, east * degreesPerMeter);
}

/// The inverse of [at].
({double east, double north}) metersOf(LatLng point) {
  const degreesPerMeter = 180 / (pi * SphericalUtil.earthRadius);
  return (
    east: point.longitude / degreesPerMeter,
    north: point.latitude / degreesPerMeter,
  );
}

double metersBetween(LatLng a, LatLng b) =>
    SphericalUtil.computeDistanceBetween(a, b).toDouble();

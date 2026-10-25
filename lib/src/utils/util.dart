// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.

import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/src/utils/spherical_util.dart';

/// Helpers to prepare data for animations.
final class MapAnimationUtils {
  MapAnimationUtils._();

  /// Tolerance used to absorb floating point error when comparing distances.
  static const _epsilonMeters = 1e-6;

  /// Returns points along [path] that are the same distance apart, so a
  /// progressive animation moves at a constant speed on the map.
  ///
  /// The spacing is the length of the path divided by the number of frames
  /// that fit in [duration] ([frameIntervalMs] per frame). The result starts at
  /// the first point of [path] and ends at its last point; the last gap can be
  /// shorter than the others. A [path] with fewer than two points, or a
  /// zero [duration], is returned unchanged.
  static List<LatLng> generateEquidistantPolylineByDuration({
    required List<LatLng> path,
    required Duration duration,
    int frameIntervalMs = 16, // e.g. 60 FPS
  }) {
    if (path.length < 2 || duration.inMilliseconds == 0) return path;

    double totalDistance = 0;
    for (int i = 0; i < path.length - 1; i++) {
      totalDistance += SphericalUtil.computeDistanceBetween(
        path[i],
        path[i + 1],
      );
    }

    int steps = duration.inMilliseconds ~/ frameIntervalMs;
    if (steps == 0) return path;

    double spacingMeters = totalDistance / steps;

    return _createEquidistantPoints(path, spacingMeters);
  }

  /// Generates a list of LatLng points spaced evenly in meters along a polyline path
  static List<LatLng> _createEquidistantPoints(
    List<LatLng> path,
    double spacingMeters,
  ) {
    if (path.length < 2 || spacingMeters <= 0) return path;

    final result = <LatLng>[path.first];

    // Distance travelled since the last emitted point.
    var carry = 0.0;

    for (int i = 0; i < path.length - 1; i++) {
      final start = path[i];
      final end = path[i + 1];
      final segmentLength = SphericalUtil.computeDistanceBetween(start, end);

      // Distance along this segment to the next point to emit.
      var next = spacingMeters - carry;
      while (next <= segmentLength + _epsilonMeters) {
        result.add(SphericalUtil.interpolate(start, end, next / segmentLength));
        next += spacingMeters;
      }
      carry = spacingMeters - (next - segmentLength);
    }

    final last = path.last;
    if (SphericalUtil.computeDistanceBetween(result.last, last) >
        _epsilonMeters) {
      result.add(last);
    }

    return result;
  }
}

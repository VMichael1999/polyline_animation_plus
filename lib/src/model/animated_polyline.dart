// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.

import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/src/animator/base/polyline_animator.dart';

/// A polyline together with the animation that draws it.
class AnimatedPolyline {
  /// The polyline to draw. Its points and style are the final state.
  final Polyline polyline;

  /// How the polyline is animated. If null, the polyline is static and is
  /// drawn as it is.
  final PolylineAnimator? polylineAnimator;

  /// Creates an animated polyline, or a static one when no animator is given.
  const AnimatedPolyline({required this.polyline, this.polylineAnimator});

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

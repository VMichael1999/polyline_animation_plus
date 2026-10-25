// Internal, not exported: public API docs are only required for exported code.
// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../model/camera_follow.dart';

/// Moves the camera after a marker, at most about 10 times per second.
class CameraFollower {
  CameraFollower({
    required this.follow,
    required this.moveCamera,
    required this.now,
  });

  /// At most one camera update in this time.
  static const Duration minInterval = Duration(milliseconds: 100);

  /// A start of camera movement this soon after an update of ours is taken as
  /// the effect of that update and not as the user.
  static const Duration echoWindow = Duration(milliseconds: 150);

  /// Creates the clock a follower uses. It is a real clock: the frames of
  /// Flutter stop when nothing is animating, so they cannot tell how long ago
  /// the camera was moved. Tests replace it with their own clock.
  static Duration Function() Function() createClock = () {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  };

  final CameraFollow follow;
  final void Function(CameraUpdate update) moveCamera;

  /// The time, from a clock that does not depend on the frames.
  final Duration Function() now;

  Duration? _lastMove;
  Marker? _latest;
  Timer? _trailing;
  bool _disposed = false;

  /// A new state of the followed marker.
  void onMarker(Marker marker) {
    if (_disposed) return;
    _latest = marker;

    final last = _lastMove;
    if (last == null || now() - last >= minInterval) {
      _move();
      return;
    }

    // Too soon: send the latest state when the interval is over, so the camera
    // does not stay behind when the marker stops.
    _trailing ??= Timer(minInterval - (now() - last), () {
      _trailing = null;
      if (!_disposed) _move();
    });
  }

  /// The user may have moved the map. Returns true if the camera was following
  /// and now stops.
  bool onCameraMoveStarted() {
    if (_disposed) return false;
    final last = _lastMove;
    if (last != null && now() - last < echoWindow) return false;

    dispose();
    return true;
  }

  void _move() {
    final marker = _latest;
    if (marker == null) return;

    _lastMove = now();
    moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: marker.position,
          zoom: follow.zoom,
          tilt: follow.tilt,
          bearing: follow.bearing == CameraBearing.vehicle
              ? _normalize(marker.rotation)
              : 0,
        ),
      ),
    );
  }

  static double _normalize(double degrees) => ((degrees % 360) + 360) % 360;

  void dispose() {
    _disposed = true;
    _trailing?.cancel();
    _trailing = null;
  }
}

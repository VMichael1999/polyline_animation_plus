// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.
// Internal, not exported: public API docs are only required for exported code.
// ignore_for_file: public_member_api_docs

import 'dart:collection';

import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../model/marker_animation.dart';
import '../tween/bearing_tween.dart';
import '../tween/location_tween.dart';
import '../utils/spherical_util.dart';

/// Moves one marker. It has its own clock and queue, so it does not depend on
/// any other marker.
///
/// Time is a [Duration] on a timeline that the caller advances (the manager
/// uses a ticker). Nothing here needs a real clock, which keeps it testable.
class MarkerController {
  /// Moves shorter than this keep the current rotation, because the heading
  /// between two (almost) identical positions is meaningless.
  static const double minMoveMeters = 0.5;

  /// When true the rotation comes from [Marker.rotation] instead of the
  /// heading between positions.
  final bool useMarkerRotation;

  final MarkerAnimationMode mode;
  final MarkerDuration duration;

  /// The marker the controller is moving to, or has reached.
  Marker _target;
  Marker get currentMarker => _target;

  LocationTween _location;
  BearingTween _bearing;

  bool _moving = false;
  Duration _start = Duration.zero;
  Duration _length = Duration.zero;

  /// When the last distinct position arrived, on the wall clock.
  Duration? _lastPush;

  final Queue<({Marker marker, Duration length})> _queue = Queue();

  MarkerController({
    required Marker marker,
    this.useMarkerRotation = false,
    this.mode = MarkerAnimationMode.queue,
    this.duration = const MarkerDuration.fixed(Duration(seconds: 2)),
  })  : _target = marker,
        _location = LocationTween(begin: marker.position, end: marker.position),
        _bearing = BearingTween(begin: marker.rotation, end: marker.rotation);

  /// Whether the marker is moving or has moves waiting.
  bool get isMoving => _moving;

  /// Number of moves waiting after the current one.
  int get queued => _queue.length;

  /// Adds a new state for the marker.
  ///
  /// [timeline] is the animation time, [wallClock] a real clock used to measure
  /// the time between positions. Returns the marker to show right now when the
  /// change needs no animation, otherwise `null`.
  Marker? push(
    Marker marker, {
    required Duration timeline,
    required Duration wallClock,
  }) {
    final latest = _queue.isEmpty ? _target : _queue.last.marker;
    if (latest == marker) return null;

    final length = duration.resolve(
      _lastPush == null ? null : wallClock - _lastPush!,
    );
    _lastPush = wallClock;

    if (mode == MarkerAnimationMode.latestOnly) {
      _queue.clear();
      return _begin(marker, length, timeline);
    }

    if (_moving) {
      _queue.addLast((marker: marker, length: length));
      return null;
    }
    return _begin(marker, length, timeline);
  }

  /// Moves the controller to [timeline]. Returns the marker to show, or `null`
  /// when nothing is moving.
  Marker? tick(Duration timeline) {
    if (!_moving) return null;

    while (true) {
      var endTime = timeline;
      if (_moving) {
        if (timeline - _start < _length) {
          return _markerAt(
            (timeline - _start).inMicroseconds / _length.inMicroseconds,
          );
        }
        endTime = _start + _length;
        _moving = false;
      }
      if (_queue.isEmpty) return _markerAt(1);

      // Chain the next move from where the previous one ended, so a long frame
      // does not lose time.
      final next = _queue.removeFirst();
      _begin(next.marker, next.length, endTime);
    }
  }

  Marker? _begin(Marker marker, Duration length, Duration timeline) {
    final shown = _markerAtTime(timeline);
    final previousTarget = _target.position;

    final movesTarget =
        SphericalUtil.computeDistanceBetween(previousTarget, marker.position) >=
            minMoveMeters;
    final movesShown =
        SphericalUtil.computeDistanceBetween(shown.position, marker.position) >=
            minMoveMeters;

    final double rotationTo;
    if (useMarkerRotation) {
      rotationTo = marker.rotation;
    } else if (movesTarget) {
      rotationTo = SphericalUtil.computeHeading(
        previousTarget,
        marker.position,
      ).toDouble();
    } else {
      rotationTo = _bearing.end;
    }

    _target = marker;
    _location = LocationTween(begin: shown.position, end: marker.position);
    _bearing = BearingTween(begin: shown.rotation, end: rotationTo);
    _start = timeline;
    _length = length;

    final needsAnimation = length > Duration.zero &&
        (movesShown || (shown.rotation - rotationTo).abs() > 1e-9);
    if (needsAnimation) {
      _moving = true;
      return null;
    }

    _moving = false;
    return _markerAt(1);
  }

  Marker _markerAtTime(Duration timeline) {
    if (!_moving || _length <= Duration.zero) return _markerAt(1);
    final t = (timeline - _start).inMicroseconds / _length.inMicroseconds;
    return _markerAt(t);
  }

  Marker _markerAt(double t) {
    final clamped = t.clamp(0.0, 1.0);
    return _target.copyWith(
      positionParam: clamped >= 1 ? _location.end : _location.lerp(clamped),
      rotationParam: _bearing.lerp(clamped),
    );
  }
}

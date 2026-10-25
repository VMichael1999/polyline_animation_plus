// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../tween/bearing_tween.dart';
import '../tween/location_tween.dart';
import '../utils/spherical_util.dart';

class MarkerController {
  /// Moves shorter than this keep the current rotation, because the heading
  /// between two (almost) identical positions is meaningless.
  static const double minMoveMeters = 0.5;

  /// When true the rotation comes from [Marker.rotation] instead of the
  /// heading between positions.
  final bool useMarkerRotation;

  final AnimationController _animationController;

  late final LocationTween _locationTween;
  late final BearingTween _bearingTween;

  Marker _currentMarker;
  Marker get currentMarker => _currentMarker;

  final Queue<Marker> _queue = Queue<Marker>();

  bool get hasMarker => _queue.isNotEmpty;

  MarkerController({
    required Marker marker,
    required AnimationController animationController,
    this.useMarkerRotation = false,
  })  : _currentMarker = marker,
        _animationController = animationController {
    _locationTween = LocationTween(
      begin: marker.position,
      end: marker.position,
    );

    _bearingTween = BearingTween(begin: marker.rotation, end: marker.rotation);

    _locationTween.animate(_animationController);
    _bearingTween.animate(_animationController);
  }

  void pushToQueue(Marker m) {
    if (_currentMarker == m) {
      return;
    }

    _queue.addLast(m);
  }

  void setupNextMarker() {
    if (_queue.isEmpty) return;
    final nextMarker = _queue.removeFirst();
    _setupTo(nextMarker);
  }

  void _setupTo(Marker m) {
    final moved =
        SphericalUtil.computeDistanceBetween(_locationTween.end, m.position) >=
            minMoveMeters;

    _currentMarker = m;
    _locationTween.swap(m.position);

    if (useMarkerRotation) {
      _bearingTween.swap(m.rotation);
    } else if (moved) {
      _bearingTween.swap(_locationTween.bearing);
    } else {
      _bearingTween.swap(_bearingTween.end);
    }
  }

  Marker animate(double t) {
    return _currentMarker.copyWith(
      positionParam: _locationTween.lerp(t),
      rotationParam: _bearingTween.lerp(t),
    );
  }
}

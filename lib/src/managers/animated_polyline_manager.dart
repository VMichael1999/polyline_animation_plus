// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.
// Internal, not exported: public API docs are only required for exported code.
// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../animator/base/polyline_animator.dart';
import '../controllers/polyline_controller.dart';
import '../model/polyline_animation_handle.dart';

/// Manages the animation of multiple polylines on a map.
///
/// This class handles the creation, updating, and disposal of polyline animations,
/// ensuring that animations run smoothly and are properly managed through their lifecycle.
class AnimatedPolylineManager {
  /// Map of controllers for each animated polyline, keyed by PolylineId
  final Map<PolylineId, PolylineAnimationController> _controllers = {};

  /// Ticker provider for animations
  final TickerProvider _vsync;

  /// Callback invoked when a polyline is updated during animation
  final void Function(PolylineId owner, List<Polyline> polylines) _listener;

  AnimatedPolylineManager({
    required TickerProvider vsync,
    required void Function(PolylineId owner, List<Polyline> polylines)
        polylinesListener,
    bool reducedMotion = false,
  })  : _vsync = vsync,
        _listener = polylinesListener,
        _reducedMotion = reducedMotion;

  bool _reducedMotion;
  bool _inBackground = false;

  List<PolylineId> get activePolylineIds => _controllers.keys.toList();

  void push({
    required Polyline polyline,
    required PolylineAnimator polylineAnimator,
  }) {
    PolylineAnimationController createController() =>
        PolylineAnimationController(
          vsync: _vsync,
          polylinesListener: _listener,
          polylineAnimator: polylineAnimator,
          polyline: polyline,
          reducedMotion: _reducedMotion,
        )..setInBackground(_inBackground);

    final controller = _controllers[polyline.polylineId];

    if (controller != null) {
      if (controller.polylineAnimator != polylineAnimator) {
        controller.dispose();
        _controllers[polyline.polylineId] = createController();
      } else {
        controller.updatePolyline(polyline);
      }
    } else {
      _controllers[polyline.polylineId] = createController();
    }
  }

  /// The app went to the background or came back: the animations keep their
  /// place and go on when it returns.
  void setInBackground(bool inBackground) {
    _inBackground = inBackground;
    for (final controller in _controllers.values) {
      controller.setInBackground(inBackground);
    }
  }

  /// The system started or stopped asking to reduce motion.
  void setReducedMotion(bool reduced) {
    _reducedMotion = reduced;
    for (final controller in _controllers.values) {
      controller.setReducedMotion(reduced);
    }
  }

  /// The handle of the animation of [polylineId], if it is being animated.
  PolylineAnimationHandle? handleFor(PolylineId polylineId) =>
      _controllers[polylineId]?.handle;

  void removePolyline(PolylineId polylineId) {
    final controller = _controllers[polylineId];

    if (controller != null) {
      controller.dispose();
      _controllers.remove(polylineId);
    }
  }

  void removePolylines(Set<PolylineId> polylineIds) {
    for (final id in polylineIds) {
      removePolyline(id);
    }
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }
}

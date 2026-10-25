// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.
// Internal, not exported: public API docs are only required for exported code.
// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../animations/delayed_curved_animation.dart';
import '../animator/base/polyline_animator.dart';

/// Controls the animation of a polyline.
///
/// This class manages the animation lifecycle and state for a polyline animation,
/// including starting, stopping, and updating the animation based on the configuration.
class PolylineAnimationController {
  /// The ticker provider that drives the animation
  final TickerProvider vsync;
  final PolylineAnimator polylineAnimator;
  final void Function(Polyline) polylineListener;
  late final AnimationController _controller;
  late final Animation<double> _curvedAnimation;

  Polyline _polyline;

  bool get isAnimating => _controller.isAnimating;

  PolylineAnimationController({
    required this.vsync,
    required Polyline polyline,
    required this.polylineAnimator,
    required this.polylineListener,
  }) : _polyline = polyline {
    _initialize();
  }

  void _initialize() {
    // The controller must run for the whole cycle (delays included), because
    // DelayedCurvedAnimation computes its interval over that total.
    final totalDuration = polylineAnimator.duration +
        polylineAnimator.delayStart +
        polylineAnimator.delayEnd;

    _controller = AnimationController(vsync: vsync, duration: totalDuration)
      ..addListener(_listener)
      ..addStatusListener(_statusListener);

    if (polylineAnimator.delayStart != Duration.zero ||
        polylineAnimator.delayEnd != Duration.zero) {
      _curvedAnimation = DelayedCurvedAnimation(
        controller: _controller,
        totalDuration: totalDuration,
        delayStart: polylineAnimator.delayStart,
        delayEnd: polylineAnimator.delayEnd,
        curve: polylineAnimator.curve,
      );
    } else {
      _curvedAnimation = CurvedAnimation(
        parent: _controller,
        curve: polylineAnimator.curve,
      );
    }

    final repeatCount = polylineAnimator.repeatCount;
    if (polylineAnimator.repeat && repeatCount != null) {
      // AnimationController.repeat(count:) does not exist in older Flutter
      // versions, so limited repeats use their own simulation.
      _controller.animateWith(
        _LimitedRepeatSimulation(
          passes: repeatCount,
          reverse: polylineAnimator.reverse,
          period: totalDuration,
        ),
      );
    } else if (polylineAnimator.repeat) {
      _controller.repeat(reverse: polylineAnimator.reverse);
    } else {
      _controller.forward();
    }
  }

  void updatePolyline(Polyline polyline) {
    _polyline = polyline;
  }

  void _listener() {
    final progress = _curvedAnimation.value;
    final animatedPolyline = polylineAnimator.animate(_polyline, progress);
    polylineListener(animatedPolyline);
  }

  void _statusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      polylineAnimator.onAnimationStop();
    }
  }

  void dispose() {
    _controller.removeListener(_listener);
    _controller.removeStatusListener(_statusListener);

    _controller.dispose();
  }
}

/// Plays [passes] passes from 0 to 1, or alternately 0 to 1 and 1 to 0 when
/// [reverse] is true, each lasting [period]. It behaves like
/// `AnimationController.repeat(count: passes)`.
class _LimitedRepeatSimulation extends Simulation {
  _LimitedRepeatSimulation({
    required this.passes,
    required this.reverse,
    required Duration period,
  }) : _periodSeconds = period.inMicroseconds / Duration.microsecondsPerSecond;

  final int passes;
  final bool reverse;
  final double _periodSeconds;

  bool _isForward(int pass) => !reverse || pass.isEven;

  @override
  double x(double timeInSeconds) {
    if (isDone(timeInSeconds)) return _isForward(passes - 1) ? 1.0 : 0.0;

    final pass = timeInSeconds ~/ _periodSeconds;
    final fraction = (timeInSeconds - pass * _periodSeconds) / _periodSeconds;
    return _isForward(pass) ? fraction : 1.0 - fraction;
  }

  @override
  double dx(double timeInSeconds) => 0.0;

  @override
  bool isDone(double timeInSeconds) => timeInSeconds >= passes * _periodSeconds;
}

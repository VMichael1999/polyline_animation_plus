// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.
// Internal, not exported: public API docs are only required for exported code.
// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../animations/delayed_curved_animation.dart';
import '../animator/base/polyline_animator.dart';
import '../model/polyline_animation_handle.dart';

/// Controls the animation of a polyline.
///
/// This class manages the animation lifecycle and state for a polyline animation,
/// including starting, stopping, and updating the animation based on the configuration.
class PolylineAnimationController implements PolylineAnimationBackend {
  /// The ticker provider that drives the animation
  final TickerProvider vsync;
  final PolylineAnimator polylineAnimator;

  /// Called on every frame with the animated polyline and the extra polylines
  /// of the animation, if any. The first argument is the animated polyline.
  final void Function(PolylineId owner, List<Polyline> polylines)
      polylinesListener;
  late final AnimationController _controller;
  late final Animation<double> _curvedAnimation;

  /// What the app uses to pause, seek and follow this animation.
  late final PolylineAnimationHandle handle = PolylineAnimationHandle(this);

  Polyline _polyline;

  late final double _periodSeconds;

  /// Number of passes to play, or `null` for ever.
  late final int? _passes;

  /// Where the current simulation started, in seconds of animation time.
  double _offset = 0;

  /// Animation time at the moment it was paused or sought.
  double _frozenTime = 0;

  /// Passes already reported through `onCycle`.
  int _reportedPasses = 0;

  _State _state = _State.playing;
  bool _changingValue = false;
  bool _disposed = false;

  final StreamController<double> _progress = StreamController.broadcast();

  bool get isAnimating => _controller.isAnimating;

  PolylineAnimationController({
    required this.vsync,
    required Polyline polyline,
    required this.polylineAnimator,
    required this.polylinesListener,
  }) : _polyline = polyline {
    _initialize();
  }

  void _initialize() {
    // The controller must run for the whole cycle (delays included), because
    // DelayedCurvedAnimation computes its interval over that total.
    final totalDuration = polylineAnimator.duration +
        polylineAnimator.delayStart +
        polylineAnimator.delayEnd;
    _periodSeconds =
        totalDuration.inMicroseconds / Duration.microsecondsPerSecond;

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

    _passes = polylineAnimator.repeat ? polylineAnimator.repeatCount : 1;
    _play(0);

    // An animation without duration is already at its end: draw it now instead
    // of waiting for the first frame.
    if (_periodSeconds <= 0) _listener();
  }

  /// Plays from [time] seconds of animation time.
  ///
  /// A custom simulation is used instead of AnimationController.repeat because
  /// repeat(count:) does not exist in older Flutter versions and it cannot
  /// resume from a given time.
  void _play(double time) {
    _offset = time;
    _reportedPasses = _passIndexAt(time);
    _state = _State.playing;
    _controller.animateWith(
      _CycleSimulation(
        period: _periodSeconds,
        passes: _passes,
        reverse: polylineAnimator.reverse,
        offset: time,
      ),
    );
  }

  int _passIndexAt(double time) =>
      _periodSeconds <= 0 ? 0 : (time / _periodSeconds).floor();

  /// Animation time now, in seconds. Only meaningful while playing.
  double get _timeNow {
    final elapsed = _controller.lastElapsedDuration;
    return _offset +
        (elapsed == null
            ? 0
            : elapsed.inMicroseconds / Duration.microsecondsPerSecond);
  }

  void updatePolyline(Polyline polyline) {
    _polyline = polyline;
    // Nothing is running to redraw it when there is no duration.
    if (_periodSeconds <= 0) _listener();
  }

  void _listener() {
    if (_disposed) return;

    final progress = _curvedAnimation.value;
    polylinesListener(
      _polyline.polylineId,
      polylineAnimator.animateAll(_polyline, progress),
    );

    if (_progress.hasListener) _progress.add(_controller.value);

    if (_state == _State.playing && !_changingValue) _reportCycles();
  }

  /// Reports the passes that ended since the last frame.
  void _reportCycles() {
    final passes = _passes;
    var ended = _passIndexAt(_timeNow);
    // The last pass is reported when the animation completes.
    if (passes != null && ended >= passes) ended = passes - 1;

    while (_reportedPasses < ended) {
      _reportedPasses++;
      handle.onCycle?.call(_reportedPasses);
    }
  }

  void _statusListener(AnimationStatus status) {
    if (_disposed || _changingValue) return;
    if (status != AnimationStatus.completed) return;

    _state = _State.finished;
    final passes = _passes;
    _frozenTime = (passes ?? 0) * _periodSeconds;
    if (passes != null) {
      while (_reportedPasses < passes) {
        _reportedPasses++;
        handle.onCycle?.call(_reportedPasses);
      }
    }
    polylineAnimator.onAnimationStop();
    handle.onComplete?.call();
  }

  @override
  void pause() {
    if (_disposed || _state != _State.playing) return;
    _frozenTime = _timeNow;
    _controller.stop();
    _state = _State.paused;
  }

  @override
  void resume() {
    if (_disposed || _state != _State.paused) return;
    _play(_frozenTime);
  }

  @override
  void seek(double progress) {
    if (_disposed) return;
    final target = progress.clamp(0.0, 1.0);

    final wasPlaying = _state == _State.playing;
    final time = wasPlaying ? _timeNow : _frozenTime;

    // Stay in the pass that is running, and take the direction into account:
    // a pass played backwards shows the progress the other way round.
    var pass = _passIndexAt(time);
    final passes = _passes;
    if (passes != null && pass >= passes) pass = passes - 1;
    final forward = !polylineAnimator.reverse || pass.isEven;
    final fraction = forward ? target : 1 - target;
    _frozenTime = (pass + fraction) * _periodSeconds;

    _changingValue = true;
    _controller.value = target; // also stops the running simulation
    _changingValue = false;

    if (wasPlaying) {
      _play(_frozenTime);
    } else {
      _state = _State.paused;
    }
  }

  @override
  bool get isPlaying => _state == _State.playing;

  @override
  bool get isCompleted => _state == _State.finished;

  @override
  double get value => _controller.value;

  @override
  Stream<double> get progress => _progress.stream;

  void dispose() {
    _disposed = true;
    _controller.removeListener(_listener);
    _controller.removeStatusListener(_statusListener);

    _controller.dispose();
    _progress.close();
  }
}

enum _State { playing, paused, finished }

/// Plays [passes] passes from 0 to 1 (for ever when `null`), or alternately 0
/// to 1 and 1 to 0 when [reverse] is true, each lasting [period] seconds.
/// Starting from [offset] seconds in. It behaves like
/// `AnimationController.repeat(count: passes)`.
class _CycleSimulation extends Simulation {
  _CycleSimulation({
    required this.period,
    required this.passes,
    required this.reverse,
    required this.offset,
  });

  final double period;
  final int? passes;
  final bool reverse;
  final double offset;

  bool _isForward(int pass) => !reverse || pass.isEven;

  @override
  double x(double timeInSeconds) {
    final time = offset + timeInSeconds;
    final total = passes;
    if (period <= 0) return total == null || _isForward(total - 1) ? 1.0 : 0.0;
    if (total != null && time >= total * period) {
      return _isForward(total - 1) ? 1.0 : 0.0;
    }

    final pass = time ~/ period;
    final fraction = (time - pass * period) / period;
    return _isForward(pass) ? fraction : 1.0 - fraction;
  }

  @override
  double dx(double timeInSeconds) => 0.0;

  @override
  bool isDone(double timeInSeconds) {
    final total = passes;
    if (period <= 0) return total != null;
    return total != null && offset + timeInSeconds >= total * period;
  }
}

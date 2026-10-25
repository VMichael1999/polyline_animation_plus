import 'dart:async';

import 'package:flutter/foundation.dart';

/// What a [PolylineAnimationHandle] needs from the animation it controls.
///
/// This is an implementation detail: use [PolylineAnimationHandle].
abstract interface class PolylineAnimationBackend {
  /// See [PolylineAnimationHandle.pause].
  void pause();

  /// See [PolylineAnimationHandle.resume].
  void resume();

  /// See [PolylineAnimationHandle.seek].
  void seek(double progress);

  /// See [PolylineAnimationHandle.isPlaying].
  bool get isPlaying;

  /// See [PolylineAnimationHandle.isCompleted].
  bool get isCompleted;

  /// See [PolylineAnimationHandle.value].
  double get value;

  /// See [PolylineAnimationHandle.progress].
  Stream<double> get progress;
}

/// Controls a running polyline animation: pause it, resume it, jump to a
/// point and follow its progress.
///
/// Get it with `MapAnimationController.polylineAnimation`. It stays valid
/// while the polyline keeps the same animator. If the animator is replaced, the
/// polyline is removed or the controller is disposed, the handle stops working:
/// its methods do nothing and [progress] is closed.
///
/// Progress is the position inside one cycle, from 0 to 1, in time: it
/// includes the `delayStart` and `delayEnd` of the animator and is measured
/// before its curve is applied.
final class PolylineAnimationHandle {
  /// Creates a handle for [backend]. Use
  /// `MapAnimationController.polylineAnimation` instead.
  PolylineAnimationHandle(PolylineAnimationBackend backend)
      : _backend = backend;

  final PolylineAnimationBackend _backend;

  /// Called once when the animation finishes.
  ///
  /// It is not called for an animation that repeats forever, because it never
  /// finishes. Use [onCycle] for those.
  VoidCallback? onComplete;

  /// Called every time a pass of the animation ends, with the number of passes
  /// played so far (1 for the first).
  ///
  /// With `reverse`, going forward and coming back count as one pass each, the
  /// same as `repeatCount`. For the last pass of an animation that finishes it
  /// is called just before [onComplete].
  void Function(int cycle)? onCycle;

  /// Freezes the animation where it is. Does nothing if it is already paused
  /// or has finished.
  void pause() => _backend.pause();

  /// Continues a paused animation from where it stopped. Does nothing if it is
  /// already playing or has finished.
  void resume() => _backend.resume();

  /// Jumps to [progress], from 0 to 1, in the current cycle.
  ///
  /// A playing animation keeps playing from there. A paused or finished one
  /// stays where it is until [resume] is called.
  void seek(double progress) => _backend.seek(progress);

  /// Whether the animation is running (not paused and not finished).
  bool get isPlaying => _backend.isPlaying;

  /// Whether the animation has finished. It is never true for an animation
  /// that repeats forever.
  bool get isCompleted => _backend.isCompleted;

  /// The current progress, from 0 to 1.
  double get value => _backend.value;

  /// The progress on every frame, from 0 to 1.
  ///
  /// It is a broadcast stream and is closed when the handle stops working.
  Stream<double> get progress => _backend.progress;
}

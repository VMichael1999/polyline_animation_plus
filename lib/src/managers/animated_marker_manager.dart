// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.
// Internal, not exported: public API docs are only required for exported code.
// ignore_for_file: public_member_api_docs

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../controllers/marker_controller.dart';
import '../model/marker_animation.dart';

/// Animates a set of markers.
///
/// Every marker has its own [MarkerController], so each one moves at its own
/// pace. A single ticker drives all of them and the changes of a frame are sent
/// together, so the cost per frame does not grow with one map call per marker.
class AnimatedMarkersManager {
  AnimatedMarkersManager({
    required TickerProvider vsync,
    required this.onUpdateMarkers,
    required this.onRemoveMarkers,
    this.useMarkerRotation = false,
    this.mode = MarkerAnimationMode.queue,
    this.duration = const MarkerDuration.fixed(Duration(seconds: 2)),
    Duration Function()? clock,
  }) : _clock = clock ?? _stopwatchClock() {
    _ticker = vsync.createTicker(_onTick);
  }

  /// A real clock, used only to measure the time between positions.
  static Duration Function() _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  /// Frames closer than this are merged into one update, which keeps the map
  /// calls at about 60 per second on high refresh rate screens.
  static const Duration minUpdateInterval = Duration(milliseconds: 16);

  final bool useMarkerRotation;
  final MarkerAnimationMode mode;
  final MarkerDuration duration;

  final ValueChanged<Set<Marker>> onUpdateMarkers;
  final ValueChanged<Set<MarkerId>> onRemoveMarkers;

  final Duration Function() _clock;
  late final Ticker _ticker;

  final Map<MarkerId, MarkerController> _controllers = {};
  final Set<MarkerId> _markersToBeRemoved = {};

  /// Changes computed but not yet sent to the map.
  final Map<MarkerId, Marker> _pending = {};

  /// The timeline keeps growing across ticker restarts: [_base] is the time
  /// accumulated by earlier runs and [_elapsed] the time of the current one.
  Duration _base = Duration.zero;
  Duration _elapsed = Duration.zero;
  Duration _lastUpdate = Duration.zero;

  Duration get _timeline => _base + _elapsed;

  bool get isAnimating => _controllers.values.any((c) => c.isMoving);

  /// Sets the markers to show. New markers appear where they are; known
  /// markers move to their new state. A marker with an entry in [routes]
  /// follows that route up to the given distance.
  void push(
    Set<Marker> markers, {
    Map<MarkerId, RouteTarget> routes = const {},
  }) {
    for (final marker in markers) {
      _markersToBeRemoved.remove(marker.markerId);

      final controller = _controllers[marker.markerId];
      if (controller == null) {
        _controllers[marker.markerId] = MarkerController(
          marker: marker,
          useMarkerRotation: useMarkerRotation,
          mode: mode,
          duration: duration,
        );
        continue;
      }

      final immediate = controller.push(
        marker,
        timeline: _timeline,
        wallClock: _clock(),
        route: routes[marker.markerId],
      );
      if (immediate != null) _pending[marker.markerId] = immediate;
    }

    _flush();
    if (isAnimating && !_ticker.isActive) _ticker.start();
  }

  /// Removes a marker. A marker that is moving finishes its moves first.
  void removeMarker(MarkerId markerId) {
    final controller = _controllers[markerId];
    if (controller != null && controller.isMoving) {
      _markersToBeRemoved.add(markerId);
      return;
    }
    _controllers.remove(markerId);
    _pending.remove(markerId);
    onRemoveMarkers({markerId});
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    final timeline = _timeline;

    var finished = false;
    for (final entry in _controllers.entries) {
      final controller = entry.value;
      final marker = controller.tick(timeline);
      if (marker == null) continue;
      _pending[entry.key] = marker;
      if (!controller.isMoving) finished = true;
    }

    if (finished || timeline - _lastUpdate >= minUpdateInterval) {
      _flush();
      _lastUpdate = timeline;
    }

    if (finished) _removeFinishedMarkers();

    if (!isAnimating) {
      _flush();
      _ticker.stop();
      _base = timeline;
      _elapsed = Duration.zero;
    }
  }

  void _flush() {
    if (_pending.isEmpty) return;
    final markers = _pending.values.toSet();
    _pending.clear();
    onUpdateMarkers(markers);
  }

  void _removeFinishedMarkers() {
    final ready = _markersToBeRemoved
        .where((id) => !(_controllers[id]?.isMoving ?? false))
        .toSet();
    if (ready.isEmpty) return;

    for (final id in ready) {
      _controllers.remove(id);
      _pending.remove(id);
    }
    _markersToBeRemoved.removeAll(ready);
    onRemoveMarkers(ready);
  }

  void dispose() {
    _ticker.dispose();
    _controllers.clear();
    _markersToBeRemoved.clear();
    _pending.clear();
  }
}

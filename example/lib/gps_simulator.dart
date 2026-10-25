import 'dart:async';
import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Pretends to be the GPS of a vehicle that drives along a route.
///
/// It sends a position every [interval], with some noise like a real GPS, and
/// can send positions that are off the route to test `onOffRoute`.
class GpsSimulator {
  GpsSimulator({
    required this.route,
    required this.onPosition,
    this.onFinished,
  }) {
    _cumulative = [0];
    for (var i = 1; i < route.length; i++) {
      _cumulative.add(_cumulative.last + _meters(route[i - 1], route[i]));
    }
  }

  final List<LatLng> route;
  final void Function(LatLng position) onPosition;
  final void Function()? onFinished;

  /// How fast the vehicle drives, in meters per second.
  double speed = 12;

  /// Time between positions. A new value is used from the next position.
  Duration interval = const Duration(seconds: 1);

  /// How far, in meters, a position can be from the real one.
  double noiseMeters = 8;

  late final List<double> _cumulative;
  final _random = Random(7);
  Timer? _timer;
  bool _running = false;
  double _along = 0;
  int _offRouteLeft = 0;

  double get length => _cumulative.last;

  /// Meters driven so far.
  double get along => _along;

  bool get isRunning => _running;

  bool get isFinished => _along >= length;

  /// Starts driving, or goes on from where it stopped.
  void start() {
    if (_running) return;
    if (isFinished) _along = 0;
    _running = true;
    _schedule();
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Back to the start of the route, stopped.
  void reset() {
    stop();
    _along = 0;
    _offRouteLeft = 0;
  }

  /// The next [fixes] positions are about 80 m away from the route.
  void sendOffRoute({int fixes = 3}) => _offRouteLeft = fixes;

  /// Drives [meters] further at once, for example to reach a curve sooner.
  void skip(double meters) => _along = min(length, _along + meters);

  void dispose() => stop();

  void _schedule() {
    _timer = Timer(interval, () {
      _tick();
      if (_running) _schedule();
    });
  }

  void _tick() {
    final seconds = interval.inMicroseconds / Duration.microsecondsPerSecond;
    _along = min(length, _along + speed * seconds);

    var position = _positionAt(_along);
    if (_offRouteLeft > 0) {
      _offRouteLeft--;
      position = _shift(position, 80, 80);
    } else if (noiseMeters > 0) {
      position = _shift(
        position,
        (_random.nextDouble() * 2 - 1) * noiseMeters,
        (_random.nextDouble() * 2 - 1) * noiseMeters,
      );
    }
    onPosition(position);

    if (isFinished) {
      stop();
      onFinished?.call();
    }
  }

  LatLng _positionAt(double distance) {
    for (var i = 1; i < route.length; i++) {
      if (distance <= _cumulative[i]) {
        final segment = _cumulative[i] - _cumulative[i - 1];
        final t =
            segment == 0 ? 0.0 : (distance - _cumulative[i - 1]) / segment;
        return LatLng(
          route[i - 1].latitude +
              (route[i].latitude - route[i - 1].latitude) * t,
          route[i - 1].longitude +
              (route[i].longitude - route[i - 1].longitude) * t,
        );
      }
    }
    return route.last;
  }

  /// Moves a position by some meters east and north.
  static LatLng _shift(LatLng from, double eastMeters, double northMeters) {
    const metersPerDegree = 111320.0;
    return LatLng(
      from.latitude + northMeters / metersPerDegree,
      from.longitude +
          eastMeters / (metersPerDegree * cos(from.latitude * pi / 180)),
    );
  }

  static double _meters(LatLng a, LatLng b) {
    const radius = 6371009.0;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final h =
        pow(sin(dLat / 2), 2) +
        cos(a.latitude * pi / 180) *
            cos(b.latitude * pi / 180) *
            pow(sin(dLng / 2), 2);
    return 2 * radius * asin(sqrt(h));
  }
}

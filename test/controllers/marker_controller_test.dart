import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';
import 'package:polyline_animation_plus/src/controllers/marker_controller.dart';

const _id = MarkerId('m');
const _origin = LatLng(0, 0);
const _east = LatLng(0, 0.001);
const _eastFar = LatLng(0, 0.002);

const _second = Duration(seconds: 1);

Marker _at(LatLng position, {double rotation = 0, double alpha = 1}) => Marker(
      markerId: _id,
      position: position,
      rotation: rotation,
      alpha: alpha,
    );

MarkerController _controller(
  Marker marker, {
  bool useMarkerRotation = false,
  MarkerAnimationMode mode = MarkerAnimationMode.queue,
  MarkerDuration duration = const MarkerDuration.fixed(Duration(seconds: 2)),
}) =>
    MarkerController(
      marker: marker,
      useMarkerRotation: useMarkerRotation,
      mode: mode,
      duration: duration,
    );

void main() {
  group('rotation', () {
    test('a marker that does not move keeps its rotation', () {
      final controller = _controller(_at(_origin, rotation: 90));

      // Only a property other than the position changes.
      final shown = controller.push(
        _at(_origin, rotation: 90, alpha: 0.5),
        timeline: Duration.zero,
        wallClock: Duration.zero,
      );

      expect(shown!.rotation, 90);
      expect(shown.alpha, 0.5);
      expect(controller.isMoving, isFalse);
    });

    test('a marker that moves rotates towards the heading', () {
      final controller = _controller(_at(_origin));
      controller.push(
        _at(_east),
        timeline: Duration.zero,
        wallClock: Duration.zero,
      );

      final end = controller.tick(const Duration(seconds: 2))!;
      expect(end.rotation, closeTo(90, 1e-6));
      expect(end.position, _east);
    });

    test('useMarkerRotation takes the rotation from the marker', () {
      final controller = _controller(_at(_origin), useMarkerRotation: true);
      controller.push(
        _at(_east, rotation: 45),
        timeline: Duration.zero,
        wallClock: Duration.zero,
      );

      expect(controller.tick(const Duration(seconds: 2))!.rotation, 45);
    });

    test('a move shorter than half a meter keeps the rotation', () {
      final controller = _controller(_at(_origin, rotation: 30));
      final shown = controller.push(
        _at(const LatLng(0, 0.000001), rotation: 30),
        timeline: Duration.zero,
        wallClock: Duration.zero,
      );

      // Too small to animate: it is applied at once and keeps its rotation.
      expect(shown!.rotation, 30);
      expect(controller.isMoving, isFalse);
    });
  });

  group('queue mode', () {
    test('ignores a marker equal to the last one waiting', () {
      final controller = _controller(_at(_origin));
      controller.push(_at(_east), timeline: Duration.zero, wallClock: _second);
      controller.push(_at(_eastFar),
          timeline: Duration.zero, wallClock: _second);
      controller.push(_at(_eastFar),
          timeline: Duration.zero, wallClock: _second);

      expect(controller.queued, 1);
    });

    test('ignores a marker equal to the current one when nothing waits', () {
      final controller = _controller(_at(_origin));

      expect(
        controller.push(
          _at(_origin),
          timeline: Duration.zero,
          wallClock: Duration.zero,
        ),
        isNull,
      );
      expect(controller.isMoving, isFalse);
    });

    test('moves linearly and plays the positions in order', () {
      final controller = _controller(_at(_origin));
      controller.push(_at(_east),
          timeline: Duration.zero, wallClock: Duration.zero);
      controller.push(_at(_eastFar),
          timeline: Duration.zero, wallClock: Duration.zero);

      expect(
          controller.tick(_second)!.position.longitude, closeTo(0.0005, 1e-9));
      expect(controller.tick(const Duration(seconds: 3))!.position.longitude,
          closeTo(0.0015, 1e-9));
      final end = controller.tick(const Duration(seconds: 4))!;
      expect(end.position, _eastFar);
      expect(controller.isMoving, isFalse);
    });

    test('a long frame does not lose time between two moves', () {
      final controller = _controller(_at(_origin));
      controller.push(_at(_east),
          timeline: Duration.zero, wallClock: Duration.zero);
      controller.push(_at(_eastFar),
          timeline: Duration.zero, wallClock: Duration.zero);

      // One frame arrives 3 s later: 1 s into the second move.
      final shown = controller.tick(const Duration(seconds: 3))!;
      expect(shown.position.longitude, closeTo(0.0015, 1e-9));
    });

    test('tick does nothing when the marker is not moving', () {
      expect(_controller(_at(_origin)).tick(_second), isNull);
    });
  });

  group('latestOnly mode', () {
    test('goes to the newest position from where it is shown', () {
      final controller = _controller(
        _at(_origin),
        mode: MarkerAnimationMode.latestOnly,
      );
      controller.push(_at(_east),
          timeline: Duration.zero, wallClock: Duration.zero);

      // Halfway through the first move a new position arrives.
      expect(
          controller.tick(_second)!.position.longitude, closeTo(0.0005, 1e-9));
      controller.push(_at(_eastFar), timeline: _second, wallClock: _second);

      expect(controller.queued, 0);
      final start = controller.tick(_second)!;
      expect(start.position.longitude, closeTo(0.0005, 1e-9));
      final middle = controller.tick(const Duration(seconds: 2))!;
      expect(middle.position.longitude, closeTo(0.00125, 1e-9));
      expect(controller.tick(const Duration(seconds: 3))!.position, _eastFar);
    });

    test('drops the positions in between', () {
      final controller = _controller(
        _at(_origin),
        mode: MarkerAnimationMode.latestOnly,
      );
      controller.push(_at(_east),
          timeline: Duration.zero, wallClock: Duration.zero);
      controller.push(_at(const LatLng(0, 0.0015)),
          timeline: Duration.zero, wallClock: _second);
      controller.push(_at(_eastFar),
          timeline: Duration.zero, wallClock: _second);

      expect(controller.queued, 0);
      expect(controller.tick(const Duration(seconds: 2))!.position, _eastFar);
    });

    test('keeps turning smoothly when it changes direction midway', () {
      final controller = _controller(
        _at(_origin),
        mode: MarkerAnimationMode.latestOnly,
      );
      controller.push(_at(_east),
          timeline: Duration.zero, wallClock: Duration.zero);
      controller.tick(_second);
      controller.push(
        _at(const LatLng(0.001, 0.0005)),
        timeline: _second,
        wallClock: _second,
      );

      // Halfway through a turn from 0 to 90 it is at 45. The new move starts
      // from there, not from the old target's 90.
      final start = controller.tick(_second)!;
      expect(start.rotation, closeTo(45, 1e-6));
    });
  });

  group('adaptive duration', () {
    MarkerController adaptive() => _controller(
          _at(_origin),
          mode: MarkerAnimationMode.latestOnly,
          duration: const MarkerDuration.adaptive(max: Duration(seconds: 2)),
        );

    test('the first move lasts the maximum', () {
      final controller = adaptive();
      controller.push(_at(_east),
          timeline: Duration.zero, wallClock: Duration.zero);

      expect(
          controller.tick(_second)!.position.longitude, closeTo(0.0005, 1e-9));
    });

    test('later moves last as long as the time between positions', () {
      final controller = adaptive();
      controller.push(_at(_east),
          timeline: Duration.zero, wallClock: Duration.zero);
      controller.push(
        _at(_eastFar),
        timeline: Duration.zero,
        wallClock: const Duration(milliseconds: 500),
      );

      // 500 ms between positions: the move from 0 to 0.002 takes 500 ms.
      expect(
        controller.tick(const Duration(milliseconds: 250))!.position.longitude,
        closeTo(0.001, 1e-9),
      );
      expect(controller.tick(const Duration(milliseconds: 500))!.position,
          _eastFar);
    });

    test('a long pause is capped at the maximum', () {
      final controller = adaptive();
      controller.push(_at(_east),
          timeline: Duration.zero, wallClock: Duration.zero);
      controller.push(
        _at(_eastFar),
        timeline: Duration.zero,
        wallClock: const Duration(seconds: 30),
      );

      expect(
          controller.tick(_second)!.position.longitude, closeTo(0.001, 1e-9));
    });
  });
}

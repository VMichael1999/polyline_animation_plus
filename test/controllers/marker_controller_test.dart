import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';
import 'package:polyline_animation_plus/src/controllers/marker_controller.dart';
import 'package:polyline_animation_plus/src/utils/route_path.dart';
import 'package:polyline_animation_plus/src/utils/spherical_util.dart';

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

  group('following a route', () {
    LatLng at(double east, double north) {
      const degreesPerMeter = 180 / (pi * SphericalUtil.earthRadius);
      return LatLng(north * degreesPerMeter, east * degreesPerMeter);
    }

    // 100 m east, then 100 m north.
    final route = RoutePath([at(0, 0), at(100, 0), at(100, 100)]);

    void expectNear(LatLng actual, LatLng expected) {
      expect(
        SphericalUtil.computeDistanceBetween(actual, expected),
        lessThan(0.05),
        reason: '$actual is not near $expected',
      );
    }

    MarkerController start({
      MarkerAnimationMode mode = MarkerAnimationMode.queue,
      bool useMarkerRotation = false,
    }) =>
        _controller(
          _at(at(0, 0)),
          mode: mode,
          useMarkerRotation: useMarkerRotation,
          duration: const MarkerDuration.fixed(Duration(seconds: 2)),
        );

    test('turns at the corner instead of cutting it', () {
      final controller = start();
      controller.push(
        _at(at(100, 100)),
        timeline: Duration.zero,
        wallClock: Duration.zero,
        route: RouteTarget(route, 200),
      );

      // 200 m in 2 s: the corner is at 1 s.
      final before = controller.tick(const Duration(milliseconds: 500))!;
      expectNear(before.position, at(50, 0));
      expect(before.rotation, closeTo(90, 1e-6));

      final after = controller.tick(const Duration(milliseconds: 1500))!;
      expectNear(after.position, at(100, 50));
      expect(after.rotation, closeTo(0, 1e-6));

      final end = controller.tick(const Duration(seconds: 2))!;
      expectNear(end.position, at(100, 100));
      expect(controller.isMoving, isFalse);
    });

    test('a second move continues from where the first one ended', () {
      final controller = start();
      controller.push(
        _at(at(100, 0)),
        timeline: Duration.zero,
        wallClock: Duration.zero,
        route: RouteTarget(route, 100),
      );
      controller.tick(const Duration(seconds: 2));
      controller.push(
        _at(at(100, 100)),
        timeline: const Duration(seconds: 2),
        wallClock: const Duration(seconds: 2),
        route: RouteTarget(route, 200),
      );

      final middle = controller.tick(const Duration(seconds: 3))!;
      expectNear(middle.position, at(100, 50));
    });

    test('latestOnly starts from the distance it is at', () {
      final controller = start(mode: MarkerAnimationMode.latestOnly);
      controller.push(
        _at(at(100, 100)),
        timeline: Duration.zero,
        wallClock: Duration.zero,
        route: RouteTarget(route, 200),
      );
      // 0.5 s: 50 m along. Then a closer target arrives.
      controller.tick(const Duration(milliseconds: 500));
      controller.push(
        _at(at(100, 0)),
        timeline: const Duration(milliseconds: 500),
        wallClock: const Duration(seconds: 1),
        route: RouteTarget(route, 100),
      );

      final start0 = controller.tick(const Duration(milliseconds: 500))!;
      expectNear(start0.position, at(50, 0));
      final end = controller.tick(const Duration(seconds: 3))!;
      expectNear(end.position, at(100, 0));
    });

    test('starts from the closest point of the route when it was off it', () {
      final controller = _controller(_at(at(40, 5)));
      controller.push(
        _at(at(100, 0)),
        timeline: Duration.zero,
        wallClock: Duration.zero,
        route: RouteTarget(route, 100),
      );

      // Starts at 40 m, so halfway it is at 70 m.
      final middle = controller.tick(_second)!;
      expectNear(middle.position, at(70, 0));
    });

    test('the same distance is not queued twice', () {
      final controller = start();
      final target = RouteTarget(route, 150);
      controller.push(
        _at(at(100, 50)),
        timeline: Duration.zero,
        wallClock: Duration.zero,
        route: target,
      );
      controller.push(
        _at(at(100, 50)),
        timeline: Duration.zero,
        wallClock: Duration.zero,
        route: RouteTarget(route, 150),
      );

      expect(controller.queued, 0);
    });

    test('going back along the route faces the other way', () {
      final controller = start();
      controller.push(
        _at(at(80, 0)),
        timeline: Duration.zero,
        wallClock: Duration.zero,
        route: RouteTarget(route, 80),
      );
      controller.tick(const Duration(seconds: 2));
      controller.push(
        _at(at(40, 0)),
        timeline: const Duration(seconds: 2),
        wallClock: const Duration(seconds: 2),
        route: RouteTarget(route, 40),
      );

      expect(controller.tick(const Duration(seconds: 3))!.rotation,
          closeTo(270, 1e-6));
    });

    test('useMarkerRotation keeps the rotation of the marker', () {
      final controller = start(useMarkerRotation: true);
      controller.push(
        _at(at(100, 0), rotation: 33),
        timeline: Duration.zero,
        wallClock: Duration.zero,
        route: RouteTarget(route, 100),
      );

      expect(controller.tick(_second)!.rotation, 33);
    });

    test('a move without a route leaves the route', () {
      final controller = start();
      controller.push(
        _at(at(100, 0)),
        timeline: Duration.zero,
        wallClock: Duration.zero,
        route: RouteTarget(route, 100),
      );
      controller.tick(const Duration(seconds: 2));
      controller.push(
        _at(at(100, 100)),
        timeline: const Duration(seconds: 2),
        wallClock: const Duration(seconds: 2),
      );

      // A straight line from (100, 0) to (100, 100).
      final middle = controller.tick(const Duration(seconds: 3))!;
      expectNear(middle.position, at(100, 50));
    });
  });
}

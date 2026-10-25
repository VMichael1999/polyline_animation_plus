// `Color.value` is deprecated on new Flutter but is the only way to compare
// colors on the minimum supported version.
// ignore_for_file: deprecated_member_use

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';
import 'package:polyline_animation_plus/src/utils/route_path.dart';
import 'package:polyline_animation_plus/src/utils/spherical_util.dart';

import '../fakes/fake_maps_platform.dart';

const _driver = MarkerId('driver');
const _traveledId = PolylineId('driver#traveled');
const _remainingId = PolylineId('driver#remaining');

/// A point [east] and [north] meters from the origin (on the equator).
LatLng at(double east, double north) {
  const degreesPerMeter = 180 / (pi * SphericalUtil.earthRadius);
  return LatLng(north * degreesPerMeter, east * degreesPerMeter);
}

double meters(LatLng a, LatLng b) =>
    SphericalUtil.computeDistanceBetween(a, b).toDouble();

Future<void> pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 50);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

void main() {
  // 1000 m east, then 1000 m north.
  final route = [at(0, 0), at(1000, 0), at(1000, 1000)];

  late FakeMapsPlatform platform;

  setUp(() {
    platform = FakeMapsPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
  });

  MapAnimationController create(
    WidgetTester tester, {
    Set<Marker> markers = const {},
    Set<AnimatedPolyline> polylines = const {},
  }) =>
      MapAnimationController(
        mapId: 1,
        vsync: tester,
        markers: markers,
        polylines: polylines,
        markerDuration: const MarkerDuration.fixed(Duration(seconds: 1)),
      );

  group('trackVehicle', () {
    testWidgets('draws the whole route and creates the marker at its start', (
      tester,
    ) async {
      final controller = create(tester);
      controller.trackVehicle(VehicleTracking(markerId: _driver, route: route));

      expect(platform.markers[_driver]!.position, route.first);
      expect(platform.polylines.keys, [_remainingId]);
      expect(platform.polylines[_remainingId]!.points.first, route.first);
      expect(platform.polylines[_remainingId]!.points.last, route.last);
      controller.dispose();
    });

    testWidgets('keeps the style of a marker that already exists', (
      tester,
    ) async {
      final controller = create(
        tester,
        markers: {Marker(markerId: _driver, position: route.first, alpha: 0.4)},
      );
      controller.trackVehicle(VehicleTracking(markerId: _driver, route: route));
      controller.updateVehicle(at(500, 0));
      await pumpFor(tester, const Duration(seconds: 2));

      expect(platform.markers[_driver]!.alpha, 0.4);
      controller.dispose();
    });

    testWidgets('uses the styles for the route lines', (tester) async {
      final controller = create(tester);
      controller.trackVehicle(
        VehicleTracking(
          markerId: _driver,
          route: route,
          traveled: const RouteStyle(color: Colors.grey, width: 3),
          remaining: const RouteStyle(color: Colors.blue, width: 8),
        ),
      );
      controller.updateVehicle(at(500, 0));
      await pumpFor(tester, const Duration(seconds: 2));

      expect(platform.polylines[_traveledId]!.color.value, Colors.grey.value);
      expect(platform.polylines[_traveledId]!.width, 3);
      expect(platform.polylines[_remainingId]!.color.value, Colors.blue.value);
      expect(platform.polylines[_remainingId]!.width, 8);
      controller.dispose();
    });

    testWidgets('throws for a route that is not valid', (tester) async {
      final controller = create(tester);
      expect(
        () => controller.trackVehicle(
          VehicleTracking(markerId: _driver, route: [at(0, 0)]),
        ),
        throwsArgumentError,
      );
      controller.dispose();
    });
  });

  group('updateVehicle', () {
    testWidgets('moves the marker onto the route', (tester) async {
      final controller = create(tester);
      controller.trackVehicle(VehicleTracking(markerId: _driver, route: route));

      // 10 m off the road.
      controller.updateVehicle(at(500, 10));
      await pumpFor(tester, const Duration(seconds: 2));

      final position = platform.markers[_driver]!.position;
      expect(meters(position, at(500, 0)), lessThan(0.5));
      controller.dispose();
    });

    testWidgets('consumes the route as the marker advances', (tester) async {
      final controller = create(tester);
      controller.trackVehicle(VehicleTracking(markerId: _driver, route: route));

      controller.updateVehicle(at(500, 0));
      await pumpFor(tester, const Duration(seconds: 2));

      final traveled = platform.polylines[_traveledId]!.points;
      final remaining = platform.polylines[_remainingId]!.points;
      expect(traveled.first, route.first);
      expect(meters(traveled.last, at(500, 0)), lessThan(1));
      expect(meters(remaining.first, at(500, 0)), lessThan(1));
      expect(remaining.last, route.last);
      controller.dispose();
    });

    testWidgets('the traveled part follows the marker, not the GPS', (
      tester,
    ) async {
      final controller = create(tester);
      controller.trackVehicle(VehicleTracking(markerId: _driver, route: route));

      controller.updateVehicle(at(800, 0));
      await pumpFor(tester, const Duration(milliseconds: 500));

      // Halfway through the move the marker is at about 400 m.
      final traveled = platform.polylines[_traveledId]!.points;
      expect(meters(traveled.last, at(400, 0)), lessThan(60));
      expect(meters(traveled.last, at(800, 0)), greaterThan(300));
      controller.dispose();
    });

    testWidgets('hides the traveled part when its style is not visible', (
      tester,
    ) async {
      final controller = create(tester);
      controller.trackVehicle(
        VehicleTracking(
          markerId: _driver,
          route: route,
          traveled: const RouteStyle(color: Colors.grey, visible: false),
        ),
      );
      controller.updateVehicle(at(500, 0));
      await pumpFor(tester, const Duration(seconds: 2));

      expect(platform.polylines.containsKey(_traveledId), isFalse);
      expect(platform.polylines.containsKey(_remainingId), isTrue);
      controller.dispose();
    });

    testWidgets('consumeRoute false keeps one line with the remaining style', (
      tester,
    ) async {
      final controller = create(tester);
      controller.trackVehicle(
        VehicleTracking(
          markerId: _driver,
          route: route,
          consumeRoute: false,
          remaining: const RouteStyle(color: Colors.red),
        ),
      );
      controller.updateVehicle(at(500, 0));
      await pumpFor(tester, const Duration(seconds: 2));

      expect(platform.polylines.keys, [_remainingId]);
      expect(platform.polylines[_remainingId]!.points, hasLength(3));
      expect(platform.polylines[_remainingId]!.color.value, Colors.red.value);
      controller.dispose();
    });

    // From 500 m the vehicle goes to 500 m past the corner. Halfway through
    // that move it is 500 m further, exactly at the corner if it follows the
    // route, or 250 m away from the road if it goes in a straight line.
    Future<double> distanceToRoadHalfwayAroundCorner(
      WidgetTester tester, {
      required bool followRoute,
    }) async {
      final controller = create(tester);
      controller.trackVehicle(
        VehicleTracking(
          markerId: _driver,
          route: route,
          followRoute: followRoute,
        ),
      );
      controller.updateVehicle(at(500, 0));
      await pumpFor(tester, const Duration(milliseconds: 1500));

      controller.updateVehicle(at(1000, 500));
      await pumpFor(tester, const Duration(milliseconds: 500));

      final position = platform.markers[_driver]!.position;
      final distance = RoutePath(route).nearest(position)!.distance;
      controller.dispose();
      return distance;
    }

    testWidgets('followRoute turns at the corner', (tester) async {
      expect(
        await distanceToRoadHalfwayAroundCorner(tester, followRoute: true),
        lessThan(1),
      );
    });

    testWidgets('without followRoute it cuts the corner', (tester) async {
      expect(
        await distanceToRoadHalfwayAroundCorner(tester, followRoute: false),
        greaterThan(100),
      );
    });

    // Drives through the corner and collects the rotations the marker has.
    Future<List<double>> rotationsAroundCorner(
      WidgetTester tester, {
      required double smoothing,
    }) async {
      final controller = create(tester);
      controller.trackVehicle(
        VehicleTracking(
          markerId: _driver,
          route: route,
          followRoute: true,
          turnSmoothingMeters: smoothing,
        ),
      );
      controller.updateVehicle(at(500, 0));
      await pumpFor(tester, const Duration(milliseconds: 1500));

      controller.updateVehicle(at(1000, 500));
      final rotations = <double>[];
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        rotations.add(platform.markers[_driver]!.rotation);
      }
      controller.dispose();
      return rotations;
    }

    testWidgets('the marker turns gradually at a corner by default', (
      tester,
    ) async {
      final rotations = await rotationsAroundCorner(tester, smoothing: 8);

      expect(rotations.any((r) => r > 10 && r < 80), isTrue);
      expect(rotations.first, closeTo(90, 1));
      expect(rotations.last, closeTo(0, 1));
    });

    testWidgets('turnSmoothingMeters 0 turns at once', (tester) async {
      final rotations = await rotationsAroundCorner(tester, smoothing: 0);

      expect(rotations.any((r) => r > 10 && r < 80), isFalse);
      expect(rotations.last, closeTo(0, 1));
    });

    testWidgets('a position far from the route is off route', (tester) async {
      final reported = <LatLng>[];
      final controller = create(tester);
      controller.trackVehicle(
        VehicleTracking(
          markerId: _driver,
          route: route,
          onOffRoute: reported.add,
        ),
      );

      controller.updateVehicle(at(500, 0));
      await pumpFor(tester, const Duration(seconds: 2));
      controller.updateVehicle(at(500, 300));
      await pumpFor(tester, const Duration(seconds: 2));

      expect(reported, [at(500, 300)]);
      // The marker goes where the GPS says, and the route keeps its progress.
      expect(meters(platform.markers[_driver]!.position, at(500, 300)),
          lessThan(1));
      expect(meters(platform.polylines[_traveledId]!.points.last, at(500, 0)),
          lessThan(150));
      controller.dispose();
    });

    testWidgets('the tolerance can be changed', (tester) async {
      final reported = <LatLng>[];
      final controller = create(tester);
      controller.trackVehicle(
        VehicleTracking(
          markerId: _driver,
          route: route,
          snapToleranceMeters: 5,
          onOffRoute: reported.add,
        ),
      );

      controller.updateVehicle(at(500, 10));
      expect(reported, hasLength(1));
      controller.dispose();
    });

    testWidgets('needs a tracked vehicle', (tester) async {
      final controller = create(tester);
      expect(() => controller.updateVehicle(at(0, 0)), throwsStateError);
      controller.dispose();
    });

    testWidgets('needs the markerId when several vehicles are tracked', (
      tester,
    ) async {
      final controller = create(tester);
      controller.trackVehicle(VehicleTracking(markerId: _driver, route: route));
      controller.trackVehicle(
        VehicleTracking(markerId: const MarkerId('other'), route: route),
      );

      expect(() => controller.updateVehicle(at(0, 0)), throwsStateError);
      controller.updateVehicle(at(100, 0), markerId: _driver);
      expect(
        () => controller.updateVehicle(at(0, 0), markerId: const MarkerId('x')),
        throwsStateError,
      );
      await pumpFor(tester, const Duration(seconds: 2));
      controller.dispose();
    });
  });

  group('stopTrackingVehicle', () {
    testWidgets('removes the route and keeps the marker', (tester) async {
      final controller = create(tester);
      controller.trackVehicle(VehicleTracking(markerId: _driver, route: route));
      controller.updateVehicle(at(500, 0));
      await pumpFor(tester, const Duration(seconds: 2));

      controller.stopTrackingVehicle(_driver);

      expect(platform.polylines, isEmpty);
      expect(platform.markers.containsKey(_driver), isTrue);
      expect(() => controller.updateVehicle(at(600, 0)), throwsStateError);
      controller.dispose();
    });

    testWidgets('does nothing for a vehicle that is not tracked', (
      tester,
    ) async {
      final controller = create(tester);
      controller.stopTrackingVehicle(_driver);
      expect(platform.polylines, isEmpty);
      controller.dispose();
    });
  });

  group('together with the rest of the map', () {
    testWidgets('updateMarkers does not move or remove a tracked marker', (
      tester,
    ) async {
      final controller = create(tester);
      controller.trackVehicle(VehicleTracking(markerId: _driver, route: route));
      controller.updateVehicle(at(500, 0));
      await pumpFor(tester, const Duration(seconds: 2));

      controller.updateMarkers({
        const Marker(markerId: MarkerId('other'), position: LatLng(5, 5)),
      });
      await pumpFor(tester, const Duration(seconds: 2));

      expect(
          meters(platform.markers[_driver]!.position, at(500, 0)), lessThan(1));
      expect(platform.markers.containsKey(const MarkerId('other')), isTrue);
      controller.dispose();
    });

    testWidgets('updatePolylines does not remove the route lines', (
      tester,
    ) async {
      final controller = create(tester);
      controller.trackVehicle(VehicleTracking(markerId: _driver, route: route));
      controller.updateVehicle(at(500, 0));
      await pumpFor(tester, const Duration(seconds: 2));

      controller.updatePolylines({});

      expect(platform.polylines.containsKey(_remainingId), isTrue);
      expect(platform.polylines.containsKey(_traveledId), isTrue);
      controller.dispose();
    });

    testWidgets('tracking a vehicle again replaces the previous route', (
      tester,
    ) async {
      final controller = create(tester);
      controller.trackVehicle(VehicleTracking(markerId: _driver, route: route));
      controller.updateVehicle(at(500, 0));
      await pumpFor(tester, const Duration(seconds: 2));

      final shorter = [at(0, 0), at(300, 0)];
      controller
          .trackVehicle(VehicleTracking(markerId: _driver, route: shorter));

      expect(platform.polylines.keys, [_remainingId]);
      expect(platform.polylines[_remainingId]!.points.last, shorter.last);
      controller.dispose();
    });
  });
}

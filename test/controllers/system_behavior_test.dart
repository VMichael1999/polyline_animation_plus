// `Color.value` is deprecated on new Flutter but is the only way to compare
// colors on the minimum supported version.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

import '../fakes/fake_maps_platform.dart';
import '../fakes/geo.dart';

const _id = PolylineId('route');
const _driver = MarkerId('driver');

final _route = [for (var i = 0; i <= 10; i++) at(i * 100.0, 0)];

Polyline get _line => Polyline(
      polylineId: _id,
      color: Colors.blue,
      width: 5,
      points: _route,
    );

const _snack = SnackAnimator(
  duration: Duration(seconds: 4),
  curve: Curves.linear,
);

Future<void> pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 50);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

void main() {
  late FakeMapsPlatform platform;

  setUp(() {
    platform = FakeMapsPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
  });

  MapAnimationController create(
    WidgetTester tester, {
    Set<AnimatedPolyline>? polylines,
    Set<Marker> markers = const {},
    bool pauseInBackground = true,
    bool respectReduceMotion = true,
  }) =>
      MapAnimationController(
        mapId: 1,
        vsync: tester,
        markers: markers,
        polylines: polylines ??
            {AnimatedPolyline(polyline: _line, polylineAnimator: _snack)},
        pauseInBackground: pauseInBackground,
        respectReduceMotion: respectReduceMotion,
        markerDuration: const MarkerDuration.fixed(Duration(seconds: 1)),
      );

  void goToBackground(WidgetTester tester) {
    // Leave the binding as it was even if the test fails.
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  }

  void comeBack(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  void reduceMotion(WidgetTester tester, bool value) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: value);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  group('in the background', () {
    testWidgets('the animations stop and go on from the same place', (
      tester,
    ) async {
      final controller = create(tester);
      final handle = controller.polylineAnimation(_id)!;
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 1));
      expect(handle.value, closeTo(0.25, 0.03));

      goToBackground(tester);
      final frozen = handle.value;
      await pumpFor(tester, const Duration(seconds: 10));
      expect(handle.value, frozen);
      expect(handle.isPlaying, isFalse);

      comeBack(tester);
      expect(handle.isPlaying, isTrue);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(handle.value, closeTo(0.5, 0.03));
      controller.dispose();
    });

    testWidgets('an animation that does not finish while away completes later',
        (
      tester,
    ) async {
      final controller = create(tester);
      final handle = controller.polylineAnimation(_id)!;
      var completed = 0;
      handle.onComplete = () => completed++;
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 3));

      goToBackground(tester);
      await pumpFor(tester, const Duration(seconds: 30));
      expect(completed, 0);

      comeBack(tester);
      await pumpFor(tester, const Duration(milliseconds: 1200));
      expect(completed, 1);
      controller.dispose();
    });

    testWidgets('an animation paused by the app stays paused', (tester) async {
      final controller = create(tester);
      final handle = controller.polylineAnimation(_id)!;
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 1));
      handle.pause();

      goToBackground(tester);
      comeBack(tester);
      await pumpFor(tester, const Duration(seconds: 2));

      expect(handle.isPlaying, isFalse);
      expect(handle.value, closeTo(0.25, 0.03));
      controller.dispose();
    });

    testWidgets('the app pausing while away is not undone by coming back', (
      tester,
    ) async {
      final controller = create(tester);
      final handle = controller.polylineAnimation(_id)!;
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 1));

      goToBackground(tester);
      handle.pause();
      comeBack(tester);
      await pumpFor(tester, const Duration(seconds: 2));

      expect(handle.isPlaying, isFalse);
      handle.resume();
      expect(handle.isPlaying, isTrue);
      controller.dispose();
    });

    testWidgets('a short interruption does not pause', (tester) async {
      final controller = create(tester);
      final handle = controller.polylineAnimation(_id)!;
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await pumpFor(tester, const Duration(seconds: 1));

      expect(handle.value, closeTo(0.5, 0.03));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      controller.dispose();
    });

    testWidgets('pauseInBackground false lets time go by while away', (
      tester,
    ) async {
      final controller = create(tester, pauseInBackground: false);
      final handle = controller.polylineAnimation(_id)!;
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 1));

      // Flutter draws no frames while the app is away, but the animation keeps
      // its clock: on return it has moved on by the time spent away.
      goToBackground(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(handle.isPlaying, isTrue);
      comeBack(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(handle.value, greaterThan(0.45));
      controller.dispose();
    });

    testWidgets('an animation added while away starts when the app returns', (
      tester,
    ) async {
      final controller = create(tester, polylines: {});
      goToBackground(tester);

      controller.updatePolylines({
        AnimatedPolyline(polyline: _line, polylineAnimator: _snack),
      });
      final handle = controller.polylineAnimation(_id)!;
      await pumpFor(tester, const Duration(seconds: 2));
      expect(handle.value, 0);

      comeBack(tester);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(handle.value, closeTo(0.25, 0.04));
      controller.dispose();
    });

    testWidgets('going away twice in a row is harmless', (tester) async {
      final controller = create(tester);
      final handle = controller.polylineAnimation(_id)!;
      await tester.pump();

      goToBackground(tester);
      goToBackground(tester);
      comeBack(tester);
      comeBack(tester);
      await pumpFor(tester, const Duration(seconds: 1));

      expect(handle.isPlaying, isTrue);
      controller.dispose();
    });
  });

  group('when the user asks to reduce motion', () {
    testWidgets('a polyline is drawn as it is and does not animate', (
      tester,
    ) async {
      reduceMotion(tester, true);
      final controller = create(tester);
      await pumpFor(tester, const Duration(seconds: 3));

      final drawn = platform.polylines[_id]!;
      expect(drawn.points, _route);
      expect(drawn.color.value, Colors.blue.value);
      // It stays like this: nothing runs.
      final calls = platform.polylineUpdateCalls;
      await pumpFor(tester, const Duration(seconds: 3));
      expect(platform.polylineUpdateCalls, calls);
      controller.dispose();
    });

    testWidgets('an animation made of several polylines shows the full route', (
      tester,
    ) async {
      reduceMotion(tester, true);
      final controller = create(
        tester,
        polylines: {
          AnimatedPolyline.segmented(
            id: _id,
            points: _route,
            segments: const [
              RouteSegment(from: 0, to: 0.5, color: Colors.green),
              RouteSegment(from: 0.5, to: 1, color: Colors.red),
            ],
            polylineAnimator: _snack,
          ),
        },
      );
      await pumpFor(tester, const Duration(seconds: 1));

      expect(platform.polylines.keys.map((id) => id.value).toSet(), {
        'route#0',
        'route#1',
      });
      expect(platform.polylines[const PolylineId('route#1')]!.points.last,
          _route.last);
      controller.dispose();
    });

    testWidgets('a pulse shows the line without its glow', (tester) async {
      reduceMotion(tester, true);
      final controller = create(
        tester,
        polylines: {
          AnimatedPolyline(
            polyline: _line,
            polylineAnimator: const PulseAnimator(),
          ),
        },
      );
      await pumpFor(tester, const Duration(seconds: 1));

      expect(platform.polylines.keys, [_id]);
      expect(platform.polylines[_id]!.color.value, Colors.blue.value);
      controller.dispose();
    });

    testWidgets('asking while an animation runs stops it', (tester) async {
      final controller = create(tester);
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 1));
      expect(platform.polylines[_id]!.points.length, lessThan(_route.length));

      reduceMotion(tester, true);
      await tester.pump();

      expect(platform.polylines[_id]!.points, _route);
      final calls = platform.polylineUpdateCalls;
      await pumpFor(tester, const Duration(seconds: 2));
      expect(platform.polylineUpdateCalls, calls);
      controller.dispose();
    });

    testWidgets('stopping asking makes the animation go on', (tester) async {
      reduceMotion(tester, true);
      final controller = create(tester);
      final handle = controller.polylineAnimation(_id)!;
      await pumpFor(tester, const Duration(seconds: 1));
      expect(handle.isPlaying, isFalse);

      reduceMotion(tester, false);
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 1));

      expect(handle.isPlaying, isTrue);
      expect(handle.value, closeTo(0.25, 0.04));
      controller.dispose();
    });

    testWidgets('the handle cannot make it play meanwhile', (tester) async {
      reduceMotion(tester, true);
      final controller = create(tester);
      final handle = controller.polylineAnimation(_id)!;

      handle.resume();
      await pumpFor(tester, const Duration(seconds: 1));

      expect(handle.value, 0);
      controller.dispose();
    });

    testWidgets('a polyline update is drawn as it is too', (tester) async {
      reduceMotion(tester, true);
      final controller = create(tester);

      controller.updatePolylines({
        AnimatedPolyline(
          polyline: _line.copyWith(colorParam: Colors.red),
          polylineAnimator: _snack,
        ),
      });

      expect(platform.polylines[_id]!.color.value, Colors.red.value);
      controller.dispose();
    });

    testWidgets('markers go to their new position at once', (tester) async {
      reduceMotion(tester, true);
      final controller = create(
        tester,
        polylines: {},
        markers: {Marker(markerId: _driver, position: at(0, 0))},
      );

      controller
          .updateMarkers({Marker(markerId: _driver, position: at(500, 0))});

      expect(platform.markers[_driver]!.position, at(500, 0));
      controller.dispose();
    });

    testWidgets('a vehicle goes to its place at once', (tester) async {
      reduceMotion(tester, true);
      final controller = create(tester, polylines: {});
      controller.trackVehicle(
        VehicleTracking(
          markerId: _driver,
          route: [at(0, 0), at(1000, 0)],
          followRoute: true,
        ),
      );

      controller.updateVehicle(at(400, 5));

      expect(metersBetween(platform.markers[_driver]!.position, at(400, 0)),
          lessThan(0.5));
      controller.dispose();
    });

    testWidgets('respectReduceMotion false keeps animating', (tester) async {
      reduceMotion(tester, true);
      final controller = create(
        tester,
        respectReduceMotion: false,
        markers: {Marker(markerId: _driver, position: at(0, 0))},
      );
      final handle = controller.polylineAnimation(_id)!;
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 1));
      expect(handle.isPlaying, isTrue);

      controller
          .updateMarkers({Marker(markerId: _driver, position: at(500, 0))});
      expect(platform.markers[_driver]!.position, isNot(at(500, 0)));
      controller.dispose();
    });

    testWidgets('moves are animated again when it stops', (tester) async {
      reduceMotion(tester, true);
      final controller = create(
        tester,
        polylines: {},
        markers: {Marker(markerId: _driver, position: at(0, 0))},
      );
      reduceMotion(tester, false);
      await tester.pump();

      controller
          .updateMarkers({Marker(markerId: _driver, position: at(500, 0))});
      await tester.pump();
      await pumpFor(tester, const Duration(milliseconds: 400));

      final east = metersOf(platform.markers[_driver]!.position).east;
      expect(east, greaterThan(100));
      expect(east, lessThan(450));
      controller.dispose();
    });
  });

  testWidgets('dispose stops listening to the system', (tester) async {
    final controller = create(tester);
    controller.dispose();

    // No error when the system reports changes afterwards.
    goToBackground(tester);
    comeBack(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';
import 'package:polyline_animation_plus/src/controllers/camera_follower.dart';

import '../fakes/fake_maps_platform.dart';
import '../fakes/geo.dart';

const _car = MarkerId('car');

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

  /// Draws the rotation as the alpha and removes the rotation, like an app
  /// that has an icon for every direction would.
  Marker byDirection(Marker marker) => marker.copyWith(
        alphaParam: ((marker.rotation % 360) + 360) % 360 / 360,
        rotationParam: 0,
      );

  MapAnimationController create(
    WidgetTester tester, {
    MarkerFrameBuilder? builder,
    MarkerListener? listener,
  }) =>
      MapAnimationController(
        mapId: 1,
        vsync: tester,
        markers: {Marker(markerId: _car, position: at(0, 0))},
        markerFrameBuilder: builder,
        markerListener: listener,
        markerDuration: const MarkerDuration.fixed(Duration(seconds: 1)),
      );

  testWidgets('the markers that are given first are changed too', (
    tester,
  ) async {
    final controller = create(
      tester,
      builder: (m) => m.copyWith(alphaParam: 0.5),
    );

    expect(platform.markers[_car]!.alpha, 0.5);
    controller.dispose();
  });

  testWidgets('every frame of the animation goes through the builder', (
    tester,
  ) async {
    final seen = <double>[];
    final controller = create(
      tester,
      builder: (m) {
        seen.add(m.rotation);
        return byDirection(m);
      },
    );

    // Going east: the rotation goes from 0 to 90 during the move.
    controller.updateMarkers({Marker(markerId: _car, position: at(100, 0))});
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 500));

    // Halfway the rotation is 45, so the alpha is 45 / 360.
    expect(platform.markers[_car]!.alpha, closeTo(45 / 360, 0.03));
    expect(platform.markers[_car]!.rotation, 0);
    expect(seen.any((r) => r > 10 && r < 80), isTrue);

    await pumpFor(tester, const Duration(milliseconds: 700));
    expect(platform.markers[_car]!.alpha, closeTo(90 / 360, 1e-6));
    controller.dispose();
  });

  testWidgets('the listener gets the marker as the animation computed it', (
    tester,
  ) async {
    final heard = <Marker>[];
    final controller = create(
      tester,
      builder: byDirection,
      listener: (markers) => heard.addAll(markers),
    );

    controller.updateMarkers({Marker(markerId: _car, position: at(100, 0))});
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 1200));

    expect(heard.last.rotation, closeTo(90, 1e-6));
    expect(heard.last.alpha, 1);
    controller.dispose();
  });

  testWidgets('without a builder markers are drawn as they are',
      (tester) async {
    final controller = create(tester);

    controller.updateMarkers({Marker(markerId: _car, position: at(100, 0))});
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 1200));

    expect(platform.markers[_car]!.rotation, closeTo(90, 1e-6));
    controller.dispose();
  });

  testWidgets('the camera and the tracked vehicle use the unchanged marker', (
    tester,
  ) async {
    final realClock = CameraFollower.createClock;
    addTearDown(() => CameraFollower.createClock = realClock);
    final start = tester.binding.clock.now();
    CameraFollower.createClock =
        () => () => tester.binding.clock.now().difference(start);

    final controller = create(tester, builder: byDirection);
    controller.trackVehicle(
      VehicleTracking(
        markerId: _car,
        route: [at(0, 0), at(1000, 0)],
        followRoute: true,
      ),
    );
    controller.followCamera(
      const CameraFollow(
        markerId: _car,
        bearing: CameraBearing.vehicle,
        bearingLag: Duration.zero,
      ),
    );
    platform.cameraMoves.clear();

    controller.updateVehicle(at(400, 3));
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 1300));

    // The marker drawn has no rotation, but the camera still turns to 90.
    expect(platform.markers[_car]!.rotation, 0);
    final camera = (platform.cameraMoves.last as List<Object?>).last! as Map;
    expect(camera['bearing'], closeTo(90, 1e-6));
    controller.dispose();
  });

  testWidgets('a removed marker is no longer built', (tester) async {
    var calls = 0;
    final controller = create(
      tester,
      builder: (m) {
        calls++;
        return m;
      },
    );
    controller.updateMarkers({});
    final callsAtRemoval = calls;

    await pumpFor(tester, const Duration(seconds: 1));

    expect(platform.markers, isEmpty);
    expect(calls, callsAtRemoval);
    controller.dispose();
  });
}

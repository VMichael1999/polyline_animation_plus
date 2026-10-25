import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

import 'package:polyline_animation_plus/src/controllers/camera_follower.dart';

import '../fakes/fake_maps_platform.dart';
import '../fakes/geo.dart';

const _driver = MarkerId('driver');

Marker _marker(LatLng position) =>
    Marker(markerId: _driver, position: position);

Future<void> pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 20);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

/// The camera position of a recorded move.
Map<String, Object?> cameraOf(Object move) {
  final json = move as List<Object?>;
  expect(json.first, 'newCameraPosition');
  return Map<String, Object?>.from(json.last! as Map);
}

LatLng targetOf(Object move) {
  final target = cameraOf(move)['target']! as List<Object?>;
  return LatLng(target[0]! as double, target[1]! as double);
}

void main() {
  late FakeMapsPlatform platform;

  final realClock = CameraFollower.createClock;

  setUp(() {
    platform = FakeMapsPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
  });

  tearDown(() => CameraFollower.createClock = realClock);

  MapAnimationController create(
    WidgetTester tester, {
    Set<Marker>? markers,
  }) {
    // The clock of the test, so that pumping moves it.
    final start = tester.binding.clock.now();
    CameraFollower.createClock =
        () => () => tester.binding.clock.now().difference(start);

    return MapAnimationController(
      mapId: 1,
      vsync: tester,
      markers: markers ?? {_marker(at(0, 0))},
      markerDuration: const MarkerDuration.fixed(Duration(seconds: 1)),
    );
  }

  testWidgets('goes to the marker as soon as it starts following', (
    tester,
  ) async {
    final controller = create(tester);
    controller.followCamera(
      const CameraFollow(markerId: _driver, zoom: 16, tilt: 40),
    );

    expect(platform.cameraMoves, hasLength(1));
    final camera = cameraOf(platform.cameraMoves.single);
    expect(camera['zoom'], 16);
    expect(camera['tilt'], 40);
    expect(camera['bearing'], 0);
    expect(targetOf(platform.cameraMoves.single), at(0, 0));
    controller.dispose();
  });

  testWidgets('follows the marker, at most ten times per second', (
    tester,
  ) async {
    final controller = create(tester);
    controller.followCamera(const CameraFollow(markerId: _driver));
    platform.cameraMoves.clear();

    controller.updateMarkers({_marker(at(100, 0))});
    await tester.pump();
    await pumpFor(tester, const Duration(seconds: 1));
    await pumpFor(tester, const Duration(milliseconds: 200));

    expect(platform.cameraMoves.length, lessThanOrEqualTo(12));
    expect(platform.cameraMoves.length, greaterThanOrEqualTo(6));
    // It does not stay behind: the last move is at the final position.
    expect(metersBetween(targetOf(platform.cameraMoves.last), at(100, 0)),
        lessThan(0.5));
    controller.dispose();
  });

  testWidgets('turns with the vehicle when asked to', (tester) async {
    final controller = create(tester);
    controller.followCamera(
      const CameraFollow(
        markerId: _driver,
        bearing: CameraBearing.vehicle,
        bearingLag: Duration.zero,
      ),
    );
    platform.cameraMoves.clear();

    // Going east: the rotation of the marker ends at 90.
    controller.updateMarkers({_marker(at(100, 0))});
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 1300));

    expect(cameraOf(platform.cameraMoves.last)['bearing'], closeTo(90, 1e-6));
    controller.dispose();
  });

  group('bearing lag', () {
    double bearingOf(Object move) => cameraOf(move)['bearing']! as double;

    testWidgets('the map turns after the vehicle', (tester) async {
      final controller = create(tester);
      controller.followCamera(
        const CameraFollow(
          markerId: _driver,
          bearing: CameraBearing.vehicle,
          bearingLag: Duration(milliseconds: 600),
        ),
      );
      platform.cameraMoves.clear();

      // The marker turns from 0 to 90 during one second.
      controller.updateMarkers({_marker(at(100, 0))});
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 1));

      // The vehicle has finished turning but the map is still catching up.
      expect(bearingOf(platform.cameraMoves.last), lessThan(80));
      expect(bearingOf(platform.cameraMoves.last), greaterThan(20));
      controller.dispose();
    });

    testWidgets('and it catches up even if the marker stops', (tester) async {
      final controller = create(tester);
      controller.followCamera(
        const CameraFollow(
          markerId: _driver,
          bearing: CameraBearing.vehicle,
          bearingLag: Duration(milliseconds: 600),
        ),
      );
      platform.cameraMoves.clear();

      controller.updateMarkers({_marker(at(100, 0))});
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 6));

      expect(bearingOf(platform.cameraMoves.last), closeTo(90, 0.6));

      // Once there it stops sending updates.
      final moves = platform.cameraMoves.length;
      await pumpFor(tester, const Duration(seconds: 2));
      expect(platform.cameraMoves.length, moves);
      controller.dispose();
    });

    testWidgets('never goes the long way round', (tester) async {
      final updates = <CameraUpdate>[];
      var time = Duration.zero;
      final follower = CameraFollower(
        follow: const CameraFollow(
          markerId: _driver,
          bearing: CameraBearing.vehicle,
          bearingLag: Duration(milliseconds: 600),
        ),
        moveCamera: updates.add,
        now: () => time,
      );

      follower.onMarker(
        Marker(markerId: _driver, position: at(0, 0), rotation: 350),
      );
      time = const Duration(milliseconds: 200);
      follower.onMarker(
        Marker(markerId: _driver, position: at(0, 0), rotation: 10),
      );
      follower.dispose();

      final bearings = [
        for (final update in updates) bearingOf(update.toJson()),
      ];
      expect(bearings.first, 350);
      // 20 degrees to turn, through north: just past 350 and not near 180.
      expect(bearings.last, inInclusiveRange(350, 360));
    });

    testWidgets('with no lag the map follows at once', (tester) async {
      final updates = <CameraUpdate>[];
      var time = Duration.zero;
      final follower = CameraFollower(
        follow: const CameraFollow(
          markerId: _driver,
          bearing: CameraBearing.vehicle,
          bearingLag: Duration.zero,
        ),
        moveCamera: updates.add,
        now: () => time,
      );

      follower.onMarker(
        Marker(markerId: _driver, position: at(0, 0), rotation: 20),
      );
      time = const Duration(milliseconds: 200);
      follower.onMarker(
        Marker(markerId: _driver, position: at(0, 0), rotation: 200),
      );
      follower.dispose();

      expect(bearingOf(updates.last.toJson()), 200);
    });

    testWidgets('north up is not affected by the lag', (tester) async {
      final controller = create(tester);
      controller.followCamera(
        const CameraFollow(
          markerId: _driver,
          bearingLag: Duration(seconds: 2),
        ),
      );
      platform.cameraMoves.clear();

      controller.updateMarkers({_marker(at(100, 0))});
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 2));

      expect(
        platform.cameraMoves.map((m) => cameraOf(m)['bearing']).toSet(),
        {0},
      );
      controller.dispose();
    });
  });

  testWidgets('keeps north up by default', (tester) async {
    final controller = create(tester);
    controller.followCamera(const CameraFollow(markerId: _driver));
    platform.cameraMoves.clear();

    controller.updateMarkers({_marker(at(100, 0))});
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 1300));

    expect(
      platform.cameraMoves.map((m) => cameraOf(m)['bearing']).toSet(),
      {0},
    );
    controller.dispose();
  });

  testWidgets('stopFollowingCamera stops it without telling the app', (
    tester,
  ) async {
    var stopped = 0;
    final controller = create(tester);
    controller.followCamera(
      CameraFollow(markerId: _driver, onFollowStopped: () => stopped++),
    );
    controller.stopFollowingCamera();
    platform.cameraMoves.clear();

    controller.updateMarkers({_marker(at(100, 0))});
    await pumpFor(tester, const Duration(seconds: 2));

    expect(platform.cameraMoves, isEmpty);
    expect(stopped, 0);
    controller.dispose();
  });

  group('when the user moves the map', () {
    testWidgets('stops following and tells the app', (tester) async {
      var stopped = 0;
      final controller = create(tester);
      controller.followCamera(
        CameraFollow(markerId: _driver, onFollowStopped: () => stopped++),
      );

      // The camera has been quiet for a while, so this is the user.
      await pumpFor(tester, const Duration(seconds: 1));
      controller.onCameraMoveStarted();

      expect(stopped, 1);
      platform.cameraMoves.clear();
      controller.updateMarkers({_marker(at(100, 0))});
      await pumpFor(tester, const Duration(seconds: 2));
      expect(platform.cameraMoves, isEmpty);

      // And it is only reported once.
      controller.onCameraMoveStarted();
      expect(stopped, 1);
      controller.dispose();
    });

    testWidgets('ignores the movement that its own update causes', (
      tester,
    ) async {
      var stopped = 0;
      final controller = create(tester);
      controller.followCamera(
        CameraFollow(markerId: _driver, onFollowStopped: () => stopped++),
      );

      // The map reports the move that was just made.
      controller.onCameraMoveStarted();
      await tester.pump(const Duration(milliseconds: 50));
      controller.onCameraMoveStarted();

      expect(stopped, 0);
      platform.cameraMoves.clear();
      controller.updateMarkers({_marker(at(100, 0))});
      await pumpFor(tester, const Duration(seconds: 2));
      expect(platform.cameraMoves, isNotEmpty);
      controller.dispose();
    });

    testWidgets('does nothing when the camera is not following', (
      tester,
    ) async {
      final controller = create(tester);
      controller.onCameraMoveStarted();
      expect(platform.cameraMoves, isEmpty);
      controller.dispose();
    });
  });

  testWidgets('follows a marker that appears later', (tester) async {
    final controller = create(tester, markers: const {});
    controller.followCamera(const CameraFollow(markerId: _driver));
    expect(platform.cameraMoves, isEmpty);

    controller.updateMarkers({_marker(at(50, 50))});

    expect(platform.cameraMoves, hasLength(1));
    expect(targetOf(platform.cameraMoves.single), at(50, 50));
    controller.dispose();
  });

  testWidgets('follows the marker of a tracked vehicle', (tester) async {
    final controller = create(tester);
    controller.trackVehicle(
      VehicleTracking(
        markerId: _driver,
        route: [at(0, 0), at(1000, 0)],
        followRoute: true,
      ),
    );
    controller.followCamera(const CameraFollow(markerId: _driver));
    platform.cameraMoves.clear();

    controller.updateVehicle(at(500, 3));
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 1300));

    expect(metersBetween(targetOf(platform.cameraMoves.last), at(500, 0)),
        lessThan(1));
    controller.dispose();
  });

  testWidgets('following another marker replaces the first one', (
    tester,
  ) async {
    const other = MarkerId('other');
    final controller = create(
      tester,
      markers: {_marker(at(0, 0)), Marker(markerId: other, position: at(9, 9))},
    );
    controller.followCamera(const CameraFollow(markerId: _driver));
    controller.followCamera(const CameraFollow(markerId: other));
    platform.cameraMoves.clear();

    controller.updateMarkers({
      _marker(at(100, 0)),
      Marker(markerId: other, position: at(9, 9)),
    });
    await pumpFor(tester, const Duration(seconds: 2));

    // The first marker moved but the camera did not go after it.
    expect(platform.cameraMoves, isEmpty);
    controller.dispose();
  });

  testWidgets('dispose leaves no pending work', (tester) async {
    final controller = create(tester);
    controller.followCamera(const CameraFollow(markerId: _driver));
    controller.updateMarkers({_marker(at(100, 0))});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    controller.dispose();
    platform.cameraMoves.clear();
    await pumpFor(tester, const Duration(seconds: 2));

    expect(platform.cameraMoves, isEmpty);
  });

  test('CameraFollow has sensible defaults', () {
    const follow = CameraFollow(markerId: _driver);
    expect(follow.bearingLag, const Duration(milliseconds: 600));
    expect(follow.zoom, 17);
    expect(follow.tilt, 0);
    expect(follow.bearing, CameraBearing.north);
    expect(follow.onFollowStopped, isNull);
  });
}

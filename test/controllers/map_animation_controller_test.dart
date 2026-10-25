import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

import '../fakes/fake_maps_platform.dart';

const _mapId = 7;
const _a = MarkerId('a');
const _b = MarkerId('b');
const _p1 = PolylineId('p1');
const _p2 = PolylineId('p2');

const _path = [LatLng(0, 0), LatLng(0, 1), LatLng(0, 2), LatLng(0, 3)];

Polyline _line(PolylineId id) =>
    Polyline(polylineId: id, color: Colors.blue, points: _path);

Marker _marker(MarkerId id, LatLng position) =>
    Marker(markerId: id, position: position);

void main() {
  late FakeMapsPlatform platform;

  setUp(() {
    platform = FakeMapsPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
  });

  MapAnimationController create(
    WidgetTester tester, {
    Set<Marker> markers = const {},
    Set<AnimatedPolyline> polylines = const {},
    MarkerListener? markerListener,
  }) =>
      MapAnimationController(
        mapId: _mapId,
        vsync: tester,
        markers: markers,
        polylines: polylines,
        markerListener: markerListener,
      );

  group('initial state', () {
    testWidgets('sends markers and static polylines to the map', (
      tester,
    ) async {
      final controller = create(
        tester,
        markers: {_marker(_a, const LatLng(1, 1))},
        polylines: {AnimatedPolyline(polyline: _line(_p1))},
      );

      expect(platform.markers.keys, [_a]);
      expect(platform.polylines.keys, [_p1]);
      expect(platform.mapIds, {_mapId});
      controller.dispose();
    });

    testWidgets('draws an animated polyline frame by frame', (tester) async {
      final controller = create(
        tester,
        polylines: {
          AnimatedPolyline(
            polyline: _line(_p1),
            polylineAnimator: const SnackAnimator(
              duration: Duration(seconds: 2),
              curve: Curves.linear,
            ),
          ),
        },
      );
      expect(platform.polylines, isEmpty);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(platform.polylines[_p1]!.points, hasLength(2));

      await tester.pump(const Duration(milliseconds: 500));
      expect(platform.polylines[_p1]!.points, hasLength(4));
      controller.dispose();
    });
  });

  group('markers', () {
    testWidgets('a new marker appears immediately', (tester) async {
      final controller = create(tester);
      controller.updateMarkers({_marker(_a, const LatLng(1, 1))});

      expect(platform.markers[_a]!.position, const LatLng(1, 1));
      controller.dispose();
    });

    testWidgets('moves a marker smoothly to its new position', (tester) async {
      final updates = <Set<Marker>>[];
      final controller = create(
        tester,
        markers: {_marker(_a, const LatLng(0, 0))},
        markerListener: updates.add,
      );

      controller.updateMarkers({_marker(_a, const LatLng(0, 1))});
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final midway = platform.markers[_a]!.position;
      expect(midway.longitude, inInclusiveRange(0.4, 0.6));
      expect(updates, isNotEmpty);

      await tester.pump(const Duration(seconds: 1));
      expect(platform.markers[_a]!.position.longitude, closeTo(1, 1e-9));
      controller.dispose();
    });

    testWidgets('removes markers that are no longer present', (tester) async {
      final controller = create(
        tester,
        markers: {
          _marker(_a, const LatLng(0, 0)),
          _marker(_b, const LatLng(1, 1)),
        },
      );

      controller.updateMarkers({_marker(_a, const LatLng(0, 0))});

      expect(platform.markers.keys, [_a]);
      controller.dispose();
    });

    testWidgets('defers removal while an animation is running', (
      tester,
    ) async {
      final controller = create(
        tester,
        markers: {
          _marker(_a, const LatLng(0, 0)),
          _marker(_b, const LatLng(1, 1)),
        },
      );

      controller.updateMarkers({
        _marker(_a, const LatLng(0, 1)),
        _marker(_b, const LatLng(1, 1)),
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // b is removed while the animation is running.
      controller.updateMarkers({_marker(_a, const LatLng(0, 1))});
      expect(platform.markers.keys, containsAll([_a, _b]));

      await tester.pump(const Duration(seconds: 2));
      expect(platform.markers.keys, [_a]);
      controller.dispose();
    });
  });

  group('polylines', () {
    testWidgets('updates a static polyline directly', (tester) async {
      final controller = create(tester);
      controller.updatePolylines({AnimatedPolyline(polyline: _line(_p1))});

      expect(platform.polylines.keys, [_p1]);
      controller.dispose();
    });

    testWidgets('removes polylines that are no longer present', (tester) async {
      final controller = create(
        tester,
        polylines: {
          AnimatedPolyline(polyline: _line(_p1)),
          AnimatedPolyline(polyline: _line(_p2)),
        },
      );

      controller.updatePolylines({AnimatedPolyline(polyline: _line(_p1))});

      expect(platform.polylines.keys, [_p1]);
      controller.dispose();
    });

    testWidgets('stops animating a polyline that becomes static', (
      tester,
    ) async {
      final controller = create(
        tester,
        polylines: {
          AnimatedPolyline(
            polyline: _line(_p1),
            polylineAnimator: const SnackAnimator(
              duration: Duration(seconds: 2),
              repeat: true,
            ),
          ),
        },
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      controller.updatePolylines({AnimatedPolyline(polyline: _line(_p1))});
      final callsAfterSwitch = platform.polylineUpdateCalls;
      await tester.pump(const Duration(seconds: 1));

      expect(platform.polylineUpdateCalls, callsAfterSwitch);
      expect(platform.polylines[_p1]!.points, _path);
      controller.dispose();
    });

    testWidgets('removes an animated polyline before its first frame', (
      tester,
    ) async {
      final controller = create(
        tester,
        polylines: {
          AnimatedPolyline(
            polyline: _line(_p1),
            polylineAnimator: const SnackAnimator(
              duration: Duration(seconds: 2),
              repeat: true,
            ),
          ),
        },
      );

      // No frame has been drawn yet, so the map does not know the polyline.
      controller.updatePolylines({});
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(platform.polylines, isEmpty);
      controller.dispose();
    });

    testWidgets('updateStaticPolyline draws the given polyline', (
      tester,
    ) async {
      final controller = create(tester);
      controller.updateStaticPolyline(_line(_p2));

      expect(platform.polylines.keys, [_p2]);
      controller.dispose();
    });
  });

  testWidgets('dispose stops all updates', (tester) async {
    final controller = create(
      tester,
      polylines: {
        AnimatedPolyline(
          polyline: _line(_p1),
          polylineAnimator: const SnackAnimator(
            duration: Duration(seconds: 2),
            repeat: true,
          ),
        ),
      },
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    controller.dispose();
    final calls = platform.polylineUpdateCalls;
    await tester.pump(const Duration(seconds: 1));

    expect(platform.polylineUpdateCalls, calls);
  });
}

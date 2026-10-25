import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

import '../fakes/fake_maps_platform.dart';

const _id = PolylineId('p');
const _extraId = PolylineId('p#extra');

/// Draws the polyline and an extra one on top, except in the second half of
/// the cycle when it draws only the polyline.
class _WithExtra extends PolylineAnimator {
  const _WithExtra()
      : super(duration: const Duration(seconds: 2), repeat: true);

  @override
  Polyline animate(Polyline polyline, double progress) => polyline;

  @override
  List<Polyline> animateAll(Polyline polyline, double progress) => [
        animate(polyline, progress),
        if (progress < 0.5)
          Polyline(
            polylineId: _extraId,
            points: polyline.points,
            color: Colors.red,
          ),
      ];
}

const _line = Polyline(
  polylineId: _id,
  points: [LatLng(0, 0), LatLng(0, 1)],
);

void main() {
  late FakeMapsPlatform platform;

  setUp(() {
    platform = FakeMapsPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
  });

  MapAnimationController create(WidgetTester tester) => MapAnimationController(
        mapId: 1,
        vsync: tester,
        polylines: {
          const AnimatedPolyline(
              polyline: _line, polylineAnimator: _WithExtra()),
        },
      );

  testWidgets('draws the polyline and its extra polylines', (tester) async {
    final controller = create(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(platform.polylines.keys, containsAll([_id, _extraId]));
    controller.dispose();
  });

  testWidgets('removes an extra polyline when the animation stops drawing it', (
    tester,
  ) async {
    final controller = create(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(platform.polylines.containsKey(_extraId), isTrue);

    // 1.5 s: past the first half of the 2 s cycle.
    await tester.pump(const Duration(seconds: 1));

    expect(platform.polylines.containsKey(_extraId), isFalse);
    expect(platform.polylines.containsKey(_id), isTrue);
    controller.dispose();
  });

  testWidgets('updatePolylines with the same polyline keeps the extras', (
    tester,
  ) async {
    final controller = create(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    controller.updatePolylines({
      const AnimatedPolyline(polyline: _line, polylineAnimator: _WithExtra()),
    });
    await tester.pump(const Duration(milliseconds: 100));

    expect(platform.polylines.keys, containsAll([_id, _extraId]));
    controller.dispose();
  });

  testWidgets('removing the polyline removes its extras too', (tester) async {
    final controller = create(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    controller.updatePolylines({});
    await tester.pump(const Duration(seconds: 1));

    expect(platform.polylines, isEmpty);
    controller.dispose();
  });

  testWidgets('making the polyline static removes its extras', (tester) async {
    final controller = create(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    controller.updatePolylines({const AnimatedPolyline(polyline: _line)});
    await tester.pump(const Duration(seconds: 1));

    expect(platform.polylines.keys, [_id]);
    controller.dispose();
  });
}

// `Color.alpha` and `Color.value` are deprecated on new Flutter but are the only
// options on the minimum supported version.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

import '../fakes/fake_maps_platform.dart';
import '../fakes/geo.dart';

const _green = Color(0xFF1E9E5A);
const _amber = Color(0xFFF2A900);
const _red = Color(0xFFE53935);

const _segments = [
  RouteSegment(from: 0.00, to: 0.35, color: _green),
  RouteSegment(from: 0.35, to: 0.60, color: _amber),
  RouteSegment(from: 0.60, to: 0.80, color: _red),
  RouteSegment(from: 0.80, to: 1.00, color: _green),
];

/// A route of 1000 m with a point every 100 m.
List<LatLng> _route() => [for (var i = 0; i <= 10; i++) at(i * 100.0, 0)];

AnimatedPolyline segmented({PolylineAnimator? animator}) =>
    AnimatedPolyline.segmented(
      id: const PolylineId('route'),
      points: _route(),
      segments: _segments,
      polylineAnimator: animator,
      width: 7,
    );

List<Polyline> framesAt(AnimatedPolyline animated, double progress) =>
    animated.polylineAnimator!.animateAll(animated.polyline, progress);

double eastOf(LatLng p) => metersOf(p).east;

void main() {
  group('AnimatedPolyline.segmented', () {
    test('draws one polyline per segment with derived IDs', () {
      final frame = framesAt(segmented(), 1);

      expect(frame.map((p) => p.polylineId.value), [
        'route#0',
        'route#1',
        'route#2',
        'route#3',
      ]);
      expect(frame.map((p) => p.color.value), [
        _green.value,
        _amber.value,
        _red.value,
        _green.value,
      ]);
      expect(frame.every((p) => p.width == 7), isTrue);
    });

    test('each segment covers its part of the route', () {
      final frame = framesAt(segmented(), 1);

      expect(eastOf(frame[1].points.first), closeTo(350, 0.5));
      expect(eastOf(frame[1].points.last), closeTo(600, 0.5));
      // The corner at 400 m and 500 m are inside the second segment.
      expect(frame[1].points, hasLength(4));
    });

    test('consecutive segments share the point where they meet', () {
      final frame = framesAt(segmented(), 1);

      for (var i = 0; i < frame.length - 1; i++) {
        expect(frame[i].points.last, frame[i + 1].points.first);
      }
      expect(frame.first.points.first, _route().first);
      expect(frame.last.points.last, _route().last);
    });

    test('the part no segment covers is not drawn', () {
      final animated = AnimatedPolyline.segmented(
        id: const PolylineId('gap'),
        points: _route(),
        segments: const [
          RouteSegment(from: 0, to: 0.3, color: _green),
          RouteSegment(from: 0.5, to: 1, color: _red),
        ],
      );
      final frame = framesAt(animated, 1);

      expect(frame, hasLength(2));
      expect(eastOf(frame[0].points.last), closeTo(300, 0.5));
      expect(eastOf(frame[1].points.first), closeTo(500, 0.5));
    });

    test('needs at least one segment', () {
      expect(
        () => AnimatedPolyline.segmented(
          id: const PolylineId('x'),
          points: _route(),
          segments: const [],
        ),
        throwsArgumentError,
      );
    });

    test('a segment must be inside the route', () {
      expect(
        () => RouteSegment(from: 0.5, to: 0.5, color: _red),
        throwsAssertionError,
      );
      expect(
        () => RouteSegment(from: -0.1, to: 0.5, color: _red),
        throwsAssertionError,
      );
      expect(
        () => RouteSegment(from: 0.1, to: 1.5, color: _red),
        throwsAssertionError,
      );
    });

    test('a route without two different points draws what it has', () {
      final animated = AnimatedPolyline.segmented(
        id: const PolylineId('s'),
        points: const [LatLng(1, 1), LatLng(1, 1)],
        segments: _segments,
      );
      expect(framesAt(animated, 1), hasLength(1));
    });

    test('is equal to another with the same data', () {
      expect(segmented(), segmented());
      expect(
        segmented(animator: const SnackAnimator()),
        segmented(animator: const SnackAnimator()),
      );
      expect(segmented().hashCode, segmented().hashCode);
      expect(segmented(), isNot(segmented(animator: const SnackAnimator())));
      expect(
        segmented(),
        isNot(
          AnimatedPolyline.segmented(
            id: const PolylineId('route'),
            points: _route(),
            segments: const [RouteSegment(from: 0, to: 1, color: _red)],
            width: 7,
          ),
        ),
      );
    });

    test('takes the settings of the animator it wraps', () {
      final animator = segmented(
        animator: const SnackAnimator(
          duration: Duration(seconds: 3),
          repeat: true,
          repeatCount: 2,
          reverse: true,
          delayStart: Duration(seconds: 1),
          delayEnd: Duration(seconds: 2),
          curve: Curves.easeIn,
        ),
      ).polylineAnimator!;

      expect(animator.duration, const Duration(seconds: 3));
      expect(animator.repeat, isTrue);
      expect(animator.repeatCount, 2);
      expect(animator.reverse, isTrue);
      expect(animator.delayStart, const Duration(seconds: 1));
      expect(animator.delayEnd, const Duration(seconds: 2));
      expect(animator.curve, Curves.easeIn);
    });

    test('without an animator it has no duration', () {
      expect(segmented().polylineAnimator!.duration, Duration.zero);
      expect(segmented().polylineAnimator!.repeat, isFalse);
    });
  });

  group('with a progressive animator', () {
    final snack = segmented(animator: const SnackAnimator());

    test('draws the route across the segments', () {
      // 11 points, progress 0.25: the first half of the points are drawn up to
      // the point at 500 m.
      final frame = framesAt(snack, 0.25);

      expect(frame.map((p) => p.polylineId.value), ['route#0', 'route#1']);
      expect(eastOf(frame[0].points.last), closeTo(350, 0.5));
      expect(eastOf(frame[1].points.last), closeTo(500, 0.5));
    });

    test('segments that are not reached yet are not drawn', () {
      // 11 points * 0.1 * 2 = 2 points: up to 100 m.
      final frame = framesAt(snack, 0.1);
      expect(frame.map((p) => p.polylineId.value), ['route#0']);
      expect(eastOf(frame[0].points.last), closeTo(100, 0.5));
    });

    test('erases the route from the start across the segments', () {
      // progress 0.75: the points from the one at 600 m on are left.
      final frame = framesAt(snack, 0.75);

      expect(frame.map((p) => p.polylineId.value), ['route#2', 'route#3']);
      expect(eastOf(frame[0].points.first), closeTo(600, 0.5));
    });

    test('draws nothing when the line is gone', () {
      expect(framesAt(snack, 0), isEmpty);
      expect(framesAt(snack, 1), isEmpty);
    });

    test('keeps the opacity of a fade', () {
      final fade = segmented(animator: const FadeInProgressiveAnimator());
      final frame = framesAt(fade, 0.15);

      // The first 30% fades in: half way is half opaque.
      expect(frame, hasLength(4));
      expect(frame.every((p) => (p.color.alpha - 128).abs() <= 1), isTrue);
      expect(frame[0].color.value & 0xFFFFFF, _green.value & 0xFFFFFF);
    });

    test('keeps the own opacity of a segment', () {
      final animated = AnimatedPolyline.segmented(
        id: const PolylineId('r'),
        points: _route(),
        segments: const [
          RouteSegment(from: 0, to: 1, color: Color(0x80E53935)),
        ],
        polylineAnimator: const FadeInProgressiveAnimator(),
      );

      // A segment that is half transparent, at half the fade: a quarter.
      expect(framesAt(animated, 0.15).single.color.alpha, closeTo(64, 1));
    });
  });

  group('on the map', () {
    late FakeMapsPlatform platform;

    setUp(() {
      platform = FakeMapsPlatform();
      GoogleMapsFlutterPlatform.instance = platform;
    });

    MapAnimationController create(
      WidgetTester tester,
      Set<AnimatedPolyline> polylines,
    ) =>
        MapAnimationController(mapId: 1, vsync: tester, polylines: polylines);

    testWidgets('a route without animator is drawn at once', (tester) async {
      final controller = create(tester, {segmented()});

      expect(platform.polylines.keys.map((id) => id.value).toSet(), {
        'route#0',
        'route#1',
        'route#2',
        'route#3',
      });
      controller.dispose();
    });

    testWidgets('updatePolylines with the same route keeps the segments', (
      tester,
    ) async {
      final controller = create(tester, {segmented()});

      controller.updatePolylines({segmented()});
      await tester.pump();

      expect(platform.polylines, hasLength(4));
      controller.dispose();
    });

    testWidgets('other polylines are not touched', (tester) async {
      const other = Polyline(
        polylineId: PolylineId('other'),
        points: [LatLng(0, 0), LatLng(1, 1)],
      );
      final controller = create(tester, {
        segmented(),
        const AnimatedPolyline(polyline: other),
      });

      expect(platform.polylines, hasLength(5));
      controller.dispose();
    });

    testWidgets('changing the segments redraws them at once', (tester) async {
      final controller = create(tester, {segmented()});

      controller.updatePolylines({
        AnimatedPolyline.segmented(
          id: const PolylineId('route'),
          points: _route(),
          segments: const [RouteSegment(from: 0, to: 1, color: _red)],
          width: 7,
        ),
      });

      expect(platform.polylines.keys.map((id) => id.value), ['route#0']);
      expect(platform.polylines.values.single.color.value, _red.value);
      controller.dispose();
    });

    testWidgets('removing the route removes every segment', (tester) async {
      final controller = create(tester, {segmented()});

      controller.updatePolylines({});

      expect(platform.polylines, isEmpty);
      controller.dispose();
    });

    testWidgets('an animated route draws and erases across the segments', (
      tester,
    ) async {
      final controller = create(tester, {
        segmented(
          animator: const SnackAnimator(
            duration: Duration(seconds: 2),
            curve: Curves.linear,
          ),
        ),
      });
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 500));
      expect(platform.polylines.keys.map((id) => id.value).toSet(), {
        'route#0',
        'route#1',
      });

      await tester.pump(const Duration(milliseconds: 1000));
      // 1.5 s of 2 s: the start is being erased, the first segment is gone.
      expect(platform.polylines.keys.map((id) => id.value).toSet(), {
        'route#2',
        'route#3',
      });
      controller.dispose();
    });
  });
}

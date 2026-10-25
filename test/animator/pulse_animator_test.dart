// `Color.alpha` is deprecated on new Flutter but is the only option on the
// minimum supported version.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

import '../fakes/geo.dart';

void main() {
  // A straight route of 1000 m.
  final polyline = Polyline(
    polylineId: const PolylineId('route'),
    color: const Color(0xFF1565C0),
    width: 5,
    points: [at(0, 0), at(300, 0), at(1000, 0)],
  );

  const animator = PulseAnimator(glowLength: 0.2);

  double eastOf(LatLng point) => metersOf(point).east;

  group('animateAll', () {
    test('draws the dimmed base and the glow on top', () {
      final result = animator.animateAll(polyline, 0.5);

      expect(result, hasLength(2));
      expect(result[0].polylineId, const PolylineId('route'));
      expect(result[0].color.alpha, closeTo(0.35 * 255, 1));
      expect(result[0].points, polyline.points);
      expect(result[1].polylineId, const PolylineId('route#glow'));
      expect(result[1].zIndex, greaterThan(result[0].zIndex));
    });

    test('the glow is a stretch of the route of the given length', () {
      // progress 0.5 * 1.2 = 0.6 is the head, the tail is 0.2 behind.
      final glow = animator.animateAll(polyline, 0.5)[1];

      expect(eastOf(glow.points.first), closeTo(400, 0.5));
      expect(eastOf(glow.points.last), closeTo(600, 0.5));
    });

    test('the glow keeps the corners of the route inside it', () {
      final glow = animator.animateAll(polyline, 0.4)[1];
      // 0.48 head, 0.28 tail: from 280 m to 480 m, with the point at 300 m.
      expect(glow.points, hasLength(3));
      expect(eastOf(glow.points[1]), closeTo(300, 0.5));
    });

    test('enters at the start and leaves at the end', () {
      final entering = animator.animateAll(polyline, 0.05)[1];
      expect(eastOf(entering.points.first), closeTo(0, 0.5));
      expect(eastOf(entering.points.last), closeTo(60, 0.5));

      final leaving = animator.animateAll(polyline, 0.95)[1];
      expect(eastOf(leaving.points.first), closeTo(940, 1.5));
      expect(eastOf(leaving.points.last), closeTo(1000, 0.5));
    });

    test('there is no glow before it enters or after it left', () {
      expect(animator.animateAll(polyline, 0), hasLength(1));
      expect(animator.animateAll(polyline, 1), hasLength(1));
    });

    test('the glow is wider and lighter than the line by default', () {
      final glow = animator.animateAll(polyline, 0.5)[1];

      expect(glow.width, 7);
      expect(glow.color.value, isNot(polyline.color.value));
      expect(glow.color.red, greaterThan(polyline.color.red));
    });

    test('uses the glow color and width that are given', () {
      const custom = PulseAnimator(
        glowColor: Color(0xFF8FD0FF),
        glowWidthExtra: 6,
        baseOpacity: 1,
      );
      final result = custom.animateAll(polyline, 0.5);

      expect(result[1].color, const Color(0xFF8FD0FF));
      expect(result[1].width, 11);
      expect(result[0].color.alpha, 255);
    });

    test('a polyline without two different points has no glow', () {
      const single = Polyline(
        polylineId: PolylineId('s'),
        points: [LatLng(0, 0), LatLng(0, 0)],
      );
      expect(animator.animateAll(single, 0.5), hasLength(1));
    });

    test('the glow has the same length wherever the points are', () {
      // The same route with many more points near the start.
      final dense = polyline.copyWith(
        pointsParam: [
          for (var i = 0; i <= 100; i++) at(i.toDouble(), 0),
          at(1000, 0),
        ],
      );
      final glow = animator.animateAll(dense, 0.5)[1];

      expect(eastOf(glow.points.first), closeTo(400, 0.5));
      expect(eastOf(glow.points.last), closeTo(600, 0.5));
    });
  });

  group('animate', () {
    test('is the dimmed line alone', () {
      final result = animator.animate(polyline, 0.5);
      expect(result.polylineId, polyline.polylineId);
      expect(result.color.alpha, closeTo(0.35 * 255, 1));
    });
  });

  group('configuration', () {
    test('loops by default', () {
      expect(animator.repeat, isTrue);
      expect(animator.duration, const Duration(milliseconds: 1800));
    });

    test('rejects a glow that does not make sense', () {
      expect(() => PulseAnimator(glowLength: 0), throwsAssertionError);
      expect(() => PulseAnimator(glowLength: 1.5), throwsAssertionError);
      expect(() => PulseAnimator(baseOpacity: 2), throwsAssertionError);
    });

    test('equality includes the pulse settings', () {
      expect(const PulseAnimator(), const PulseAnimator());
      expect(const PulseAnimator().hashCode, const PulseAnimator().hashCode);
      expect(
          const PulseAnimator(), isNot(const PulseAnimator(glowLength: 0.3)));
      expect(
        const PulseAnimator(),
        isNot(const PulseAnimator(glowColor: Colors.red)),
      );
      expect(
          const PulseAnimator(), isNot(const PulseAnimator(baseOpacity: 0.5)));
      expect(
        const PulseAnimator(),
        isNot(const PulseAnimator(glowWidthExtra: 4)),
      );
    });
  });
}

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/src/utils/route_path.dart';
import 'package:polyline_animation_plus/src/utils/spherical_util.dart';

/// A point [east] and [north] meters from the origin, on the equator where a
/// degree is about the same in both directions.
LatLng at(double east, double north) {
  const degreesPerMeter = 180 / (pi * SphericalUtil.earthRadius);
  return LatLng(north * degreesPerMeter, east * degreesPerMeter);
}

void expectNear(LatLng actual, LatLng expected, {double meters = 0.01}) {
  expect(
    SphericalUtil.computeDistanceBetween(actual, expected),
    lessThan(meters),
    reason: '$actual is not near $expected',
  );
}

void main() {
  // 100 m east, then 100 m north.
  final lRoute = RoutePath([at(0, 0), at(100, 0), at(100, 100)]);

  group('construction', () {
    test('measures the length', () {
      expect(lRoute.length, closeTo(200, 0.01));
      expect(lRoute.segments, 2);
    });

    test('drops consecutive equal points', () {
      final route = RoutePath([at(0, 0), at(0, 0), at(100, 0), at(100, 0)]);
      expect(route.points, hasLength(2));
      expect(route.length, closeTo(100, 0.01));
    });

    test('needs two different points', () {
      expect(() => RoutePath([at(0, 0)]), throwsArgumentError);
      expect(() => RoutePath([at(0, 0), at(0, 0)]), throwsArgumentError);
    });
  });

  group('pointAt, headingAt and segmentAt', () {
    test('finds points by distance', () {
      expectNear(lRoute.pointAt(50), at(50, 0));
      expectNear(lRoute.pointAt(100), at(100, 0));
      expectNear(lRoute.pointAt(150), at(100, 50));
    });

    test('clamps outside the route', () {
      expectNear(lRoute.pointAt(-5), at(0, 0));
      expectNear(lRoute.pointAt(999), at(100, 100));
    });

    test('gives the heading of the segment', () {
      expect(lRoute.headingAt(10), closeTo(90, 1e-6));
      expect(lRoute.headingAt(150), closeTo(0, 1e-6));
      expect(lRoute.headingAt(999), closeTo(0, 1e-6));
    });

    test('smoothing rounds the corner gradually', () {
      // The corner is at 100 m: from 92 m to 108 m the heading goes from 90
      // to 0 instead of jumping.
      expect(lRoute.headingAt(100, smoothMeters: 8), closeTo(45, 0.5));
      expect(lRoute.headingAt(80, smoothMeters: 8), closeTo(90, 1e-6));
      expect(lRoute.headingAt(120, smoothMeters: 8), closeTo(0, 1e-6));

      var previous = 90.0;
      for (var along = 90.0; along <= 110; along += 1) {
        final heading = lRoute.headingAt(along, smoothMeters: 8);
        expect(heading, lessThanOrEqualTo(previous + 1e-9));
        previous = heading;
      }
    });

    test('without smoothing the heading jumps at the corner', () {
      expect(lRoute.headingAt(99.9), closeTo(90, 1e-6));
      expect(lRoute.headingAt(100.1), closeTo(0, 1e-6));
    });

    test('smoothing works near the ends of the route', () {
      expect(lRoute.headingAt(0, smoothMeters: 8), closeTo(90, 1e-6));
      expect(lRoute.headingAt(200, smoothMeters: 8), closeTo(0, 1e-6));
    });

    test('segmentAt handles the boundaries', () {
      expect(lRoute.segmentAt(-1), 0);
      expect(lRoute.segmentAt(0), 0);
      expect(lRoute.segmentAt(99.9), 0);
      expect(lRoute.segmentAt(100), 1);
      expect(lRoute.segmentAt(200), 1);
    });
  });

  group('slice', () {
    test('keeps the corners between both ends', () {
      final points = lRoute.slice(50, 150);
      expect(points, hasLength(3));
      expectNear(points[0], at(50, 0));
      expectNear(points[1], at(100, 0));
      expectNear(points[2], at(100, 50));
    });

    test('the whole route gives the original points', () {
      final points = lRoute.slice(0, lRoute.length);
      expect(points, hasLength(3));
      expectNear(points.last, at(100, 100));
    });

    test('inside one segment gives two points', () {
      expect(lRoute.slice(10, 20), hasLength(2));
    });

    test('an empty range gives one point', () {
      expect(lRoute.slice(30, 30), hasLength(1));
    });

    test('does not repeat a corner that is exactly an end', () {
      final points = lRoute.slice(0, 100);
      expect(points, hasLength(2));
      expectNear(points.last, at(100, 0));
    });
  });

  group('nearest', () {
    test('puts a position on the route', () {
      final result = lRoute.nearest(at(50, 10))!;
      expect(result.along, closeTo(50, 0.05));
      expect(result.distance, closeTo(10, 0.05));
      expectNear(result.point, at(50, 0), meters: 0.1);
      expect(result.segment, 0);
    });

    test('clamps to the ends of the route', () {
      expect(lRoute.nearest(at(-30, 0))!.along, closeTo(0, 1e-6));
      expect(lRoute.nearest(at(100, 160))!.along, closeTo(200, 1e-6));
    });

    test('picks the second segment around the corner', () {
      final result = lRoute.nearest(at(110, 60))!;
      expect(result.segment, 1);
      expect(result.along, closeTo(160, 0.05));
    });

    group('with a window', () {
      // East 1000 m, north 500 m, west 1000 m, south to 5 m from the start and
      // east again: it passes the same place twice.
      final loop = RoutePath([
        at(0, 0),
        at(1000, 0),
        at(1000, 500),
        at(0, 500),
        at(0, 5), // passes 5 m from the start again
        at(1000, 5),
      ]);

      test('without a window it finds the closest of both passes', () {
        final result = loop.nearest(at(500, 2))!;
        expect(result.along, closeTo(500, 1));
      });

      test('with a window it stays on the pass the vehicle is on', () {
        // The vehicle was 3000 m along the route, on the second pass.
        final result = loop.nearest(
          at(500, 2),
          from: 3000,
          behind: 100,
          ahead: 500,
        );
        expect(result!.along, greaterThan(2900));
      });

      test('a window past the end still covers the last segment', () {
        // A window past the end still covers the last segment.
        expect(
          loop.nearest(at(500, 0), from: 99999, behind: 10, ahead: 10),
          isNotNull,
        );
      });

      test('prefers the pass near the expected distance when tied', () {
        // Exactly the same place on both passes of a crossing route.
        final cross = RoutePath([
          at(0, 0),
          at(100, 0),
          at(100, 1000),
          at(50, 1000),
          at(50, -10),
          at(50, 0.5),
        ]);
        final first =
            cross.nearest(at(50, 0), from: 50, behind: 20, ahead: 10000);
        expect(first!.along, closeTo(50, 1));
      });
    });
  });
}

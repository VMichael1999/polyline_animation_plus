import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/src/utils/math_util.dart';
import 'package:polyline_animation_plus/src/utils/spherical_util.dart';

const _origin = LatLng(0, 0);
const _quarterCircle = SphericalUtil.earthRadius * pi / 2;

void expectLatLng(LatLng actual, LatLng expected, {double tolerance = 1e-6}) {
  expect(actual.latitude, closeTo(expected.latitude, tolerance));
  expect(actual.longitude, closeTo(expected.longitude, tolerance));
}

void main() {
  group('SphericalUtil', () {
    test('computeHeading follows the compass', () {
      expect(SphericalUtil.computeHeading(_origin, const LatLng(1, 0)), 0);
      expect(
        SphericalUtil.computeHeading(_origin, const LatLng(0, 1)),
        closeTo(90, 1e-9),
      );
      expect(
        SphericalUtil.computeHeading(_origin, const LatLng(-1, 0)),
        closeTo(-180, 1e-9),
      );
      expect(
        SphericalUtil.computeHeading(_origin, const LatLng(0, -1)),
        closeTo(-90, 1e-9),
      );
    });

    test('computeOffset moves a quarter of the Earth along the equator', () {
      final result = SphericalUtil.computeOffset(_origin, _quarterCircle, 90);
      expectLatLng(result, const LatLng(0, 90));
    });

    test('computeOffsetOrigin undoes computeOffset', () {
      const distance = SphericalUtil.earthRadius * pi / 4;
      final destination = SphericalUtil.computeOffset(_origin, distance, 90);
      final origin =
          SphericalUtil.computeOffsetOrigin(destination, distance, 90);
      expectLatLng(origin!, _origin);
    });

    test('computeOffsetOrigin returns null when there is no solution', () {
      final origin = SphericalUtil.computeOffsetOrigin(
        const LatLng(80, 0),
        SphericalUtil.earthRadius * 20 * pi / 180,
        90,
      );
      expect(origin, isNull);
    });

    test('interpolate returns the middle point', () {
      expectLatLng(
        SphericalUtil.interpolate(_origin, const LatLng(0, 90), 0.5),
        const LatLng(0, 45),
      );
    });

    test('interpolate between identical points returns that point', () {
      expectLatLng(
        SphericalUtil.interpolate(const LatLng(3, 4), const LatLng(3, 4), 0.5),
        const LatLng(3, 4),
      );
    });

    test('distance and length are measured on the sphere', () {
      const end = LatLng(0, 90);
      expect(
        SphericalUtil.computeDistanceBetween(_origin, end),
        closeTo(_quarterCircle, 1e-3),
      );
      expect(
        SphericalUtil.computeLength([_origin, const LatLng(0, 45), end]),
        closeTo(_quarterCircle, 1e-3),
      );
      expect(SphericalUtil.computeLength([_origin]), 0);
    });

    test('computeArea of an octant of the Earth', () {
      const octant = [LatLng(0, 0), LatLng(0, 90), LatLng(90, 0)];
      final expected = pi * pow(SphericalUtil.earthRadius, 2) / 2;

      expect(SphericalUtil.computeArea(octant), closeTo(expected, 1));
      expect(
        SphericalUtil.computeSignedArea(octant.reversed.toList()).abs(),
        closeTo(expected, 1),
      );
      expect(SphericalUtil.computeArea(const [_origin, LatLng(1, 1)]), 0);
    });

    test('angleLerp takes the shortest way around', () {
      expect(SphericalUtil.angleLerp(0, 90, 0.5), closeTo(45, 1e-9));
      expect(SphericalUtil.angleLerp(350, 10, 0.5), closeTo(360, 1e-9));
      expect(SphericalUtil.angleLerp(10, 0, 1), 0);
      expect(SphericalUtil.angleLerp(0, 0, 0.5), 0);
    });
  });

  group('MathUtil', () {
    test('converts between degrees and radians', () {
      expect(MathUtil.toRadians(180), closeTo(pi, 1e-12));
      expect(MathUtil.toDegrees(pi), closeTo(180, 1e-12));
    });

    test('wrap keeps values inside [min, max)', () {
      expect(MathUtil.wrap(190, -180, 180), -170);
      expect(MathUtil.wrap(10, -180, 180), 10);
      expect(MathUtil.wrap(180, -180, 180), -180);
    });

    test('mod is never negative', () {
      expect(MathUtil.mod(-1, 3), 2);
      expect(MathUtil.mod(7, 3), 1);
    });

    test('haversine helpers agree with each other', () {
      expect(MathUtil.hav(pi), closeTo(1, 1e-12));
      expect(MathUtil.arcHav(MathUtil.hav(1.2)), closeTo(1.2, 1e-12));
      expect(MathUtil.havDistance(0, 0, 0), 0);
    });
  });
}

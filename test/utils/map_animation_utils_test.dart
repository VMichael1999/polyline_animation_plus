import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';
import 'package:polyline_animation_plus/src/utils/spherical_util.dart';

/// A point [meters] east of the origin along the equator.
LatLng _eastOf(double meters) =>
    LatLng(0, meters / SphericalUtil.earthRadius * 180 / 3.141592653589793);

void main() {
  _boundsTests();

  group('generateEquidistantPolylineByDuration', () {
    // Two straight segments of 9 m and 11 m (20 m total). 128 ms at 16 ms per
    // frame is 8 steps, so the spacing is 2.5 m. The junction at 9 m is not a
    // multiple of the spacing.
    final path = [_eastOf(0), _eastOf(9), _eastOf(20)];
    final points = MapAnimationUtils.generateEquidistantPolylineByDuration(
      path: path,
      duration: const Duration(milliseconds: 128),
    );

    test('starts at the first point without duplicating it', () {
      expect(points.first, path.first);
      expect(points[1], isNot(path.first));
    });

    test('keeps the same distance between consecutive points', () {
      for (var i = 0; i < points.length - 1; i++) {
        final d = SphericalUtil.computeDistanceBetween(
          points[i],
          points[i + 1],
        );
        expect(d, closeTo(2.5, 1e-3), reason: 'between point $i and ${i + 1}');
      }
    });

    test('ends at the last point of the path', () {
      expect(points.last.latitude, closeTo(path.last.latitude, 1e-9));
      expect(points.last.longitude, closeTo(path.last.longitude, 1e-9));
      expect(points, hasLength(9));
    });

    test('adds the last point when it is not a multiple of the spacing', () {
      // 20 m / 6 steps = 3.33 m; the last gap is shorter than the spacing.
      final shortGap = [_eastOf(0), _eastOf(10), _eastOf(21)];
      final result = MapAnimationUtils.generateEquidistantPolylineByDuration(
        path: shortGap,
        duration: const Duration(milliseconds: 96),
      );
      expect(result.last.longitude, closeTo(shortGap.last.longitude, 1e-9));
    });

    test('returns the path unchanged when all points coincide', () {
      final same = [_eastOf(5), _eastOf(5)];
      final result = MapAnimationUtils.generateEquidistantPolylineByDuration(
        path: same,
        duration: const Duration(milliseconds: 128),
      );
      expect(result, same);
    });
  });
}

void _boundsTests() {
  group('boundsOf', () {
    test('contains every point', () {
      final bounds = MapAnimationUtils.boundsOf(const [
        LatLng(10, 20),
        LatLng(-5, 30),
        LatLng(7, -15),
      ]);

      expect(bounds.southwest, const LatLng(-5, -15));
      expect(bounds.northeast, const LatLng(10, 30));
    });

    test('one point gives a box with no size', () {
      final bounds = MapAnimationUtils.boundsOf(const [LatLng(3, 4)]);

      expect(bounds.southwest, const LatLng(3, 4));
      expect(bounds.northeast, const LatLng(3, 4));
    });

    test('works with negative coordinates only', () {
      final bounds = MapAnimationUtils.boundsOf(const [
        LatLng(-10, -20),
        LatLng(-30, -5),
      ]);

      expect(bounds.southwest, const LatLng(-30, -20));
      expect(bounds.northeast, const LatLng(-10, -5));
    });

    test('rejects an empty list', () {
      expect(() => MapAnimationUtils.boundsOf(const []), throwsArgumentError);
    });
  });
}

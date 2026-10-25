import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/src/controllers/vehicle_tracker.dart';
import 'package:polyline_animation_plus/src/utils/route_path.dart';
import 'package:polyline_animation_plus/src/utils/spherical_util.dart';

LatLng at(double east, double north) {
  const degreesPerMeter = 180 / (pi * SphericalUtil.earthRadius);
  return LatLng(north * degreesPerMeter, east * degreesPerMeter);
}

/// The inverse of [at].
({double east, double north}) metersOf(LatLng point) {
  const degreesPerMeter = 180 / (pi * SphericalUtil.earthRadius);
  return (
    east: point.longitude / degreesPerMeter,
    north: point.latitude / degreesPerMeter,
  );
}

void main() {
  group('on an L shaped route', () {
    // 1000 m east, then 1000 m north.
    final route = RoutePath([at(0, 0), at(1000, 0), at(1000, 1000)]);

    test('puts noisy positions (up to 10 m) back on the road', () {
      final tracker = VehicleTracker(route, toleranceMeters: 30);
      final random = Random(7);
      double noise() => (random.nextDouble() * 2 - 1) * 10;

      var previous = 0.0;
      for (var travelled = 0.0; travelled <= 2000; travelled += 25) {
        final truth = route.pointAt(travelled);
        final truthMeters = metersOf(truth);
        final fix = tracker.update(
          at(truthMeters.east + noise(), truthMeters.north + noise()),
        );

        expect(fix.onRoute, isTrue, reason: 'at $travelled m');
        // Near the real position, and on the route itself.
        expect(fix.along, closeTo(travelled, 15));
        expect(route.nearest(fix.position)!.distance, lessThan(0.5));
        // It never goes far backwards.
        expect(fix.along!, greaterThan(previous - 15));
        previous = fix.along!;
      }
    });

    test('a position beyond the end stays at the end', () {
      final tracker = VehicleTracker(route, toleranceMeters: 30);
      tracker.update(at(1000, 990));
      final fix = tracker.update(at(1000, 1010));

      expect(fix.onRoute, isTrue);
      expect(fix.along, closeTo(2000, 1e-6));
    });
  });

  group('on a route that passes twice through the same place', () {
    // East 1000 m, north 3000 m, west 1000 m, south 3000 m, and east again:
    // the origin is visited at 0 m and at 8000 m, and the vehicle never takes
    // the later pass by mistake.
    final route = RoutePath([
      at(0, 0),
      at(1000, 0),
      at(1000, 3000),
      at(0, 3000),
      at(0, 0),
      at(1000, 0),
    ]);

    test('stays on the first pass while it is on it', () {
      final tracker = VehicleTracker(route, toleranceMeters: 30);

      tracker.update(at(5, 0)); // the very beginning
      final fix = tracker.update(at(500, 0));
      expect(fix.along, closeTo(500, 1));
    });

    test('takes the second pass when the vehicle gets there', () {
      final tracker = VehicleTracker(route, toleranceMeters: 30);

      // Drive the whole loop, one position every 200 m.
      double? along;
      for (var travelled = 0.0; travelled <= 7000; travelled += 200) {
        final truth = route.pointAt(travelled);
        along = tracker.update(truth).along;
      }
      expect(along, closeTo(7000, 1));

      // Back at the origin, 8000 m along the route (the same place as 0 m).
      final fix = tracker.update(at(0, 0));
      expect(fix.along, closeTo(7000 + 1000, 1), reason: 'second visit');
    });
  });

  group('off route', () {
    final route = RoutePath([at(0, 0), at(1000, 0)]);

    test('reports the position as it is and keeps the progress', () {
      final tracker = VehicleTracker(route, toleranceMeters: 30);
      tracker.update(at(300, 0));

      final fix = tracker.update(at(500, 200));
      expect(fix.onRoute, isFalse);
      expect(fix.position, at(500, 200));
      expect(fix.along, closeTo(300, 0.1));
      expect(tracker.along, closeTo(300, 0.1));
    });

    test('picks the route up again when it comes back', () {
      final tracker = VehicleTracker(route, toleranceMeters: 30);
      tracker.update(at(300, 0));
      tracker.update(at(500, 200));

      final fix = tracker.update(at(600, 5));
      expect(fix.onRoute, isTrue);
      expect(fix.along, closeTo(600, 1));
    });

    test('a first position far from the route is off route', () {
      final tracker = VehicleTracker(route, toleranceMeters: 30);
      final fix = tracker.update(at(500, 500));

      expect(fix.onRoute, isFalse);
      expect(fix.along, isNull);
    });

    test('a jump to another part of the route is accepted', () {
      // 6 km further than the search window: found by the full search.
      final long = RoutePath([at(0, 0), at(10000, 0)]);
      final tracker = VehicleTracker(long, toleranceMeters: 30);
      tracker.update(at(100, 0));
      final fix = tracker.update(at(6000, 0));
      expect(fix.onRoute, isTrue);
      expect(fix.along, closeTo(6000, 1));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/src/tween/bearing_tween.dart';
import 'package:polyline_animation_plus/src/tween/location_tween.dart';

void main() {
  group('BearingTween', () {
    test('returns the ends exactly', () {
      final tween = BearingTween(begin: 10, end: 80);
      expect(tween.lerp(0), 10);
      expect(tween.lerp(1), 80);
    });

    test('turns the short way and transform matches lerp', () {
      final tween = BearingTween(begin: 350, end: 10);
      expect(tween.lerp(0.5), closeTo(360, 1e-9));
      expect(tween.transform(0.5), tween.lerp(0.5));
    });

    test('swap continues from the previous end', () {
      final tween = BearingTween(begin: 0, end: 90)..swap(180);
      expect(tween.begin, 90);
      expect(tween.end, 180);
    });
  });

  group('LocationTween', () {
    test('interpolates over the sphere and exposes the bearing', () {
      final tween = LocationTween(
        begin: const LatLng(0, 0),
        end: const LatLng(0, 2),
      );
      expect(tween.lerp(0.5).longitude, closeTo(1, 1e-9));
      expect(tween.bearing, closeTo(90, 1e-9));
    });

    test('swap continues from the previous end', () {
      final tween = LocationTween(
        begin: const LatLng(0, 0),
        end: const LatLng(0, 1),
      )..swap(const LatLng(1, 1));
      expect(tween.begin, const LatLng(0, 1));
      expect(tween.end, const LatLng(1, 1));
    });
  });
}

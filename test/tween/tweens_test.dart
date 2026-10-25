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
  });

  group('LocationTween', () {
    test('interpolates over the sphere', () {
      final tween = LocationTween(
        begin: const LatLng(0, 0),
        end: const LatLng(0, 2),
      );
      expect(tween.lerp(0.5).longitude, closeTo(1, 1e-9));
    });
  });
}

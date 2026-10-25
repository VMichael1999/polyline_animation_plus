import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

void main() {
  const line = Polyline(polylineId: PolylineId('p'));

  test('equal when polyline and animator are equal', () {
    const a =
        AnimatedPolyline(polyline: line, polylineAnimator: SnackAnimator());
    const b =
        AnimatedPolyline(polyline: line, polylineAnimator: SnackAnimator());
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('different animators make them different', () {
    const a =
        AnimatedPolyline(polyline: line, polylineAnimator: SnackAnimator());
    const b = AnimatedPolyline(polyline: line);
    expect(a, isNot(b));
  });

  test('toString mentions the polyline', () {
    expect(const AnimatedPolyline(polyline: line).toString(), contains('p'));
  });
}

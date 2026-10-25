// `alpha` and `value` are deprecated on new Flutter but are the only options on
// the minimum supported version.
// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

void main() {
  const animator = FadeInProgressiveAnimator();
  const polyline = Polyline(
    polylineId: PolylineId('p'),
    color: Color(0xFF1565C0),
    points: [LatLng(0, 0), LatLng(0, 1), LatLng(0, 2), LatLng(0, 3)],
  );

  test('fades in during the first 30% without moving the points', () {
    final start = animator.animate(polyline, 0.0);
    final middle = animator.animate(polyline, 0.15);
    final end = animator.animate(polyline, 0.3);

    expect(start.color.alpha, 0);
    expect(middle.color.alpha, closeTo(128, 1));
    expect(end.color.alpha, 255);
    expect(middle.color.value & 0x00FFFFFF, 0x1565C0);
    expect(middle.points, polyline.points);
  });

  test('erases the polyline from its start afterwards', () {
    expect(animator.animate(polyline, 0.3).points, polyline.points);
    expect(animator.animate(polyline, 0.65).points, hasLength(2));
    expect(animator.animate(polyline, 1.0).points, isEmpty);
  });
}

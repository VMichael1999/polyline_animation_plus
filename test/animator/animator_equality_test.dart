import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

void main() {
  group('PolylineAnimator equality', () {
    test('differs when delayStart changes', () {
      const a = FadeInProgressiveAnimator(delayStart: Duration(seconds: 1));
      const b = FadeInProgressiveAnimator(delayStart: Duration(seconds: 2));
      expect(a, isNot(b));
    });

    test('differs when delayEnd changes', () {
      const a = FadeInProgressiveAnimator(delayEnd: Duration(seconds: 1));
      const b = FadeInProgressiveAnimator(delayEnd: Duration(seconds: 2));
      expect(a, isNot(b));
    });

    test('equal animators share the hash code', () {
      const a = FadeInProgressiveAnimator(delayStart: Duration(seconds: 1));
      const b = FadeInProgressiveAnimator(delayStart: Duration(seconds: 1));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('ColorTransitionAnimation equality', () {
    test('differs when colors change', () {
      const a = ColorTransitionAnimation(colors: [Colors.red, Colors.blue]);
      const b = ColorTransitionAnimation(colors: [Colors.red, Colors.green]);
      expect(a, isNot(b));
    });

    test('equal colors give equal animators and hash codes', () {
      final a = ColorTransitionAnimation(colors: [Colors.red, Colors.blue]);
      final b = ColorTransitionAnimation(colors: [Colors.red, Colors.blue]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}

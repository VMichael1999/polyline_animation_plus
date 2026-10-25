import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

void main() {
  test('SnackAnimator accepts delays', () {
    const animator = SnackAnimator(
      delayStart: Duration(seconds: 1),
      delayEnd: Duration(seconds: 2),
    );
    expect(animator.delayStart, const Duration(seconds: 1));
    expect(animator.delayEnd, const Duration(seconds: 2));
  });

  test('ColorTransitionAnimation accepts repeatCount, reverse and delays', () {
    const animator = ColorTransitionAnimation(
      colors: [Colors.red, Colors.blue],
      repeat: true,
      repeatCount: 3,
      reverse: true,
      delayStart: Duration(seconds: 1),
      delayEnd: Duration(seconds: 2),
    );
    expect(animator.repeatCount, 3);
    expect(animator.reverse, isTrue);
    expect(animator.delayStart, const Duration(seconds: 1));
    expect(animator.delayEnd, const Duration(seconds: 2));
  });
}

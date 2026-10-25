// `Color.value` is deprecated on new Flutter but is the only way to compare
// colors on the minimum supported version.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

const _polyline = Polyline(
  polylineId: PolylineId('p'),
  color: Colors.black,
  points: [LatLng(0, 0), LatLng(0, 1), LatLng(0, 2), LatLng(0, 3)],
);

void main() {
  group('SnackAnimator', () {
    const animator = SnackAnimator();

    test('draws the line during the first half', () {
      expect(animator.animate(_polyline, 0).points, isEmpty);
      expect(
          animator.animate(_polyline, 0.25).points, _polyline.points.take(2));
      expect(animator.animate(_polyline, 0.5).points, _polyline.points);
    });

    test('erases the line from the start during the second half', () {
      expect(
          animator.animate(_polyline, 0.75).points, _polyline.points.skip(2));
      expect(animator.animate(_polyline, 1).points, isEmpty);
    });
  });

  group('ColorTransitionAnimation', () {
    const animator = ColorTransitionAnimation(
      colors: [Colors.red, Colors.blue],
    );

    test('starts with the first color', () {
      expect(animator.animate(_polyline, 0).color.value, Colors.red.value);
    });

    test('reaches the next color halfway', () {
      expect(animator.animate(_polyline, 0.5).color.value, Colors.blue.value);
    });

    test('blends the colors in between', () {
      expect(
        animator.animate(_polyline, 0.25).color.value,
        Color.lerp(Colors.red, Colors.blue, 0.5)!.value,
      );
    });

    test('is back at the first color at the end, ready to repeat', () {
      expect(animator.animate(_polyline, 1).color.value, Colors.red.value);
    });

    test('does not leave the range of the colors near the end', () {
      const three = ColorTransitionAnimation(
        colors: [Colors.red, Colors.green, Colors.blue],
      );
      final value = three.animate(_polyline, 0.999).color.value;
      // Almost red: the red channel is high and the blue one is low.
      expect((value >> 16) & 0xFF, greaterThan(0xF0));
      expect(value & 0xFF, lessThan(0x40));
      expect(three.animate(_polyline, 1).color.value, Colors.red.value);
    });

    test('a single color stays that color', () {
      const single = ColorTransitionAnimation(colors: [Colors.green]);
      expect(single.animate(_polyline, 0.4).color.value, Colors.green.value);
      expect(single.animate(_polyline, 1).color.value, Colors.green.value);
    });

    test('without colors the polyline is left unchanged', () {
      const empty = ColorTransitionAnimation(colors: []);
      expect(empty.animate(_polyline, 0.5), _polyline);
    });

    test('keeps the points untouched', () {
      expect(animator.animate(_polyline, 0.3).points, _polyline.points);
    });
  });

  group('PolylineAnimator', () {
    test('equality is false for another type or other settings', () {
      const fade = FadeInProgressiveAnimator();
      expect(fade == const SnackAnimator(), isFalse);
      expect(
        fade == const FadeInProgressiveAnimator(repeatCount: 2),
        isFalse,
      );
      expect(fade == const FadeInProgressiveAnimator(reverse: true), isFalse);
    });

    test('toString lists the settings', () {
      final text = const SnackAnimator(repeatCount: 2).toString();
      expect(text, contains('repeatCount: 2'));
      expect(text, contains('delayStart'));
    });
  });
}

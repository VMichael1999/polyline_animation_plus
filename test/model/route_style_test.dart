import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

void main() {
  group('RouteStyle', () {
    test('has defaults', () {
      const style = RouteStyle(color: Colors.blue);
      expect(style.width, 5);
      expect(style.visible, isTrue);
    });

    test('equality and hash code use every field', () {
      const style = RouteStyle(color: Colors.blue, width: 3);
      expect(style, const RouteStyle(color: Colors.blue, width: 3));
      expect(style.hashCode,
          const RouteStyle(color: Colors.blue, width: 3).hashCode);
      expect(style, isNot(const RouteStyle(color: Colors.red, width: 3)));
      expect(style, isNot(const RouteStyle(color: Colors.blue, width: 4)));
      expect(
        style,
        isNot(const RouteStyle(color: Colors.blue, width: 3, visible: false)),
      );
    });

    test('toString names the fields', () {
      expect(
        const RouteStyle(color: Colors.blue).toString(),
        allOf(contains('width: 5'), contains('visible: true')),
      );
    });
  });

  group('RouteSegment', () {
    test('equality and hash code use every field', () {
      const segment = RouteSegment(from: 0, to: 0.5, color: Colors.red);
      expect(segment, const RouteSegment(from: 0, to: 0.5, color: Colors.red));
      expect(
        segment.hashCode,
        const RouteSegment(from: 0, to: 0.5, color: Colors.red).hashCode,
      );
      expect(segment,
          isNot(const RouteSegment(from: 0.1, to: 0.5, color: Colors.red)));
      expect(segment,
          isNot(const RouteSegment(from: 0, to: 0.6, color: Colors.red)));
      expect(segment,
          isNot(const RouteSegment(from: 0, to: 0.5, color: Colors.blue)));
    });

    test('toString shows the range', () {
      expect(
        const RouteSegment(from: 0, to: 0.5, color: Colors.red).toString(),
        contains('0.0 to 0.5'),
      );
    });
  });
}

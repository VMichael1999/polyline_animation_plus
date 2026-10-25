import 'package:flutter_test/flutter_test.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

void main() {
  group('MarkerDuration.fixed', () {
    const fixed = MarkerDuration.fixed(Duration(seconds: 2));

    test('always lasts the same', () {
      expect(fixed.resolve(null), const Duration(seconds: 2));
      expect(fixed.resolve(const Duration(milliseconds: 300)),
          const Duration(seconds: 2));
      expect(fixed.isAdaptive, isFalse);
    });
  });

  group('MarkerDuration.adaptive', () {
    const adaptive = MarkerDuration.adaptive(max: Duration(seconds: 2));

    test('uses the maximum for the first move', () {
      expect(adaptive.resolve(null), const Duration(seconds: 2));
      expect(adaptive.isAdaptive, isTrue);
      expect(adaptive.maxDuration, const Duration(seconds: 2));
    });

    test('follows the time between positions', () {
      expect(adaptive.resolve(const Duration(milliseconds: 800)),
          const Duration(milliseconds: 800));
    });

    test('is capped at the maximum', () {
      expect(adaptive.resolve(const Duration(minutes: 1)),
          const Duration(seconds: 2));
    });

    test('is never shorter than 100 ms', () {
      expect(adaptive.resolve(const Duration(milliseconds: 5)),
          const Duration(milliseconds: 100));
    });

    test('a maximum below 100 ms wins', () {
      const tiny = MarkerDuration.adaptive(max: Duration(milliseconds: 50));
      expect(tiny.resolve(const Duration(milliseconds: 5)),
          const Duration(milliseconds: 50));
    });
  });

  test('equality and toString', () {
    expect(const MarkerDuration.fixed(Duration(seconds: 1)),
        const MarkerDuration.fixed(Duration(seconds: 1)));
    expect(const MarkerDuration.fixed(Duration(seconds: 1)),
        isNot(const MarkerDuration.adaptive(max: Duration(seconds: 1))));
    expect(const MarkerDuration.fixed(Duration(seconds: 1)).hashCode,
        const MarkerDuration.fixed(Duration(seconds: 1)).hashCode);
    expect(const MarkerDuration.adaptive(max: Duration(seconds: 1)).toString(),
        contains('adaptive'));
    expect(const MarkerDuration.fixed(Duration(seconds: 1)).toString(),
        contains('fixed'));
  });
}

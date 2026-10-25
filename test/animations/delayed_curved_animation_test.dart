import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyline_animation_plus/src/animations/delayed_curved_animation.dart';

void main() {
  late AnimationController controller;

  setUp(() => controller = AnimationController(vsync: const TestVSync()));
  tearDown(() => controller.dispose());

  DelayedCurvedAnimation create({
    Duration delayStart = const Duration(seconds: 1),
    Duration delayEnd = const Duration(seconds: 1),
  }) =>
      DelayedCurvedAnimation(
        controller: controller,
        totalDuration: const Duration(seconds: 5),
        delayStart: delayStart,
        delayEnd: delayEnd,
      );

  test('exposes the duration of the animated part', () {
    expect(create().animationDuration, const Duration(seconds: 3));
  });

  test('rejects delays that leave no time to animate', () {
    expect(
      () => create(
        delayStart: const Duration(seconds: 3),
        delayEnd: const Duration(seconds: 2),
      ),
      throwsArgumentError,
    );
  });

  test('stays at 0 during the start delay and at 1 during the end delay', () {
    final animation = create();

    controller.value = 0.1;
    expect(animation.value, 0);
    expect(animation.isInStartDelay, isTrue);
    expect(animation.isAnimating, isFalse);

    controller.value = 0.9;
    expect(animation.value, 1);
    expect(animation.isInEndDelay, isTrue);
    expect(animation.isAnimating, isFalse);
  });

  test('maps the middle of the cycle to the middle of the animation', () {
    final animation = create();
    controller.value = 0.5;

    expect(animation.value, closeTo(0.5, 1e-9));
    expect(animation.animationProgress, closeTo(0.5, 1e-9));
    expect(animation.isAnimating, isTrue);
  });

  test('animationProgress is 0 and 1 at the ends', () {
    final animation = create();

    controller.value = 0;
    expect(animation.animationProgress, 0);
    controller.value = 1;
    expect(animation.animationProgress, 1);
  });

  test('without delays it behaves like the plain controller', () {
    final animation = create(
      delayStart: Duration.zero,
      delayEnd: Duration.zero,
    );
    controller.value = 0.3;

    expect(animation.value, closeTo(0.3, 1e-9));
    expect(animation.isInStartDelay, isFalse);
  });
}

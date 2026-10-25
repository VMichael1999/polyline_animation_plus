import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';
import 'package:polyline_animation_plus/src/controllers/polyline_controller.dart';

class _RecordingAnimator extends PolylineAnimator {
  const _RecordingAnimator({
    required super.duration,
    super.delayStart,
    super.repeat,
  });

  static final progress = <double>[];
  static var stops = 0;

  @override
  void onAnimationStop() => stops++;

  @override
  Polyline animate(Polyline polyline, double progress) {
    _RecordingAnimator.progress.add(progress);
    return polyline;
  }
}

void main() {
  const polyline = Polyline(
    polylineId: PolylineId('p'),
    points: [LatLng(0, 0), LatLng(0, 1)],
  );

  setUp(() {
    _RecordingAnimator.progress.clear();
    _RecordingAnimator.stops = 0;
  });

  testWidgets('delayStart is added to duration instead of eating into it', (
    tester,
  ) async {
    final controller = PolylineAnimationController(
      vsync: tester,
      polyline: polyline,
      polylineListener: (_) {},
      polylineAnimator: const _RecordingAnimator(
        duration: Duration(seconds: 4),
        delayStart: Duration(seconds: 1),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_RecordingAnimator.progress.last, 0.0);

    await tester.pump(const Duration(seconds: 2));
    expect(_RecordingAnimator.progress.last, closeTo(0.5, 1e-6));

    await tester.pump(const Duration(seconds: 2));
    expect(_RecordingAnimator.progress.last, 1.0);

    controller.dispose();
  });

  group('onAnimationStop', () {
    PolylineAnimationController create(WidgetTester tester, bool repeat) =>
        PolylineAnimationController(
          vsync: tester,
          polyline: polyline,
          polylineListener: (_) {},
          polylineAnimator: _RecordingAnimator(
            duration: const Duration(seconds: 1),
            repeat: repeat,
          ),
        );

    testWidgets('is called once when the animation completes', (tester) async {
      final controller = create(tester, false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(_RecordingAnimator.stops, 1);
      controller.dispose();
    });

    testWidgets('is not called when disposed before completing', (
      tester,
    ) async {
      final controller = create(tester, false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      controller.dispose();
      expect(_RecordingAnimator.stops, 0);
    });

    testWidgets('is not called by an endless repeating animation', (
      tester,
    ) async {
      final controller = create(tester, true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(_RecordingAnimator.stops, 0);
      controller.dispose();
    });
  });
}

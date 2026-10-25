import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';
import 'package:polyline_animation_plus/src/controllers/polyline_controller.dart';

import '../fakes/fake_maps_platform.dart';

class _Animator extends PolylineAnimator {
  const _Animator({
    super.duration = const Duration(seconds: 4),
    super.repeat,
    super.repeatCount,
    super.reverse,
    super.delayStart,
  }) : super(curve: Curves.linear);

  static final progress = <double>[];

  @override
  Polyline animate(Polyline polyline, double progress) {
    _Animator.progress.add(progress);
    return polyline;
  }
}

const _line = Polyline(
  polylineId: PolylineId('p'),
  points: [LatLng(0, 0), LatLng(0, 1)],
);

Future<void> pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 50);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

void main() {
  setUp(_Animator.progress.clear);

  PolylineAnimationController create(
    WidgetTester tester,
    PolylineAnimator animator,
  ) =>
      PolylineAnimationController(
        vsync: tester,
        polyline: _line,
        polylineAnimator: animator,
        polylineListener: (_) {},
      );

  group('pause and resume', () {
    testWidgets('pause freezes the animation and resume continues it', (
      tester,
    ) async {
      final controller = create(tester, const _Animator());
      final handle = controller.handle;
      await tester.pump();

      await pumpFor(tester, const Duration(seconds: 1));
      expect(handle.value, closeTo(0.25, 0.02));
      handle.pause();
      expect(handle.isPlaying, isFalse);
      final frozen = handle.value;

      await pumpFor(tester, const Duration(seconds: 3));
      expect(handle.value, frozen);

      handle.resume();
      expect(handle.isPlaying, isTrue);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(handle.value, closeTo(0.5, 0.03));
      controller.dispose();
    });

    testWidgets('the time spent paused does not count', (tester) async {
      final controller = create(tester, const _Animator());
      var completed = 0;
      controller.handle.onComplete = () => completed++;
      await tester.pump();

      await pumpFor(tester, const Duration(seconds: 2));
      controller.handle.pause();
      await pumpFor(tester, const Duration(seconds: 10));
      controller.handle.resume();

      await pumpFor(tester, const Duration(milliseconds: 1500));
      expect(completed, 0);
      await pumpFor(tester, const Duration(milliseconds: 700));
      expect(completed, 1);
      controller.dispose();
    });

    testWidgets('pause twice and resume twice are harmless', (tester) async {
      final controller = create(tester, const _Animator());
      final handle = controller.handle;
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 1));

      handle.pause();
      handle.pause();
      final frozen = handle.value;
      handle.resume();
      handle.resume();
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(handle.value, greaterThan(frozen));
      controller.dispose();
    });

    testWidgets('a paused repeating animation resumes where it was', (
      tester,
    ) async {
      final controller = create(
        tester,
        const _Animator(duration: Duration(seconds: 2), repeat: true),
      );
      await tester.pump();
      await pumpFor(tester, const Duration(milliseconds: 2500));
      expect(controller.handle.value, closeTo(0.25, 0.03));

      controller.handle.pause();
      await pumpFor(tester, const Duration(seconds: 5));
      controller.handle.resume();
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(controller.handle.value, closeTo(0.5, 0.03));
      controller.dispose();
    });
  });

  group('seek', () {
    testWidgets('jumps while playing and keeps playing from there', (
      tester,
    ) async {
      final controller = create(tester, const _Animator());
      var completed = 0;
      controller.handle.onComplete = () => completed++;
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 1));

      controller.handle.seek(0.75);
      expect(controller.handle.value, 0.75);
      expect(controller.handle.isPlaying, isTrue);
      expect(completed, 0);

      await pumpFor(tester, const Duration(milliseconds: 1200));
      expect(completed, 1);
      expect(controller.handle.isCompleted, isTrue);
      controller.dispose();
    });

    testWidgets('draws the new frame even when paused', (tester) async {
      final controller = create(tester, const _Animator());
      await tester.pump();
      controller.handle.pause();
      _Animator.progress.clear();

      controller.handle.seek(0.5);

      expect(_Animator.progress, isNotEmpty);
      expect(_Animator.progress.last, 0.5);
      expect(controller.handle.isPlaying, isFalse);

      await pumpFor(tester, const Duration(seconds: 1));
      expect(controller.handle.value, 0.5);

      controller.handle.resume();
      await pumpFor(tester, const Duration(seconds: 1));
      expect(controller.handle.value, closeTo(0.75, 0.03));
      controller.dispose();
    });

    testWidgets('seeking to the end completes once', (tester) async {
      final controller = create(tester, const _Animator());
      var completed = 0;
      controller.handle.onComplete = () => completed++;
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 1));

      controller.handle.seek(1);
      await pumpFor(tester, const Duration(seconds: 1));

      expect(completed, 1);
      controller.dispose();
    });

    testWidgets('seeking a finished animation does not replay it', (
      tester,
    ) async {
      final controller = create(tester, const _Animator());
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 5));
      expect(controller.handle.isCompleted, isTrue);

      controller.handle.seek(0.25);
      await pumpFor(tester, const Duration(seconds: 2));

      expect(controller.handle.value, 0.25);
      expect(controller.handle.isPlaying, isFalse);

      controller.handle.resume();
      await pumpFor(tester, const Duration(milliseconds: 3200));
      expect(controller.handle.isCompleted, isTrue);
      controller.dispose();
    });

    testWidgets('clamps out of range values', (tester) async {
      final controller = create(tester, const _Animator());
      await tester.pump();
      controller.handle.pause();

      controller.handle.seek(-3);
      expect(controller.handle.value, 0);
      controller.handle.seek(7);
      expect(controller.handle.value, 1);
      controller.dispose();
    });

    testWidgets('keeps going backwards in a backwards pass', (tester) async {
      final controller = create(
        tester,
        const _Animator(
          duration: Duration(seconds: 2),
          repeat: true,
          reverse: true,
        ),
      );
      await tester.pump();
      // 2.5 s: halfway through the pass that comes back.
      await pumpFor(tester, const Duration(milliseconds: 2500));
      expect(controller.handle.value, closeTo(0.75, 0.03));

      // An asymmetric target, so a wrong direction shows.
      controller.handle.seek(0.8);
      await pumpFor(tester, const Duration(milliseconds: 400));

      // Still coming back: 0.8 minus 0.4 s of a 2 s pass.
      expect(controller.handle.value, closeTo(0.6, 0.03));
      controller.dispose();
    });

    testWidgets('delays count as progress', (tester) async {
      final controller = create(
        tester,
        const _Animator(
          duration: Duration(seconds: 3),
          delayStart: Duration(seconds: 1),
        ),
      );
      await tester.pump();
      controller.handle.pause();

      // The cycle lasts 4 s, so 0.25 is the end of the start delay.
      controller.handle.seek(0.25);
      expect(_Animator.progress.last, closeTo(0, 1e-9));
      controller.handle.seek(0.625);
      expect(_Animator.progress.last, closeTo(0.5, 1e-9));
      controller.dispose();
    });
  });

  group('progress', () {
    testWidgets('emits the progress on every frame and closes on dispose', (
      tester,
    ) async {
      final controller = create(tester, const _Animator());
      final values = <double>[];
      var closed = false;
      controller.handle.progress
          .listen(values.add, onDone: () => closed = true);
      await tester.pump();

      await pumpFor(tester, const Duration(seconds: 2));
      expect(values, isNotEmpty);
      expect(values.last, closeTo(0.5, 0.03));
      expect(values, orderedEquals([...values]..sort()));

      controller.dispose();
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('can be listened to by several listeners', (tester) async {
      final controller = create(tester, const _Animator());
      final first = <double>[];
      final second = <double>[];
      controller.handle.progress.listen(first.add);
      controller.handle.progress.listen(second.add);
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 1));

      expect(first, isNotEmpty);
      expect(second, first);
      controller.dispose();
    });
  });

  group('onComplete and onCycle', () {
    testWidgets('onComplete is called once when a single pass ends', (
      tester,
    ) async {
      final controller = create(tester, const _Animator());
      final calls = <String>[];
      controller.handle.onComplete = () => calls.add('complete');
      controller.handle.onCycle = (cycle) => calls.add('cycle $cycle');
      await tester.pump();

      await pumpFor(tester, const Duration(seconds: 5));

      expect(calls, ['cycle 1', 'complete']);
      expect(controller.handle.isCompleted, isTrue);
      expect(controller.handle.isPlaying, isFalse);
      controller.dispose();
    });

    testWidgets('an endless animation reports cycles but never completes', (
      tester,
    ) async {
      final controller = create(
        tester,
        const _Animator(duration: Duration(seconds: 1), repeat: true),
      );
      final cycles = <int>[];
      var completed = 0;
      controller.handle.onCycle = cycles.add;
      controller.handle.onComplete = () => completed++;
      await tester.pump();

      await pumpFor(tester, const Duration(milliseconds: 3600));

      expect(cycles, [1, 2, 3]);
      expect(completed, 0);
      expect(controller.handle.isCompleted, isFalse);
      controller.dispose();
    });

    testWidgets('a limited repeat reports every cycle and then completes', (
      tester,
    ) async {
      final controller = create(
        tester,
        const _Animator(
          duration: Duration(seconds: 1),
          repeat: true,
          repeatCount: 3,
        ),
      );
      final calls = <String>[];
      controller.handle.onComplete = () => calls.add('complete');
      controller.handle.onCycle = (cycle) => calls.add('cycle $cycle');
      await tester.pump();

      await pumpFor(tester, const Duration(seconds: 4));

      expect(calls, ['cycle 1', 'cycle 2', 'cycle 3', 'complete']);
      controller.dispose();
    });

    testWidgets('cycles are not repeated after a pause or a seek', (
      tester,
    ) async {
      final controller = create(
        tester,
        const _Animator(duration: Duration(seconds: 1), repeat: true),
      );
      final cycles = <int>[];
      controller.handle.onCycle = cycles.add;
      await tester.pump();

      await pumpFor(tester, const Duration(milliseconds: 1500));
      controller.handle.pause();
      controller.handle.resume();
      controller.handle.seek(0.5);
      await pumpFor(tester, const Duration(milliseconds: 600));

      expect(cycles, [1, 2]);
      controller.dispose();
    });

    testWidgets('onAnimationStop of the animator is still called', (
      tester,
    ) async {
      var stops = 0;
      final controller = PolylineAnimationController(
        vsync: tester,
        polyline: _line,
        polylineAnimator: _Stopping(() => stops++),
        polylineListener: (_) {},
      );
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 2));

      expect(stops, 1);
      controller.dispose();
    });
  });

  group('after dispose', () {
    testWidgets('the handle does nothing', (tester) async {
      final controller = create(tester, const _Animator());
      final handle = controller.handle;
      await tester.pump();
      controller.dispose();

      handle.pause();
      handle.resume();
      handle.seek(0.5);

      expect(handle.isPlaying, isTrue);
    });
  });

  group('MapAnimationController.polylineAnimation', () {
    testWidgets('returns the handle of an animated polyline only', (
      tester,
    ) async {
      GoogleMapsFlutterPlatform.instance = FakeMapsPlatform();
      final controller = MapAnimationController(
        mapId: 1,
        vsync: tester,
        polylines: {
          const AnimatedPolyline(
            polyline: _line,
            polylineAnimator: _Animator(repeat: true),
          ),
          const AnimatedPolyline(
              polyline: Polyline(polylineId: PolylineId('s'))),
        },
      );

      expect(controller.polylineAnimation(const PolylineId('p')), isNotNull);
      expect(controller.polylineAnimation(const PolylineId('s')), isNull);
      expect(controller.polylineAnimation(const PolylineId('nope')), isNull);
      controller.dispose();
    });

    testWidgets('the same handle is returned while the animator is the same', (
      tester,
    ) async {
      GoogleMapsFlutterPlatform.instance = FakeMapsPlatform();
      final controller = MapAnimationController(
        mapId: 1,
        vsync: tester,
        polylines: {
          const AnimatedPolyline(
            polyline: _line,
            polylineAnimator: _Animator(repeat: true),
          ),
        },
      );
      final first = controller.polylineAnimation(const PolylineId('p'));
      controller.updatePolylines({
        const AnimatedPolyline(
          polyline: _line,
          polylineAnimator: _Animator(repeat: true),
        ),
      });

      expect(controller.polylineAnimation(const PolylineId('p')), same(first));
      controller.dispose();
    });

    testWidgets('the handle stops working when the polyline is removed', (
      tester,
    ) async {
      GoogleMapsFlutterPlatform.instance = FakeMapsPlatform();
      final controller = MapAnimationController(
        mapId: 1,
        vsync: tester,
        polylines: {
          const AnimatedPolyline(
            polyline: _line,
            polylineAnimator: _Animator(repeat: true),
          ),
        },
      );
      final handle = controller.polylineAnimation(const PolylineId('p'))!;
      var closed = false;
      handle.progress.listen((_) {}, onDone: () => closed = true);

      controller.updatePolylines({});
      await tester.pump();

      expect(controller.polylineAnimation(const PolylineId('p')), isNull);
      expect(closed, isTrue);
      controller.dispose();
    });
  });
}

class _Stopping extends PolylineAnimator {
  const _Stopping(this.onStop) : super(duration: const Duration(seconds: 1));

  final void Function() onStop;

  @override
  Polyline animate(Polyline polyline, double progress) => polyline;

  @override
  void onAnimationStop() => onStop();
}

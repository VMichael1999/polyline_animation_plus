import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';
import 'package:polyline_animation_plus/src/managers/animated_marker_manager.dart';

Marker _marker(String id, double longitude) =>
    Marker(markerId: MarkerId(id), position: LatLng(0, longitude));

/// Pumps in small steps, like frames.
Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 20);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

class _Recorder {
  final updates = <Set<Marker>>[];
  final removed = <Set<MarkerId>>[];
  final positions = <String, double>{};

  void onUpdate(Set<Marker> markers) {
    updates.add(markers);
    for (final m in markers) {
      positions[m.markerId.value] = m.position.longitude;
    }
  }

  void onRemove(Set<MarkerId> ids) => removed.add(ids);
}

void main() {
  late _Recorder recorder;

  setUp(() => recorder = _Recorder());

  AnimatedMarkersManager create(
    WidgetTester tester, {
    MarkerAnimationMode mode = MarkerAnimationMode.queue,
    MarkerDuration duration = const MarkerDuration.fixed(Duration(seconds: 2)),
    Duration Function()? clock,
  }) =>
      AnimatedMarkersManager(
        vsync: tester,
        onUpdateMarkers: recorder.onUpdate,
        onRemoveMarkers: recorder.onRemove,
        mode: mode,
        duration: duration,
        clock: clock,
      );

  testWidgets('each marker moves on its own clock', (tester) async {
    final manager = create(tester);
    manager.push({_marker('a', 0), _marker('b', 0)});

    // a has two moves, b has one.
    manager.push({_marker('a', 0.001), _marker('b', 0.001)});
    manager.push({_marker('a', 0.002), _marker('b', 0.001)});
    await _pumpFor(tester, const Duration(milliseconds: 2100));
    expect(recorder.positions['b'], closeTo(0.001, 1e-9));

    // b gets a new position while a is still on its second move. It starts
    // right away instead of waiting for a.
    manager.push({_marker('a', 0.002), _marker('b', 0.002)});
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(recorder.positions['b'], closeTo(0.0015, 2e-5));
    expect(recorder.positions['a'], greaterThan(0.001));

    await _pumpFor(tester, const Duration(seconds: 3));
    expect(manager.isAnimating, isFalse);
    manager.dispose();
  });

  testWidgets('sends the changes of a frame together', (tester) async {
    final manager = create(tester);
    final start = {for (var i = 0; i < 50; i++) _marker('m$i', 0)};
    manager.push(start);
    manager.push({for (var i = 0; i < 50; i++) _marker('m$i', 0.001)});

    recorder.updates.clear();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(recorder.updates, hasLength(1));
    expect(recorder.updates.single, hasLength(50));
    manager.dispose();
  });

  testWidgets('does not send more than about one update per 16 ms', (
    tester,
  ) async {
    final manager = create(tester);
    manager.push({_marker('a', 0)});
    manager.push({_marker('a', 0.001)});
    recorder.updates.clear();

    await tester.pump();
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 4));
    }

    // 400 ms in 4 ms frames: at most one update per 16 ms.
    expect(recorder.updates.length, lessThanOrEqualTo(26));
    expect(recorder.updates.length, greaterThan(15));
    manager.dispose();
  });

  testWidgets('always sends the final position of a move', (tester) async {
    final manager = create(tester);
    manager.push({_marker('a', 0)});
    manager.push({_marker('a', 0.001)});

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2005));

    expect(recorder.positions['a'], 0.001);
    manager.dispose();
  });

  testWidgets('latestOnly follows the newest position without lagging', (
    tester,
  ) async {
    final manager = create(tester, mode: MarkerAnimationMode.latestOnly);
    manager.push({_marker('a', 0)});

    // A position every second, each move would take 2 s.
    for (var i = 1; i <= 5; i++) {
      manager.push({_marker('a', i * 0.001)});
      await _pumpFor(tester, const Duration(seconds: 1));
    }
    await _pumpFor(tester, const Duration(milliseconds: 1100));

    // Moving to the latest position, it has reached the last one soon after it
    // arrived instead of replaying the backlog.
    expect(recorder.positions['a'], closeTo(0.005, 1e-9));
    manager.dispose();
  });

  testWidgets('queue mode lags behind when positions arrive faster', (
    tester,
  ) async {
    final manager = create(tester);
    manager.push({_marker('a', 0)});

    // The same schedule as the latestOnly test above.
    for (var i = 1; i <= 5; i++) {
      manager.push({_marker('a', i * 0.001)});
      await _pumpFor(tester, const Duration(seconds: 1));
    }
    await _pumpFor(tester, const Duration(milliseconds: 1100));

    // Each move takes 2 s, so after 6.1 s only about 3 of the 5 moves are done.
    expect(recorder.positions['a'], lessThan(0.004));
    expect(manager.isAnimating, isTrue);
    manager.dispose();
  });

  testWidgets('adaptive durations follow the time between positions', (
    tester,
  ) async {
    var wallClock = Duration.zero;
    final manager = create(
      tester,
      mode: MarkerAnimationMode.latestOnly,
      duration: const MarkerDuration.adaptive(max: Duration(seconds: 2)),
      clock: () => wallClock,
    );
    manager.push({_marker('a', 0)});

    manager.push({_marker('a', 0.001)});
    wallClock = const Duration(seconds: 1);
    await _pumpFor(tester, const Duration(seconds: 1));
    manager.push({_marker('a', 0.002)});

    // The second position came 1 s after the first, so its move lasts 1 s.
    await _pumpFor(tester, const Duration(milliseconds: 1100));
    expect(recorder.positions['a'], closeTo(0.002, 1e-9));
    expect(manager.isAnimating, isFalse);
    manager.dispose();
  });

  testWidgets('a marker pushed again cancels its pending removal', (
    tester,
  ) async {
    final manager = create(tester);
    manager.push({_marker('a', 0)});
    manager.push({_marker('a', 0.001)});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    manager.removeMarker(const MarkerId('a'));
    manager.push({_marker('a', 0.001)});
    await _pumpFor(tester, const Duration(seconds: 3));

    expect(recorder.removed, isEmpty);
    manager.dispose();
  });

  testWidgets('dispose stops the updates', (tester) async {
    final manager = create(tester);
    manager.push({_marker('a', 0)});
    manager.push({_marker('a', 0.001)});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    manager.dispose();
    final updates = recorder.updates.length;
    await _pumpFor(tester, const Duration(seconds: 2));

    expect(recorder.updates.length, updates);
  });
}

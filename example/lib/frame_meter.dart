import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Measures how smooth the app is: frames per second and the slowest frame of
/// the last second.
class FrameMeter extends ChangeNotifier {
  int _frames = 0;
  Duration _worst = Duration.zero;
  DateTime _windowStart = DateTime.now();

  double fps = 0;
  double worstFrameMs = 0;

  void start() => SchedulerBinding.instance.addTimingsCallback(_onTimings);

  void stop() => SchedulerBinding.instance.removeTimingsCallback(_onTimings);

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frames++;
      if (timing.totalSpan > _worst) _worst = timing.totalSpan;
    }

    final now = DateTime.now();
    final elapsed = now.difference(_windowStart);
    if (elapsed < const Duration(seconds: 1)) return;

    fps = _frames * Duration.microsecondsPerSecond / elapsed.inMicroseconds;
    worstFrameMs = _worst.inMicroseconds / 1000;
    _frames = 0;
    _worst = Duration.zero;
    _windowStart = now;
    notifyListeners();
  }
}

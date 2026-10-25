// Internal, not exported: public API docs are only required for exported code.
// ignore_for_file: public_member_api_docs

import 'package:flutter/widgets.dart';

/// Tells when the app goes to the background and back, and when the user asks
/// the system to reduce motion.
class SystemObserver with WidgetsBindingObserver {
  SystemObserver({
    required this.onBackground,
    required this.onForeground,
    required this.onReduceMotionChanged,
  });

  final void Function() onBackground;
  final void Function() onForeground;
  final void Function(bool reduceMotion) onReduceMotionChanged;

  bool _inBackground = false;
  bool _reduceMotion = false;

  /// Whether the system asks to reduce motion right now.
  bool get reduceMotion => _reduceMotion;

  void attach() {
    final binding = WidgetsBinding.instance;
    _reduceMotion = _readReduceMotion(binding);
    binding.addObserver(this);
  }

  void detach() => WidgetsBinding.instance.removeObserver(this);

  static bool _readReduceMotion(WidgetsBinding binding) =>
      binding.platformDispatcher.accessibilityFeatures.disableAnimations;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` is a short interruption with the app still visible (a call
    // banner, the app switcher), so it does not count.
    final away = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;

    if (away && !_inBackground) {
      _inBackground = true;
      onBackground();
    } else if (state == AppLifecycleState.resumed && _inBackground) {
      _inBackground = false;
      onForeground();
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    final reduce = _readReduceMotion(WidgetsBinding.instance);
    if (reduce == _reduceMotion) return;

    _reduceMotion = reduce;
    onReduceMotionChanged(reduce);
  }
}

/// What happens when a new position arrives for a marker that is still moving.
enum MarkerAnimationMode {
  /// Every position is played in order, one move after the other.
  ///
  /// This is the default and the behavior of previous versions. If positions
  /// arrive faster than the moves finish, the marker falls behind.
  queue,

  /// The marker goes straight to the newest position, starting from where it
  /// is shown right now, and the positions in between are dropped.
  ///
  /// The marker never falls behind the latest position, which is what you want
  /// for live GPS tracking.
  latestOnly,
}

/// How long each marker move lasts.
final class MarkerDuration {
  /// Every move lasts exactly [duration].
  const MarkerDuration.fixed(Duration duration)
      : _duration = duration,
        _adaptive = false;

  /// Every move lasts as long as the time since the previous position of that
  /// marker arrived, so the marker reaches each position just when the next
  /// one comes in.
  ///
  /// The first move, and moves after a long pause, last [max]. A move is never
  /// shorter than 100 ms.
  const MarkerDuration.adaptive({required Duration max})
      : _duration = max,
        _adaptive = true;

  final Duration _duration;
  final bool _adaptive;

  /// The longest a move can last. For [MarkerDuration.fixed] it is the exact
  /// duration.
  Duration get maxDuration => _duration;

  /// Whether the duration follows the time between positions.
  bool get isAdaptive => _adaptive;

  /// Shortest duration of an adaptive move.
  static const Duration minAdaptive = Duration(milliseconds: 100);

  /// Duration of a move for a position that arrived [sinceLast] after the
  /// previous one, or `null` if it is the first one.
  Duration resolve(Duration? sinceLast) {
    if (!_adaptive || sinceLast == null) return _duration;

    final shortest = minAdaptive < _duration ? minAdaptive : _duration;
    if (sinceLast < shortest) return shortest;
    return sinceLast < _duration ? sinceLast : _duration;
  }

  @override
  bool operator ==(Object other) =>
      other is MarkerDuration &&
      other._duration == _duration &&
      other._adaptive == _adaptive;

  @override
  int get hashCode => Object.hash(_duration, _adaptive);

  @override
  String toString() => _adaptive
      ? 'MarkerDuration.adaptive(max: $_duration)'
      : 'MarkerDuration.fixed($_duration)';
}

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

import '../fakes/geo.dart';

void main() {
  // 1000 m, with a corner at 300 m.
  final polyline = Polyline(
    polylineId: const PolylineId('walk'),
    width: 4,
    points: [at(0, 0), at(300, 0), at(1000, 0)],
  );

  // One dash and gap is 20 m. A 1 s cycle at 20 m/s moves exactly one of them.
  const animator = DashFlowAnimator(dash: 10, gap: 10, speed: 20);

  double startOf(Polyline p) => metersOf(p.points.first).east;

  test('draws the dash pattern', () {
    final result = animator.animate(polyline, 0);

    expect(result.patterns, hasLength(2));
    expect(result.patterns.first.toJson(), PatternItem.dash(10).toJson());
    expect(result.patterns.last.toJson(), PatternItem.gap(10).toJson());
  });

  test('keeps the end of the route and cuts only the start', () {
    final result = animator.animate(polyline, 0.5);

    expect(metersOf(result.points.last).east, closeTo(1000, 0.5));
    expect(result.width, 4);
    expect(result.polylineId, polyline.polylineId);
  });

  test('moves the start forward as the cycle goes by', () {
    expect(startOf(animator.animate(polyline, 0)), closeTo(0, 0.5));
    expect(startOf(animator.animate(polyline, 0.25)), closeTo(5, 0.5));
    expect(startOf(animator.animate(polyline, 0.5)), closeTo(10, 0.5));
    expect(startOf(animator.animate(polyline, 0.75)), closeTo(15, 0.5));
  });

  test('the end of a cycle looks like its start', () {
    expect(startOf(animator.animate(polyline, 1)), closeTo(0, 0.5));
  });

  test('moves a whole number of dashes per cycle so the loop has no jump', () {
    // 2 s cycle at 30 m/s is 60 m: three periods of 20 m.
    const longer = DashFlowAnimator(
      speed: 30,
      duration: Duration(seconds: 2),
    );
    // A third of the cycle is exactly one period, which looks like the start.
    expect(startOf(longer.animate(polyline, 1 / 3)), closeTo(0, 0.5));
    expect(startOf(longer.animate(polyline, 1 / 6)), closeTo(10, 0.5));
    expect(startOf(longer.animate(polyline, 1)), closeTo(0, 0.5));
  });

  test('a cycle moves at least one period even at a very low speed', () {
    const slow = DashFlowAnimator(speed: 1);
    expect(startOf(slow.animate(polyline, 0.5)), closeTo(10, 0.5));
  });

  test('keeps the corners that are left in the line', () {
    final result = animator.animate(polyline, 0.5);

    expect(result.points, hasLength(3));
    expect(metersOf(result.points[1]).east, closeTo(300, 0.5));
  });

  test('a route shorter than one period is not cut', () {
    final tiny = polyline.copyWith(pointsParam: [at(0, 0), at(5, 0)]);
    final result = animator.animate(tiny, 0.9);

    expect(result.points, tiny.points);
    expect(result.patterns, hasLength(2));
  });

  test('a polyline without two different points keeps its points', () {
    final single = polyline.copyWith(pointsParam: [at(1, 1), at(1, 1)]);
    expect(animator.animate(single, 0.5).points, single.points);
  });

  test('loops with a one second cycle by default', () {
    expect(const DashFlowAnimator().repeat, isTrue);
    expect(const DashFlowAnimator().duration, const Duration(seconds: 1));
  });

  test('rejects values that do not make sense', () {
    expect(() => DashFlowAnimator(dash: 0), throwsAssertionError);
    expect(() => DashFlowAnimator(gap: -1), throwsAssertionError);
    expect(() => DashFlowAnimator(speed: 0), throwsAssertionError);
  });

  test('equality includes dash, gap and speed', () {
    expect(const DashFlowAnimator(), const DashFlowAnimator());
    expect(
        const DashFlowAnimator().hashCode, const DashFlowAnimator().hashCode);
    expect(const DashFlowAnimator(), isNot(const DashFlowAnimator(dash: 5)));
    expect(const DashFlowAnimator(), isNot(const DashFlowAnimator(gap: 5)));
    expect(const DashFlowAnimator(), isNot(const DashFlowAnimator(speed: 5)));
  });
}

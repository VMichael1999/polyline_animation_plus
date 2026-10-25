// `Color.value` is deprecated on new Flutter but is the only way to compare
// colors on the minimum supported version.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';
import 'package:polyline_animation_plus/src/managers/animated_polyline_manager.dart';

const _id = PolylineId('p');
const _other = PolylineId('q');
const _polyline = Polyline(
  polylineId: _id,
  points: [LatLng(0, 0), LatLng(0, 1)],
);

void main() {
  testWidgets('keeps one controller per polyline and replaces it on change', (
    tester,
  ) async {
    final updates = <Polyline>[];
    final manager = AnimatedPolylineManager(
      vsync: tester,
      polylinesListener: (_, polylines) => updates.addAll(polylines),
    );

    manager.push(
      polyline: _polyline,
      polylineAnimator: const SnackAnimator(repeat: true),
    );
    manager.push(
      polyline: _polyline,
      polylineAnimator: const SnackAnimator(repeat: true),
    );
    expect(manager.activePolylineIds, [_id]);

    // A different animator replaces the running one.
    manager.push(
      polyline: _polyline,
      polylineAnimator: const SnackAnimator(
        repeat: true,
        delayStart: Duration(seconds: 1),
      ),
    );
    expect(manager.activePolylineIds, [_id]);

    manager.dispose();
    expect(manager.activePolylineIds, isEmpty);
  });

  testWidgets('removes polylines one at a time or in bulk', (tester) async {
    final manager = AnimatedPolylineManager(
      vsync: tester,
      polylinesListener: (_, __) {},
    );
    const animator = SnackAnimator(repeat: true);
    manager.push(polyline: _polyline, polylineAnimator: animator);
    manager.push(
      polyline: const Polyline(polylineId: _other),
      polylineAnimator: animator,
    );

    manager.removePolyline(_other);
    manager.removePolyline(const PolylineId('missing'));
    expect(manager.activePolylineIds, [_id]);

    manager.removePolylines({_id});
    expect(manager.activePolylineIds, isEmpty);
    manager.dispose();
  });

  testWidgets('a pushed polyline update is used by the running animation', (
    tester,
  ) async {
    final updates = <Polyline>[];
    final manager = AnimatedPolylineManager(
      vsync: tester,
      polylinesListener: (_, polylines) => updates.addAll(polylines),
    );
    const animator = SnackAnimator(
      duration: Duration(seconds: 2),
      curve: Curves.linear,
    );
    manager.push(polyline: _polyline, polylineAnimator: animator);
    await tester.pump();

    manager.push(
      polyline: _polyline.copyWith(colorParam: Colors.red),
      polylineAnimator: animator,
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(updates.last.color.value, Colors.red.value);
    manager.dispose();
  });
}

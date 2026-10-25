import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/src/controllers/marker_controller.dart';

const _id = MarkerId('m');
const _origin = LatLng(0, 0);
const _east = LatLng(0, 0.001);

MarkerController _controller(
  AnimationController animation,
  Marker marker, {
  bool useMarkerRotation = false,
}) =>
    MarkerController(
      marker: marker,
      animationController: animation,
      useMarkerRotation: useMarkerRotation,
    );

void main() {
  late AnimationController animation;

  setUp(() => animation = AnimationController(vsync: const TestVSync()));
  tearDown(() => animation.dispose());

  test('a marker that does not move keeps its rotation', () {
    final controller = _controller(
      animation,
      const Marker(markerId: _id, position: _origin, rotation: 90),
    );
    controller.pushToQueue(
      const Marker(markerId: _id, position: _origin, rotation: 90, alpha: 0.5),
    );
    controller.setupNextMarker();

    expect(controller.animate(0.0).rotation, 90);
    expect(controller.animate(0.5).rotation, 90);
    expect(controller.animate(1.0).rotation, 90);
  });

  test('a marker that moves rotates towards the heading', () {
    final controller = _controller(
      animation,
      const Marker(markerId: _id, position: _origin),
    );
    controller.pushToQueue(const Marker(markerId: _id, position: _east));
    controller.setupNextMarker();

    expect(controller.animate(1.0).rotation, closeTo(90, 1e-6));
  });

  test('useMarkerRotation takes the rotation from the marker', () {
    final controller = _controller(
      animation,
      const Marker(markerId: _id, position: _origin),
      useMarkerRotation: true,
    );
    controller.pushToQueue(
      const Marker(markerId: _id, position: _east, rotation: 45),
    );
    controller.setupNextMarker();

    expect(controller.animate(1.0).rotation, closeTo(45, 1e-6));
  });

  group('queue', () {
    test('ignores a marker equal to the last one waiting', () {
      final controller = _controller(
        animation,
        const Marker(markerId: _id, position: _origin),
      );
      const next = Marker(markerId: _id, position: _east);

      controller.pushToQueue(next);
      controller.pushToQueue(next);

      controller.setupNextMarker();
      expect(controller.hasMarker, isFalse);
    });

    test('ignores a marker equal to the current one when nothing waits', () {
      final controller = _controller(
        animation,
        const Marker(markerId: _id, position: _origin),
      );

      controller.pushToQueue(const Marker(markerId: _id, position: _origin));

      expect(controller.hasMarker, isFalse);
    });

    test('keeps different positions in order', () {
      final controller = _controller(
        animation,
        const Marker(markerId: _id, position: _origin),
      );

      controller.pushToQueue(const Marker(markerId: _id, position: _east));
      controller
          .pushToQueue(const Marker(markerId: _id, position: LatLng(1, 1)));

      controller.setupNextMarker();
      expect(controller.currentMarker.position, _east);
      expect(controller.hasMarker, isTrue);
    });
  });
}

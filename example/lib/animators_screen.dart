import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

import 'data.dart';
import 'widgets.dart';

const _routeId = PolylineId('route');

/// A route drawn with each of the animators, with controls to pause it, move
/// it to a point and follow its progress.
class AnimatorsScreen extends StatefulWidget {
  const AnimatorsScreen({super.key});

  @override
  State<AnimatorsScreen> createState() => _AnimatorsScreenState();
}

class _AnimatorsScreenState extends State<AnimatorsScreen>
    with TickerProviderStateMixin {
  static const _segments = [
    RouteSegment(from: 0.00, to: 0.35, color: Color(0xFF1E9E5A)),
    RouteSegment(from: 0.35, to: 0.60, color: Color(0xFFF2A900)),
    RouteSegment(from: 0.60, to: 0.80, color: Color(0xFFE53935)),
    RouteSegment(from: 0.80, to: 1.00, color: Color(0xFF1E9E5A)),
  ];

  /// The animators to try, by name.
  late final Map<String, AnimatedPolyline Function()> _options = {
    'SnackAnimator':
        () => _plain(
          const SnackAnimator(
            duration: Duration(seconds: 4),
            repeat: true,
            curve: Curves.easeInOut,
          ),
        ),
    'FadeInProgressiveAnimator':
        () => _plain(
          const FadeInProgressiveAnimator(
            duration: Duration(seconds: 4),
            delayStart: Duration(seconds: 1),
          ),
        ),
    'ColorTransitionAnimation':
        () => _plain(
          const ColorTransitionAnimation(
            colors: [Colors.red, Colors.blue, Colors.green],
            duration: Duration(seconds: 6),
            repeat: true,
          ),
        ),
    'PulseAnimator': () => _plain(const PulseAnimator()),
    'DashFlowAnimator': () => _plain(const DashFlowAnimator()),
    'Colors by section': () => _segmented(null),
    'Colors by section + Snack':
        () => _segmented(
          const SnackAnimator(
            duration: Duration(seconds: 4),
            repeat: true,
            curve: Curves.linear,
          ),
        ),
    'Colors by section + Fade':
        () => _segmented(
          const FadeInProgressiveAnimator(duration: Duration(seconds: 4)),
        ),
  };

  MapAnimationController? _controller;
  PolylineAnimationHandle? _handle;
  StreamSubscription<double>? _progressSubscription;

  String _choice = 'SnackAnimator';
  double _progress = 0;
  int _cycles = 0;
  bool _completed = false;
  bool _paused = false;

  AnimatedPolyline _plain(PolylineAnimator animator) => AnimatedPolyline(
    polyline: Polyline(
      polylineId: _routeId,
      color: const Color(0xFF1565C0),
      width: 6,
      points: coordinates1,
    ),
    polylineAnimator: animator,
  );

  AnimatedPolyline _segmented(PolylineAnimator? animator) =>
      AnimatedPolyline.segmented(
        id: _routeId,
        points: coordinates1,
        segments: _segments,
        polylineAnimator: animator,
        width: 7,
      );

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _show(String choice) {
    final controller = _controller;
    if (controller == null) return;

    _choice = choice;
    _cycles = 0;
    _completed = false;
    _paused = false;
    _progress = 0;

    // The grey line under the animation is a static polyline.
    controller.updatePolylines({
      AnimatedPolyline(
        polyline: Polyline(
          polylineId: const PolylineId('base'),
          color: Colors.grey,
          width: 3,
          points: coordinates1,
        ),
      ),
      _options[choice]!(),
    });

    _progressSubscription?.cancel();
    final handle = controller.polylineAnimation(_routeId);
    _handle = handle;
    if (handle != null) {
      handle.onCycle = (cycle) => setState(() => _cycles = cycle);
      handle.onComplete = () => setState(() => _completed = true);
      _progressSubscription = handle.progress.listen((value) {
        if (mounted) setState(() => _progress = value);
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final handle = _handle;

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: coordinates1.first,
            zoom: 16,
          ),
          onMapCreated: (map) {
            _controller = MapAnimationController(mapId: map.mapId, vsync: this);
            map.animateCamera(
              CameraUpdate.newLatLngBounds(
                MapAnimationUtils.boundsOf(coordinates1),
                60,
              ),
            );
            _show(_choice);
          },
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: MapChip(
              handle == null
                  ? 'This option has no animation to control'
                  : 'progress ${_progress.toStringAsFixed(2)} · passes $_cycles${_completed ? ' · completed' : ''}',
            ),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.34,
          minChildSize: 0.12,
          maxChildSize: 0.8,
          builder:
              (context, scroll) => Material(
                elevation: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  children: [
                    Section(
                      title: 'Animator',
                      children: [
                        DropdownButton<String>(
                          isExpanded: true,
                          value: _choice,
                          items: [
                            for (final name in _options.keys)
                              DropdownMenuItem(value: name, child: Text(name)),
                          ],
                          onChanged: (name) {
                            if (name != null) _show(name);
                          },
                        ),
                      ],
                    ),
                    Section(
                      title: 'Control (PolylineAnimationHandle)',
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(
                              onPressed:
                                  handle == null
                                      ? null
                                      : () {
                                        if (_paused) {
                                          handle.resume();
                                        } else {
                                          handle.pause();
                                        }
                                        setState(() => _paused = !_paused);
                                      },
                              child: Text(_paused ? 'Resume' : 'Pause'),
                            ),
                            OutlinedButton(
                              onPressed:
                                  handle == null ? null : () => handle.seek(0),
                              child: const Text('Seek 0'),
                            ),
                            OutlinedButton(
                              onPressed:
                                  handle == null
                                      ? null
                                      : () => handle.seek(0.5),
                              child: const Text('Seek 0.5'),
                            ),
                          ],
                        ),
                        Slider(
                          value: _progress.clamp(0, 1),
                          onChanged: handle?.seek,
                        ),
                        const Text(
                          'Drag the slider to seek. Reduce motion (system settings) '
                          'draws the route as it is. Send the app to the background '
                          'and back to see the animation go on from where it was.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ),
      ],
    );
  }
}

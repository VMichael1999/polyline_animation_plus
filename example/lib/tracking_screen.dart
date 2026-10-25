import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

import 'data.dart';
import 'frame_meter.dart';
import 'gps_simulator.dart';
import 'widgets.dart';

const _carId = MarkerId('car');

/// A car that drives along a route while a simulated GPS reports its position.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  final List<LatLng> _route = coordinates1;
  final _meter = FrameMeter();

  MapAnimationController? _controller;
  GoogleMapController? _map;
  BitmapDescriptor? _icon;
  late final GpsSimulator _gps;

  // What the controls set.
  MarkerAnimationMode _mode = MarkerAnimationMode.queue;
  bool _adaptive = false;
  double _moveSeconds = 2;
  bool _followRoute = true;
  bool _consumeRoute = true;
  double _tolerance = 30;
  bool _followCamera = false;
  CameraBearing _bearing = CameraBearing.vehicle;
  double _tilt = 0;

  // What is shown.
  int _fixes = 0;
  int _markerFrames = 0;
  int _markerFramesPerSecond = 0;
  int _offRouteCount = 0;
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _gps = GpsSimulator(
      route: _route,
      onPosition: _onPosition,
      onFinished: () => setState(() {}),
    );
    _meter
      ..addListener(() => setState(() {}))
      ..start();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _markerFramesPerSecond = _markerFrames;
        _markerFrames = 0;
      });
    });
    BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(26, 48)),
      'assets/car.png',
    ).then((icon) {
      if (!mounted) return;
      setState(() => _icon = icon);
      _rebuildController();
    });
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _gps.dispose();
    _meter
      ..stop()
      ..dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onPosition(LatLng position) {
    _fixes++;
    _controller?.updateVehicle(position);
    setState(() {});
  }

  /// Creates the controller again. Some options can only be given when it is
  /// created.
  void _rebuildController() {
    final map = _map;
    if (map == null || _icon == null) return;

    _controller?.dispose();
    final controller = MapAnimationController(
      mapId: map.mapId,
      vsync: this,
      markers: {
        Marker(
          markerId: _carId,
          position: _route.first,
          icon: _icon!,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndexInt: 2,
        ),
      },
      markerAnimationMode: _mode,
      markerDuration:
          _adaptive
              ? MarkerDuration.adaptive(
                max: Duration(milliseconds: (_moveSeconds * 1000).round()),
              )
              : MarkerDuration.fixed(
                Duration(milliseconds: (_moveSeconds * 1000).round()),
              ),
      markerListener: (_) => _markerFrames++,
    );
    _controller = controller;
    _applyTracking();
    _applyCamera();
    _gps.reset();
    setState(() {});
  }

  void _applyTracking() {
    _controller?.trackVehicle(
      VehicleTracking(
        markerId: _carId,
        route: _route,
        traveled: const RouteStyle(color: Color(0xFF9E9E9E), width: 6),
        remaining: const RouteStyle(color: Color(0xFF1565C0), width: 6),
        snapToleranceMeters: _tolerance,
        followRoute: _followRoute,
        consumeRoute: _consumeRoute,
        onOffRoute: (position) {
          _offRouteCount++;
          if (!mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Off route: the car goes where the GPS says'),
                duration: Duration(seconds: 2),
              ),
            );
        },
      ),
    );
  }

  void _applyCamera() {
    final controller = _controller;
    if (controller == null) return;

    if (!_followCamera) {
      controller.stopFollowingCamera();
      return;
    }
    controller.followCamera(
      CameraFollow(
        markerId: _carId,
        zoom: 18,
        tilt: _tilt,
        bearing: _bearing,
        onFollowStopped: () {
          if (!mounted) return;
          setState(() => _followCamera = false);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'You moved the map: the camera stopped following',
                ),
                duration: Duration(seconds: 2),
              ),
            );
        },
      ),
    );
  }

  void _restart() {
    _gps.reset();
    _applyTracking();
    _controller?.updateMarkers({
      Marker(
        markerId: _carId,
        position: _route.first,
        icon: _icon!,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndexInt: 2,
      ),
    });
    _fixes = 0;
    _offRouteCount = 0;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _route.first, zoom: 16),
          onMapCreated: (map) {
            _map = map;
            map.animateCamera(
              CameraUpdate.newLatLngBounds(
                MapAnimationUtils.boundsOf(_route),
                60,
              ),
            );
            _rebuildController();
          },
          onCameraMoveStarted: () => _controller?.onCameraMoveStarted(),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                MapChip(
                  '${_meter.fps.toStringAsFixed(0)} fps · slowest frame ${_meter.worstFrameMs.toStringAsFixed(0)} ms',
                ),
                MapChip(
                  'GPS positions $_fixes · marker updates/s $_markerFramesPerSecond · off route $_offRouteCount',
                ),
                MapChip(
                  '${_gps.along.toStringAsFixed(0)} of ${_gps.length.toStringAsFixed(0)} m',
                ),
              ],
            ),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.12,
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
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    _simulationControls(),
                    _markerControls(),
                    _trackingControls(),
                    _cameraControls(),
                  ],
                ),
              ),
        ),
      ],
    );
  }

  Widget _simulationControls() => Section(
    title: 'Simulated GPS',
    children: [
      Wrap(
        spacing: 8,
        children: [
          FilledButton.icon(
            onPressed:
                _icon == null
                    ? null
                    : () {
                      if (_gps.isRunning) {
                        _gps.stop();
                      } else {
                        if (_gps.isFinished) _restart();
                        _gps.start();
                      }
                      setState(() {});
                    },
            icon: Icon(_gps.isRunning ? Icons.pause : Icons.play_arrow),
            label: Text(_gps.isRunning ? 'Pause' : 'Drive'),
          ),
          OutlinedButton(onPressed: _restart, child: const Text('Restart')),
          OutlinedButton(
            onPressed: _gps.sendOffRoute,
            child: const Text('Go off route'),
          ),
        ],
      ),
      LabeledSlider(
        label: 'Speed',
        value: _gps.speed,
        min: 3,
        max: 40,
        display: '${_gps.speed.toStringAsFixed(0)} m/s',
        onChanged: (v) => setState(() => _gps.speed = v),
      ),
      LabeledSlider(
        label: 'GPS every',
        value: _gps.interval.inMilliseconds / 1000,
        min: 0.5,
        max: 5,
        divisions: 9,
        display:
            '${(_gps.interval.inMilliseconds / 1000).toStringAsFixed(1)} s',
        onChanged:
            (v) => setState(
              () => _gps.interval = Duration(milliseconds: (v * 1000).round()),
            ),
      ),
      LabeledSlider(
        label: 'GPS noise',
        value: _gps.noiseMeters,
        min: 0,
        max: 25,
        display: '${_gps.noiseMeters.toStringAsFixed(0)} m',
        onChanged: (v) => setState(() => _gps.noiseMeters = v),
      ),
    ],
  );

  Widget _markerControls() => Section(
    title: 'Marker animation',
    children: [
      SegmentedButton<MarkerAnimationMode>(
        segments: const [
          ButtonSegment(value: MarkerAnimationMode.queue, label: Text('queue')),
          ButtonSegment(
            value: MarkerAnimationMode.latestOnly,
            label: Text('latestOnly'),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (v) {
          _mode = v.first;
          _rebuildController();
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Adaptive duration'),
        subtitle: const Text(
          'Each move lasts as long as the time between positions',
        ),
        value: _adaptive,
        onChanged: (v) {
          _adaptive = v;
          _rebuildController();
        },
      ),
      LabeledSlider(
        label: _adaptive ? 'Max move' : 'Move lasts',
        value: _moveSeconds,
        min: 0.5,
        max: 5,
        divisions: 9,
        display: '${_moveSeconds.toStringAsFixed(1)} s',
        onChanged: (v) => setState(() => _moveSeconds = v),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _rebuildController,
          child: const Text('Apply duration'),
        ),
      ),
    ],
  );

  Widget _trackingControls() => Section(
    title: 'Vehicle tracking',
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('followRoute'),
        subtitle: const Text('The car takes the route and turns at corners'),
        value: _followRoute,
        onChanged: (v) {
          _followRoute = v;
          _applyTracking();
          setState(() {});
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('consumeRoute'),
        subtitle: const Text('Travelled part in grey, remaining in blue'),
        value: _consumeRoute,
        onChanged: (v) {
          _consumeRoute = v;
          _applyTracking();
          setState(() {});
        },
      ),
      LabeledSlider(
        label: 'Tolerance',
        value: _tolerance,
        min: 5,
        max: 60,
        display: '${_tolerance.toStringAsFixed(0)} m',
        onChanged: (v) => setState(() => _tolerance = v),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _applyTracking,
          child: const Text('Apply tolerance'),
        ),
      ),
    ],
  );

  Widget _cameraControls() => Section(
    title: 'Camera',
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Follow the car'),
        subtitle: const Text('Move the map yourself to stop it'),
        value: _followCamera,
        onChanged: (v) {
          _followCamera = v;
          _applyCamera();
          setState(() {});
        },
      ),
      SegmentedButton<CameraBearing>(
        segments: const [
          ButtonSegment(
            value: CameraBearing.vehicle,
            label: Text('Turns with car'),
          ),
          ButtonSegment(value: CameraBearing.north, label: Text('North up')),
        ],
        selected: {_bearing},
        onSelectionChanged: (v) {
          _bearing = v.first;
          _applyCamera();
          setState(() {});
        },
      ),
      LabeledSlider(
        label: 'Tilt',
        value: _tilt,
        min: 0,
        max: 60,
        display: '${_tilt.toStringAsFixed(0)}°',
        onChanged: (v) {
          setState(() => _tilt = v);
          _applyCamera();
        },
      ),
    ],
  );
}

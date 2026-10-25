import 'package:flutter/material.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'data.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  GoogleMapController? mapController;
  MapAnimationController? mapAnimationController;

  final Set<AnimatedPolyline> _polylines = {
    AnimatedPolyline(
      polyline: Polyline(
        polylineId: PolylineId('front'),
        color: Colors.black,
        width: 2,
        points: MapAnimationUtils.generateEquidistantPolylineByDuration(
          path: coordinates1,
          duration: const Duration(seconds: 4),
        ),
      ),
      polylineAnimator: FadeInProgressiveAnimator(
        repeat: true,
        curve: Curves.linear,
        duration: const Duration(seconds: 4),
        delayStart: const Duration(seconds: 1),
      ),
    ),
    AnimatedPolyline(
      polyline: Polyline(
        polylineId: PolylineId('back'),
        color: Colors.grey,
        width: 2,
        points: coordinates1,
      ),
    ),
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    mapAnimationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Map Screen',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: coordinates1.first,
          zoom: 16.0,
        ),
        onMapCreated: (controller) {
          mapController = controller;
          mapAnimationController = MapAnimationController(
            mapId: controller.mapId,
            vsync: this,
            polylines: _polylines,
          );
          // Move camera to show the whole polyline
          final bounds = MapAnimationUtils.boundsOf(coordinates1);
          controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
        },
      ),
    );
  }
}

// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../managers/animated_marker_manager.dart';
import '../managers/animated_polyline_manager.dart';
import '../model/animated_polyline.dart';
import '../model/marker_animation.dart';

/// Called with the polyline that was just drawn on the map.
typedef PolylineListener = void Function(Polyline);

/// Called with the markers that were just updated on the map.
typedef MarkerListener = void Function(Set<Marker>);

/// Animates polylines and markers on a Google Map.
///
/// It draws directly on the map with the given [mapId], so the `GoogleMap`
/// widget must not receive polylines or markers with the same IDs. Call
/// [dispose] when the map goes away.
final class MapAnimationController {
  /// Drives the animations, usually the `State` of the map widget mixed with
  /// `TickerProviderStateMixin`.
  final TickerProvider vsync;

  /// Called every time animated markers are updated, once per frame.
  final MarkerListener? markerListener;

  /// ID of the map to draw on, from `GoogleMapController.mapId`.
  final int mapId;

  /// Use [Marker.rotation] as the rotation of animated markers instead of the
  /// heading between consecutive positions. Default is false.
  final bool useMarkerRotation;

  /// Duration of each marker move. Default is 2 seconds.
  ///
  /// It is a shortcut for `markerDuration: MarkerDuration.fixed(...)` and is
  /// ignored when [markerDuration] is given.
  final Duration markersAnimationDuration;

  /// How long each marker move lasts. Overrides [markersAnimationDuration].
  ///
  /// Use [MarkerDuration.adaptive] to make every move last as long as the time
  /// between positions, which suits live GPS updates.
  final MarkerDuration? markerDuration;

  /// What a marker does when a new position arrives while it is still moving.
  /// Default is [MarkerAnimationMode.queue].
  final MarkerAnimationMode markerAnimationMode;

  /// Creates a controller and immediately draws [markers] and [polylines].
  ///
  /// Polylines with a [AnimatedPolyline.polylineAnimator] are animated, the
  /// others are drawn as they are.
  MapAnimationController({
    required this.mapId,
    required this.vsync,
    Set<Marker> markers = const {},
    Set<AnimatedPolyline> polylines = const {},
    this.markersAnimationDuration = const Duration(milliseconds: 2000),
    this.markerListener,
    this.useMarkerRotation = false,
    this.markerDuration,
    this.markerAnimationMode = MarkerAnimationMode.queue,
  }) {
    _initialize(markers, polylines);
  }

  /// Manager responsible for animating marker transitions
  late final AnimatedMarkersManager _animatedMarkersManager;

  /// Manager responsible for animating polyline drawing and updates
  late final AnimatedPolylineManager _animatedPolylineManager;

  final Map<MarkerId, Marker> _markers = {};

  final Map<PolylineId, Polyline> _polylines = {};

  void _initialize(Set<Marker> markers, Set<AnimatedPolyline> polylines) {
    // The initial markers are drawn directly on the map; the manager only
    // needs to know them so that later updates can move them.

    _markers.addAll(keyByMarkerId(markers));
    final markerSet = _markers.values.toSet();

    _updateMarkersOnMap({}, markerSet);

    // Set up the markers animation manager
    _animatedMarkersManager = AnimatedMarkersManager(
      vsync: vsync,
      mode: markerAnimationMode,
      duration:
          markerDuration ?? MarkerDuration.fixed(markersAnimationDuration),
      onUpdateMarkers: _updateMarker,
      onRemoveMarkers: _removeMarker,
      useMarkerRotation: useMarkerRotation,
    );

    _animatedMarkersManager.push(markerSet);

    // -- Polylines Initialization --

    // Set up the polylines animation manager
    _animatedPolylineManager = AnimatedPolylineManager(
      vsync: vsync,
      polylineListener: _updatePolyline,
    );

    // Add all polylines to animate

    for (var i in polylines) {
      if (i.polylineAnimator != null) {
        _animatedPolylineManager.push(
          polyline: i.polyline,
          polylineAnimator: i.polylineAnimator!,
        );
      } else {
        // If no animation is provided, add the polyline directly to the map
        _polylines[i.polyline.polylineId] = i.polyline.clone();
      }
    }

    _updatePolylinesOnMap({}, _polylines.values.toSet());
  }

  /// Sets the markers shown on the map.
  ///
  /// [updatedMarkers] is the full set: markers that are not in it are removed.
  /// A marker that is already on the map glides to its new position. Positions
  /// that arrive during a move wait in a queue.
  void updateMarkers(Set<Marker> updatedMarkers) {
    final newMarkersById = keyByMarkerId(updatedMarkers);

    // Identify markers that were added, removed, or updated
    final oldIds = _markers.keys.toSet();
    final newIds = newMarkersById.keys.toSet();

    final removedIds = oldIds.difference(
      newIds,
    ); // Markers that no longer exist
    final addedIds = newIds.difference(oldIds); // Newly added markers

    if (removedIds.isNotEmpty) {
      for (final id in removedIds) {
        _animatedMarkersManager.removeMarker(id);
      }
    }

    // New markers are drawn where they are, without animation. The manager
    // only moves markers it already knows.
    if (addedIds.isNotEmpty) {
      _updateMarker({for (final id in addedIds) newMarkersById[id]!});
    }

    // Push all new markers to the animation manager
    // so that they can be animated on marker update
    if (newMarkersById.isNotEmpty) {
      final markerSet = newMarkersById.values.toSet();

      _animatedMarkersManager.push(markerSet);
    }
  }

  /// Add/update or remove polylines on the map
  /// This method will handle both animated and non-animated polylines.
  /// If a polyline has an animator, it will be animated.
  /// If not, it will be updated directly on the map.
  void updatePolylines(Set<AnimatedPolyline> updatedPolylines) {
    final newPolyLineById = keyByPolylineId(
      updatedPolylines.map((p) => p.polyline),
    );

    // An animated polyline is only on the map after its first frame, but its
    // controller exists from the start, so both must be considered.
    final oldIds = {
      ..._polylines.keys,
      ..._animatedPolylineManager.activePolylineIds,
    };
    final newIds = newPolyLineById.keys.toSet();

    final removedIds = oldIds.difference(newIds);

    if (removedIds.isNotEmpty) {
      _animatedPolylineManager.removePolylines(removedIds);
      _removePolylines(removedIds);
    }

    if (updatedPolylines.isNotEmpty) {
      for (final p in updatedPolylines) {
        if (p.polylineAnimator != null) {
          _animatedPolylineManager.push(
            polyline: p.polyline,
            polylineAnimator: p.polylineAnimator!,
          );
        } else {
          final poly = p.polyline;
          _updatePolyline(poly);

          // Make sure to remove controller, in case it exits before
          // no effect if controller does not exist
          _animatedPolylineManager.removePolyline(poly.polylineId);
        }
      }
    }
  }

  /// Update Polyline directly on the map
  /// This method is used to update a static polyline that does not have an animator.
  /// Useful for update the polyline on marker update using [markerListener].
  void updateStaticPolyline(Polyline polyline) {
    _updatePolyline(polyline);
  }

  void _removeMarker(Set<MarkerId> markerIds) {
    final prevMarkers = Set<Marker>.from(_markers.values);

    for (final markerId in markerIds) {
      _markers.remove(markerId);
    }
    _updateMarkersOnMap(prevMarkers, _markers.values.toSet());
  }

  void _updateMarker(Set<Marker> updatedMarkers) {
    final prevMarkers = Set<Marker>.from(_markers.values);

    for (final marker in updatedMarkers) {
      _markers[marker.markerId] = marker;
    }

    // Notify external listeners
    markerListener?.call(updatedMarkers);

    _updateMarkersOnMap(prevMarkers, _markers.values.toSet());
  }

  void _updatePolyline(Polyline updatedPolyline) {
    final prevPolylines = Set<Polyline>.from(_polylines.values);

    _polylines[updatedPolyline.polylineId] = updatedPolyline;

    _updatePolylinesOnMap(prevPolylines, _polylines.values.toSet());
  }

  void _removePolylines(Set<PolylineId> polylineIds) {
    final prevPolyline = Set<Polyline>.from(_polylines.values);

    for (final id in polylineIds) {
      _polylines.remove(id);
    }
    _updatePolylinesOnMap(prevPolyline, _polylines.values.toSet());
  }

  Future<void> _updateMarkersOnMap(
    Set<Marker> previous,
    Set<Marker> current,
  ) async {
    GoogleMapsFlutterPlatform.instance.updateMarkers(
      MarkerUpdates.from(previous, current),
      mapId: mapId,
    );
  }

  Future<void> _updatePolylinesOnMap(
    Set<Polyline> previous,
    Set<Polyline> current,
  ) async {
    GoogleMapsFlutterPlatform.instance.updatePolylines(
      PolylineUpdates.from(previous, current),
      mapId: mapId,
    );
  }

  /// Stops all animations and releases their resources.
  ///
  /// The controller cannot be used afterwards.
  void dispose() {
    _animatedMarkersManager.dispose();
    _animatedPolylineManager.dispose();
    _markers.clear();
    _polylines.clear();
  }
}

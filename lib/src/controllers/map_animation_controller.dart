// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../managers/animated_marker_manager.dart';
import '../managers/animated_polyline_manager.dart';
import '../model/animated_polyline.dart';
import '../model/marker_animation.dart';
import '../model/polyline_animation_handle.dart';
import '../model/vehicle_tracking.dart';
import 'marker_controller.dart';
import 'tracked_vehicle.dart';
import 'vehicle_tracker.dart';

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

  final Map<MarkerId, TrackedVehicle> _vehicles = {};

  /// The extra polylines an animation draws besides the animated polyline
  /// itself (see PolylineAnimator.animateAll), by animated polyline.
  final Map<PolylineId, Set<PolylineId>> _extras = {};

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
      polylinesListener: _updateAnimated,
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
    // The marker of a tracked vehicle is moved by updateVehicle, so it is
    // neither removed nor moved from here.
    final newMarkersById = keyByMarkerId(
      updatedMarkers.where((m) => !_vehicles.containsKey(m.markerId)),
    );

    // Identify markers that were added, removed, or updated
    final oldIds = _markers.keys.toSet()..removeAll(_vehicles.keys);
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
    // The lines of a tracked vehicle and the extra polylines of an animation
    // belong to the package, not to the set the app gives.
    final owned = {
      for (final v in _vehicles.values) ...v.polylineIds,
      for (final extras in _extras.values) ...extras,
    };
    final oldIds = {
      ..._polylines.keys,
      ..._animatedPolylineManager.activePolylineIds,
    }..removeAll(owned);
    final newIds = newPolyLineById.keys.toSet();

    final removedIds = oldIds.difference(newIds);

    if (removedIds.isNotEmpty) {
      _animatedPolylineManager.removePolylines(removedIds);
      _removePolylines({
        ...removedIds,
        for (final id in removedIds) ...?_extras.remove(id),
      });
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
          final extras = _extras.remove(poly.polylineId);
          if (extras != null) _removePolylines(extras);
        }
      }
    }
  }

  /// Starts following a vehicle along a route.
  ///
  /// From now on the position given to [updateVehicle] is put on
  /// [VehicleTracking.route], the marker moves along it and the route is drawn
  /// as the part already travelled and the part still to go.
  ///
  /// The marker of the vehicle is created at the start of the route if it does
  /// not exist. While the vehicle is tracked, [updateMarkers] does not move or
  /// remove its marker. Tracking the same marker again replaces the previous
  /// tracking.
  void trackVehicle(VehicleTracking tracking) {
    stopTrackingVehicle(tracking.markerId);

    final id = tracking.markerId;
    final base = _markers[id];
    final vehicle = TrackedVehicle(
      tracking,
      base ?? Marker(markerId: id, position: tracking.route.first),
    );
    _vehicles[id] = vehicle;

    if (base == null) {
      _updateMarker({vehicle.baseMarker});
      _animatedMarkersManager.push({vehicle.baseMarker});
    }
    _drawRoute(vehicle, 0);
  }

  /// Gives the new position of a tracked vehicle, for example from the GPS.
  ///
  /// If the position is within [VehicleTracking.snapToleranceMeters] of the
  /// route it is put on the route and the marker moves to it, following the
  /// route if [VehicleTracking.followRoute] is set. Otherwise
  /// [VehicleTracking.onOffRoute] is called and the marker goes to the position
  /// as it is.
  ///
  /// [markerId] is only needed when more than one vehicle is tracked.
  void updateVehicle(LatLng position, {MarkerId? markerId}) {
    final vehicle = _vehicleFor(markerId);
    final fix = vehicle.tracker.update(position);

    if (!fix.onRoute) {
      vehicle.tracking.onOffRoute?.call(position);
      _animatedMarkersManager.push({
        vehicle.baseMarker.copyWith(positionParam: position),
      });
      return;
    }

    final marker = vehicle.baseMarker.copyWith(positionParam: fix.position);
    _animatedMarkersManager.push(
      {marker},
      routes: vehicle.tracking.followRoute
          ? {vehicle.markerId: RouteTarget(vehicle.path, fix.along!)}
          : const {},
    );
  }

  /// Stops following the vehicle with this marker and removes its route from
  /// the map. The marker stays where it is. Does nothing if it is not tracked.
  void stopTrackingVehicle(MarkerId markerId) {
    final vehicle = _vehicles.remove(markerId);
    if (vehicle == null) return;

    _applyPolylines(removeIds: vehicle.polylineIds);
  }

  TrackedVehicle _vehicleFor(MarkerId? markerId) {
    if (markerId != null) {
      final vehicle = _vehicles[markerId];
      if (vehicle == null) {
        throw StateError('The vehicle $markerId is not being tracked');
      }
      return vehicle;
    }
    if (_vehicles.length != 1) {
      throw StateError(
        _vehicles.isEmpty
            ? 'No vehicle is being tracked. Call trackVehicle first.'
            : 'More than one vehicle is tracked: pass the markerId.',
      );
    }
    return _vehicles.values.single;
  }

  /// Draws the route of [vehicle] for the marker [along] meters from the start.
  void _drawRoute(TrackedVehicle vehicle, double along) {
    final lines = vehicle.linesAt(along);
    vehicle.drawnAlong = along;
    _applyPolylines(
      upserts: [
        if (lines.traveled != null) lines.traveled!,
        if (lines.remaining != null) lines.remaining!
      ],
      removeIds: {
        if (lines.traveled == null) vehicle.traveledId,
        if (lines.remaining == null) vehicle.remainingId,
      },
    );
  }

  /// Keeps the route in step with the marker as it is shown, not as the last
  /// position that arrived.
  void _followShownMarker(Marker marker) {
    final vehicle = _vehicles[marker.markerId];
    if (vehicle == null || !vehicle.tracking.consumeRoute) return;

    final projection = vehicle.path.nearest(
      marker.position,
      from: vehicle.shownAlong,
      behind: vehicle.tracker.behindMeters,
      ahead: VehicleTracker.aheadMeters,
    );
    if (projection == null) return;

    vehicle.shownAlong = projection.along;
    final drawn = vehicle.drawnAlong;
    if (drawn != null && (projection.along - drawn).abs() < 0.5) return;
    _drawRoute(vehicle, projection.along);
  }

  /// Adds, changes and removes several polylines with one call to the map.
  void _applyPolylines({
    Iterable<Polyline> upserts = const [],
    Set<PolylineId> removeIds = const {},
  }) {
    final previous = Set<Polyline>.from(_polylines.values);
    for (final id in removeIds) {
      _polylines.remove(id);
    }
    for (final polyline in upserts) {
      _polylines[polyline.polylineId] = polyline;
    }
    _updatePolylinesOnMap(previous, _polylines.values.toSet());
  }

  /// The handle to pause, resume, seek and follow the animation of a polyline,
  /// or `null` if that polyline is not being animated.
  ///
  /// The handle stops working if the animator of the polyline is replaced, the
  /// polyline is removed or the controller is disposed.
  PolylineAnimationHandle? polylineAnimation(PolylineId polylineId) =>
      _animatedPolylineManager.handleFor(polylineId);

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

    if (_vehicles.isNotEmpty) updatedMarkers.forEach(_followShownMarker);

    _updateMarkersOnMap(prevMarkers, _markers.values.toSet());
  }

  /// A frame of an animated polyline: the polyline and its extra polylines.
  void _updateAnimated(PolylineId owner, List<Polyline> polylines) {
    final ids = {for (final p in polylines) p.polylineId};
    final extras = ids.difference({owner});
    final previous = _extras[owner] ?? const <PolylineId>{};

    if (extras.isEmpty) {
      _extras.remove(owner);
    } else {
      _extras[owner] = extras;
    }

    _applyPolylines(upserts: polylines, removeIds: previous.difference(ids));
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
    _vehicles.clear();
    _extras.clear();
  }
}

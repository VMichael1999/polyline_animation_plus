import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A [GoogleMapsFlutterPlatform] that records what the package draws.
///
/// [markers] and [polylines] hold what a real map would currently show, and
/// the counters tell how many updates were sent.
class FakeMapsPlatform extends GoogleMapsFlutterPlatform
    with MockPlatformInterfaceMixin {
  final markers = <MarkerId, Marker>{};
  final polylines = <PolylineId, Polyline>{};

  /// The camera moves, as JSON.
  final cameraMoves = <Object>[];

  int markerUpdateCalls = 0;
  int polylineUpdateCalls = 0;
  final mapIds = <int>{};

  @override
  Future<void> updateMarkers(MarkerUpdates markerUpdates,
      {required int mapId}) async {
    markerUpdateCalls++;
    mapIds.add(mapId);
    for (final m in markerUpdates.markersToAdd) {
      markers[m.markerId] = m;
    }
    for (final m in markerUpdates.markersToChange) {
      markers[m.markerId] = m;
    }
    markerUpdates.markerIdsToRemove.forEach(markers.remove);
  }

  @override
  Future<void> updatePolylines(
    PolylineUpdates polylineUpdates, {
    required int mapId,
  }) async {
    polylineUpdateCalls++;
    mapIds.add(mapId);
    for (final p in polylineUpdates.polylinesToAdd) {
      polylines[p.polylineId] = p;
    }
    for (final p in polylineUpdates.polylinesToChange) {
      polylines[p.polylineId] = p;
    }
    polylineUpdates.polylineIdsToRemove.forEach(polylines.remove);
  }

  @override
  Future<void> moveCamera(CameraUpdate cameraUpdate,
      {required int mapId}) async {
    cameraMoves.add(cameraUpdate.toJson());
  }
}

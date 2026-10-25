import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// Where the camera looks while it follows a marker.
enum CameraBearing {
  /// The map is turned so the marker always faces up, like in a navigation app.
  vehicle,

  /// North stays up and the map does not turn.
  north,
}

/// A camera that follows a marker, for `MapAnimationController.followCamera`.
final class CameraFollow {
  /// Creates the description of a followed marker.
  const CameraFollow({
    required this.markerId,
    this.zoom = 17,
    this.tilt = 0,
    this.bearing = CameraBearing.north,
    this.onFollowStopped,
  });

  /// The marker to follow, for example the marker of a tracked vehicle.
  final MarkerId markerId;

  /// Zoom level of the camera.
  final double zoom;

  /// Tilt of the camera in degrees. 0 looks straight down.
  final double tilt;

  /// Whether the map turns with the marker or keeps north up.
  final CameraBearing bearing;

  /// Called when the camera stops following because the user moved the map.
  ///
  /// It is not called by `stopFollowingCamera`. For it to work the app has to
  /// pass the camera events of the map to the controller, see
  /// `MapAnimationController.onCameraMoveStarted`.
  final void Function()? onFollowStopped;
}

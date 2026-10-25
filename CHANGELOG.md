## 1.3.0

This version also contains everything that was planned for 1.2.0, which was not published on its own.

### Breaking behavior

- `followRoute` rounds the corners when the marker turns (`turnSmoothingMeters`, 0 to turn at once), and `CameraFollow` turns the map with a lag (`bearingLag`, `Duration.zero` to turn at once).
- Polyline animations now pause when the app goes to the background and go on from the same place when it returns. Use `pauseInBackground: false` on `MapAnimationController` to keep the old behavior.
- When the system asks to reduce motion, polylines are drawn as they are and markers move at once. Use `respectReduceMotion: false` to keep animating.
- Every marker now moves on its own clock. Before, all markers moved in synchronized rounds, so a marker with several waiting positions held back the rest. Markers also play their waiting positions without waiting for the others.
- A marker that is removed waits for the end of its own moves, not for the moves of every marker. A marker that is not moving is removed at once.
- A change to a marker that does not move it (for example its alpha or icon) is applied right away instead of running a move of the full duration.

### New

- `VehicleTracking.turnSmoothingMeters` (default 8): with `followRoute`, the marker turns gradually around corners instead of jumping.
- `CameraFollow.bearingLag` (default 600 ms): when the map turns with the vehicle, it catches up a little later, so in a curve the vehicle is seen from the side.
- `MapAnimationController.markerFrameBuilder`: change a marker on every frame before it is drawn, for example to pick an icon for the direction it faces.
- `PulseAnimator`: a light that travels along a dimmed copy of the route (extra polyline `<id>#glow`).
- `DashFlowAnimator`: dashes that flow along the route. Its limitation (pattern in pixels, cut in meters) is documented.
- `AnimatedPolyline.segmented` and `RouteSegment`: a route in several colors, with the animator applied to the whole route.
- `MapAnimationController.followCamera(CameraFollow(...))`, `stopFollowingCamera()` and `onCameraMoveStarted()` to follow a marker with the camera and stop when the user moves the map.
- `PolylineAnimator.animateAll` and `PolylineAnimator.reducedMotionFrame` for animations made of several polylines.
- `MapAnimationController.pauseInBackground` and `respectReduceMotion`.
- `MapAnimationController.markerAnimationMode`: `MarkerAnimationMode.queue` (default, as before) or `MarkerAnimationMode.latestOnly`, which goes straight to the newest position from where the marker is shown and drops the ones in between.
- `MapAnimationController.markerDuration`: `MarkerDuration.fixed(duration)` or `MarkerDuration.adaptive(max: duration)`, where each move lasts as long as the time between positions. `markersAnimationDuration` still works and is a shortcut for `fixed`.
- Vehicle tracking: `MapAnimationController.trackVehicle(VehicleTracking(...))`, `updateVehicle(position)` and `stopTrackingVehicle(markerId)`. Positions are put on the route (searching around the last known distance first, so crossing routes and parallel streets do not cause jumps), the route is drawn as travelled and remaining (`RouteStyle`), `followRoute` makes the marker follow the route and turn at the corners, and `onOffRoute` reports positions beyond `snapToleranceMeters`.
- Animation control: `MapAnimationController.polylineAnimation(id)` returns a `PolylineAnimationHandle` with `pause()`, `resume()`, `seek(progress)`, `isPlaying`, `isCompleted`, `value`, a `progress` stream, `onComplete` and `onCycle`.
- `PolylineCodec.decode` and `PolylineCodec.encode` for the Google Encoded Polyline format, with precision 5 or 6.
- `MapAnimationUtils.boundsOf(points)`.

### Other

- An animation without duration is drawn at once and redrawn when its polyline changes.
- Polyline animations now run on their own simulation, with the same timing as before, so they can be paused and resumed at any point.
- All markers share one ticker and the changes of a frame go to the map together. With 50 markers it is one map call per frame, as before, at about 170 µs per frame in the test harness.

## 1.1.0

### Breaking behavior

- Animations with `delayStart`/`delayEnd` now take the full `duration` to draw. Before, the delays were taken out of `duration`, so the drawing phase was shorter than configured. If you shortened `duration` to compensate, restore the value you intended.
- `MapAnimationUtils.generateEquidistantPolylineByDuration` now returns evenly spaced points, no duplicated first point and including the last point of the path. The number and position of the generated points changed.
- A marker that does not move (less than 0.5 m) keeps its rotation instead of turning to face north.

### New

- `MapAnimationController.useMarkerRotation` (default `false`): use `Marker.rotation` instead of the heading between positions.
- `SnackAnimator` accepts `delayStart` and `delayEnd`.
- `ColorTransitionAnimation` accepts `repeatCount`, `reverse`, `delayStart` and `delayEnd`.

### Fixes

- `PolylineAnimator` equality and `hashCode` now include `delayStart` and `delayEnd`, and `ColorTransitionAnimation` includes `colors`. Changing only those values now restarts the animation.
- `generateEquidistantPolylineByDuration` no longer loops forever when the path has zero length.
- An animated polyline removed before it drew its first frame is now really removed; before, its animation kept running and drew it again.
- `ColorTransitionAnimation` no longer fails with an empty `colors` list, and at the end of a cycle it blends back to the first color instead of jumping to a wrong one.
- Sending the same marker position twice while a move is running no longer plays it twice.
- With two or more positions waiting in the queue, the marker no longer skips one of them.

### Other

- Supports Flutter 3.22 and Dart 3.4 (was effectively Flutter 3.27): `Color.withValues` replaced with `withAlpha`, `google_maps_flutter_platform_interface` constraint lowered to `^2.10.0`.
- Declared supported platforms: Android, iOS and web.
- `onAnimationStop` is documented: called once when the animation completes, not on dispose and not for endless repeating animations.
- Added unit tests.
- Repository links point to `VMichael1999`.
- Example no longer requests the deprecated legacy Android renderer.

## 1.0.4

- Initial release of `polyline_animation_plus`.
- Added core polyline animation engine.
- Included progressive fade animation, controllers, and utilities.
- Provided example project demonstrating Google Maps integration.

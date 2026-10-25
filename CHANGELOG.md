## 1.2.0 (unreleased)

### Breaking behavior

- Every marker now moves on its own clock. Before, all markers moved in synchronized rounds, so a marker with several waiting positions held back the rest. Markers also play their waiting positions without waiting for the others.
- A marker that is removed waits for the end of its own moves, not for the moves of every marker. A marker that is not moving is removed at once.
- A change to a marker that does not move it (for example its alpha or icon) is applied right away instead of running a move of the full duration.

### New

- `MapAnimationController.markerAnimationMode`: `MarkerAnimationMode.queue` (default, as before) or `MarkerAnimationMode.latestOnly`, which goes straight to the newest position from where the marker is shown and drops the ones in between.
- `MapAnimationController.markerDuration`: `MarkerDuration.fixed(duration)` or `MarkerDuration.adaptive(max: duration)`, where each move lasts as long as the time between positions. `markersAnimationDuration` still works and is a shortcut for `fixed`.

### Other

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

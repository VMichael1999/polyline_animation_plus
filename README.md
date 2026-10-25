# polyline_animation_plus

[![pub package](https://img.shields.io/pub/v/polyline_animation_plus.svg)](https://pub.dev/packages/polyline_animation_plus)
[![CI](https://github.com/VMichael1999/polyline_animation_plus/actions/workflows/ci.yml/badge.svg)](https://github.com/VMichael1999/polyline_animation_plus/actions/workflows/ci.yml)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

**English** · [Español](README.es.md)

Smooth, customizable polyline and marker animations for Google Maps in Flutter. Useful for transportation, delivery, logistics, tracking or any app that needs animated routes.

> Fork of [google_map_animation](https://github.com/manishrelani/google_map_animation) by Manish Relani (BSD-3-Clause). See [Credits and license](#credits-and-license).

<p align="center">
  <img src="https://raw.githubusercontent.com/VMichael1999/polyline_animation_plus/main/doc/demo.gif" width="30%" alt="Animated polyline drawing on Google Maps" />
  <br>
  <em>An animated polyline drawn with this package.</em>
</p>

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Built-in animators](#built-in-animators)
- [Create your own animator](#create-your-own-animator)
- [Animated markers](#animated-markers)
- [Important: do not reuse IDs in `GoogleMap`](#important-do-not-reuse-ids-in-googlemap)
- [Contributing](#contributing)
- [Credits and license](#credits-and-license)

## Features

- Animated polylines with progressive drawing effects.
- Repeating or one-shot animations, with custom duration, curve and delays.
- Several animated polylines at the same time.
- Animated markers that glide between positions and turn towards the direction of travel.
- Works on Android, iOS and web.
- Built on `google_maps_flutter_platform_interface`: it does not depend on a specific map widget version.

## Requirements

- Flutter 3.22 or newer (Dart 3.4 or newer).
- A map using [`google_maps_flutter`](https://pub.dev/packages/google_maps_flutter), already set up with its API keys.

## Installation

```yaml
dependencies:
  polyline_animation_plus: ^1.1.0
```

```dart
import 'package:polyline_animation_plus/polyline_animation_plus.dart';
```

## Quick start

Create a `MapAnimationController` when the map is ready and give it the polylines to draw. A polyline with an animator is animated; a polyline without one is drawn as it is.

```dart
final Set<AnimatedPolyline> polylines = {
  AnimatedPolyline(
    polyline: Polyline(
      polylineId: const PolylineId('front'),
      color: Colors.blue,
      width: 4,
      points: MapAnimationUtils.generateEquidistantPolylineByDuration(
        path: yourCoordinatesList,
        duration: const Duration(seconds: 4),
      ),
    ),
    polylineAnimator: const FadeInProgressiveAnimator(
      repeat: true,
      curve: Curves.linear,
      duration: Duration(seconds: 4),
      delayStart: Duration(seconds: 1),
    ),
  ),
  // No animator: drawn as it is.
  AnimatedPolyline(
    polyline: Polyline(
      polylineId: const PolylineId('back'),
      color: Colors.grey,
      width: 4,
      points: yourCoordinatesList,
    ),
  ),
};

late MapAnimationController mapAnimationController;

void onMapCreated(GoogleMapController controller) {
  mapAnimationController = MapAnimationController(
    mapId: controller.mapId,
    vsync: this, // a State with TickerProviderStateMixin
    polylines: polylines,
  );
}

@override
void dispose() {
  mapAnimationController.dispose();
  super.dispose();
}
```

`MapAnimationUtils.generateEquidistantPolylineByDuration` adds points so they are evenly spaced, which makes progressive animations move at a constant speed. A complete app is in the [`example`](example) folder.

To change the polylines later, call `mapAnimationController.updatePolylines(newSet)`. Polylines missing from the new set are removed.

## Built-in animators

All animators share these options: `duration`, `curve`, `repeat`, `repeatCount`, `reverse`, `delayStart` and `delayEnd`. The delays are added to `duration`; they do not shorten it.

| Animator | What it does |
| --- | --- |
| `SnackAnimator` | Draws the line from start to end, then erases it in the same direction. |
| `FadeInProgressiveAnimator` | Fades the line in during the first 30% and then erases it from the start. |
| `ColorTransitionAnimation` | Changes the color smoothly through a list of `colors`. |

## Create your own animator

Extend `PolylineAnimator` and return the polyline to draw for a given `progress` (from 0 to 1):

```dart
class BlinkAnimator extends PolylineAnimator {
  const BlinkAnimator()
      : super(duration: const Duration(seconds: 1), repeat: true);

  @override
  Polyline animate(Polyline polyline, double progress) {
    return polyline.copyWith(
      colorParam: polyline.color.withAlpha((progress * 255).round()),
    );
  }
}
```

`polyline` is always the original polyline, not the previous frame.

## Animated markers

Pass the markers to the same controller and call `updateMarkers` each time a position changes, for example on every GPS update. The marker glides from its previous position to the new one and rotates towards the direction of travel.

```dart
mapAnimationController = MapAnimationController(
  mapId: controller.mapId,
  vsync: this,
  markers: {
    Marker(markerId: const MarkerId('driver'), position: start),
  },
  // How long each move takes. Default: 2 seconds.
  markersAnimationDuration: const Duration(seconds: 2),
  // Called with the markers updated on every animation frame.
  markerListener: (markers) {},
);

// When a new position arrives, send the full set of markers:
mapAnimationController.updateMarkers({
  Marker(markerId: const MarkerId('driver'), position: newPosition),
});
```

- `updateMarkers` receives **all** the markers: the ones you leave out are removed from the map.
- Positions that arrive while a marker is still moving wait in a queue and are played in order.
- A marker that does not move keeps its rotation. Set `useMarkerRotation: true` to use `Marker.rotation` instead of the heading between positions.

### Live tracking: do not fall behind the GPS

By default every position is played in order. If the GPS sends a position every second but each move lasts 2 seconds, the marker falls further and further behind. For live tracking use `latestOnly`: the marker goes straight to the newest position, starting from where it is shown at that moment.

```dart
mapAnimationController = MapAnimationController(
  mapId: controller.mapId,
  vsync: this,
  markerAnimationMode: MarkerAnimationMode.latestOnly,
  // Each move lasts as long as the time between positions, up to 2 seconds.
  markerDuration: const MarkerDuration.adaptive(max: Duration(seconds: 2)),
);
```

| Option | Values | Default |
| --- | --- | --- |
| `markerAnimationMode` | `queue` plays every position in order. `latestOnly` skips to the newest one. | `queue` |
| `markerDuration` | `MarkerDuration.fixed(d)` always lasts `d`. `MarkerDuration.adaptive(max: d)` follows the time between positions, between 100 ms and `d`. | `fixed`, from `markersAnimationDuration` (2 seconds) |

Every marker moves on its own clock, so a slow marker does not hold back the others.

## Follow a vehicle on a route

For a ride or delivery you already have the route. Give it to the controller together with the marker of the vehicle, and send each GPS position to `updateVehicle`. The position is put on the route, so the marker does not wander off the road, and the route is drawn as the part already travelled and the part still to go.

```dart
mapAnimationController.trackVehicle(
  VehicleTracking(
    markerId: const MarkerId('driver'),
    route: routePoints, // for example, decoded from a Directions response
    traveled: const RouteStyle(color: Colors.grey),
    remaining: const RouteStyle(color: Colors.blue, width: 6),
    snapToleranceMeters: 30,
    followRoute: true,
    onOffRoute: (position) => requestNewRoute(position),
  ),
);

// On every GPS update:
mapAnimationController.updateVehicle(position);

// When the trip ends:
mapAnimationController.stopTrackingVehicle(const MarkerId('driver'));
```

| Option | What it does | Default |
| --- | --- | --- |
| `snapToleranceMeters` | How far from the route a position can be and still be put on it. | 30 |
| `followRoute` | The marker takes the route between two positions and turns at the corners, instead of going in a straight line. | `false` |
| `consumeRoute` | Draws the travelled part with `traveled` (or hides it with `visible: false`) and the rest with `remaining`. When `false`, the whole route keeps the `remaining` style. | `true` |
| `onOffRoute` | Called with a position farther than the tolerance. The marker goes to that position as it is, and the progress on the route is kept. | none |

- The marker is created at the start of the route if it does not exist. While the vehicle is tracked, `updateMarkers` does not move or remove it.
- The two lines are polylines with the IDs `<markerId>#traveled` and `<markerId>#remaining`. Do not use those IDs for other polylines.
- The search for the position starts near the last known one, so a route that crosses itself, or a parallel street, does not make the vehicle jump. If nothing is close, the whole route is searched.
- With several vehicles, pass the `markerId` to `updateVehicle`.
- Combine it with `markerAnimationMode: MarkerAnimationMode.latestOnly` for live tracking.

## Important: do not reuse IDs in `GoogleMap`

The controller draws directly on the map, using the `mapId`. If the `GoogleMap` widget also receives a polyline or marker with the same ID in its `polylines` or `markers`, the widget overwrites what the controller draws. Give the controller its own IDs and leave them out of the widget's sets.

## Contributing

Issues and pull requests are welcome at [github.com/VMichael1999/polyline_animation_plus](https://github.com/VMichael1999/polyline_animation_plus). Before opening a pull request, run:

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

See the [CHANGELOG](CHANGELOG.md) for what changed in each version.

## Credits and license

This package is a fork of [google_map_animation](https://github.com/manishrelani/google_map_animation) by Manish Relani and builds on his work. It is maintained by [Michael Anthony Valdiviezo Maza](https://github.com/VMichael1999).

BSD 3-Clause. The original code is © 2025 Manish Relani; the changes in this fork are © 2025 Michael Anthony Valdiviezo Maza. Both notices are in [LICENSE](LICENSE) and must be kept in copies.

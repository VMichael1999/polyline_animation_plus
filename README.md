# polyline_animation_plus

> Fork of [google_map_animation](https://github.com/manishrelani/google_map_animation) by Manish Relani (BSD-3-Clause). See [License](#-license).

A Flutter package for creating smooth, customizable polyline animations on Google Maps. Ideal for apps in transportation, delivery, logistics, tracking, or any project that needs animated route visualizations.

## 🎥 Demo

<p align="center">
<img src="https://raw.githubusercontent.com/VMichael1999/polyline_animation_plus/main/doc/demo.gif" width="30%" alt="Animated polyline drawing on Google Maps" />
<br>
This animation represents how the plugin behaves
</p>

---

## ✨ Features

- 🎬 **Animated polylines** with progressive drawing effects
- 🔁 **Repeatable** or one‑shot animations
- ⏱️ **Custom duration**, delay, and animation curves
- 📍 **Animated markers** that glide between positions and turn towards the direction of travel
- 🗺️ Works on **Android, iOS and web** (Google Maps)
- 🧩 Supports **multiple animated polylines** simultaneously
- ⚡ Built using the `google_maps_flutter_platform_interface`

---

## 🚀 Getting Started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  polyline_animation_plus: ^1.0.4
```

Or if using locally (for development):

```yaml
dependencies:
  polyline_animation_plus:
    path: ../polyline_animation_plus
```

Import it:

```dart
import 'package:polyline_animation_plus/polyline_animation_plus.dart';
```

---

## 📌 Usage Example

Below is a basic example of how to animate a polyline on Google Maps.

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

onMapCreated(GoogleMapController controller) {
  mapAnimationController = MapAnimationController(
    mapId: controller.mapId,
    vsync: this,
    polylines: polylines,
  );
}
```

Remember to release the controller when the map goes away:

```dart
@override
void dispose() {
  mapAnimationController.dispose();
  super.dispose();
}
```

More complete examples can be found in the `/example` folder.

---

## 📍 Animated markers

Pass the markers to the same controller and call `updateMarkers` every time a position changes (for example, on each GPS update). The marker glides from its previous position to the new one and rotates towards the direction of travel.

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

---

## ⚠️ Do not pass the same IDs to `GoogleMap`

The controller draws directly on the map, using the `mapId`. If the `GoogleMap` widget also receives a polyline or marker with the same ID in its `polylines` or `markers`, the widget will overwrite what the controller draws. Give the controller its own IDs and leave them out of the widget's sets.

---

## 📚 Additional Information

- Issues and feature requests: **GitHub Issues**
- Repository: https://github.com/VMichael1999/polyline_animation_plus
- Contributions are welcome! Submit PRs to improve animations or extend support.
- Based on [google_map_animation](https://github.com/manishrelani/google_map_animation) by Manish Relani.

## 👤 Author / Developer

**Michael Anthony Valdiviezo Maza**

Flutter & Mobile Developer focused on mobility, ride‑hailing, logistics and real‑time map experiences. Maintainer of this fork, which builds on the original work of Manish Relani.

**Areas of focus**
- Google Maps & geolocation (polylines, tracking, animations)
- Ride‑hailing / fleet dispatch flows
- Real‑time mobility UX and performance optimization
- White‑label transportation platforms (B2B & B2C)

**Connect**
- GitHub: https://github.com/VMichael1999

If you use this package in your project, feel free to open an issue or PR — contributions and ideas are welcome.

---


## 📄 License

BSD 3-Clause. The original code is © 2025 Manish Relani ([google_map_animation](https://github.com/manishrelani/google_map_animation)); changes in this fork are © 2025 Michael Anthony Valdiviezo Maza. Both notices are in [LICENSE](LICENSE) and must be kept in copies.

Fork additions: see [CHANGELOG](CHANGELOG.md).

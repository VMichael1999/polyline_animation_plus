# polyline_animation_plus

> Fork of [google_map_animation](https://github.com/manishrelani/google_map_animation) by Manish Relani (BSD-3-Clause). See [License](#-license).

A Flutter package for creating smooth, customizable polyline animations on Google Maps. Ideal for apps in transportation, delivery, logistics, tracking, or any project that needs animated route visualizations.

## 🎥 Demo

<p align="center">
<img src="doc/demo.gif" width="30%" alt="Animated polyline drawing on Google Maps" />
<br>
This animation represents how the plugin behaves
</p>

---

## ✨ Features

- 🎬 **Animated polylines** with progressive drawing effects
- 🔁 **Repeatable** or one‑shot animations
- ⏱️ **Custom duration**, delay, and animation curves
- 🗺️ Works on **Android & iOS** (Google Maps)
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

More complete examples can be found in the `/example` folder.

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

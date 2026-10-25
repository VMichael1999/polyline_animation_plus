# polyline_animation_plus

[![pub package](https://img.shields.io/pub/v/polyline_animation_plus.svg)](https://pub.dev/packages/polyline_animation_plus)
[![CI](https://github.com/VMichael1999/polyline_animation_plus/actions/workflows/ci.yml/badge.svg)](https://github.com/VMichael1999/polyline_animation_plus/actions/workflows/ci.yml)
[![Licencia: BSD-3-Clause](https://img.shields.io/badge/licencia-BSD--3--Clause-blue.svg)](LICENSE)

[English](README.md) · **Español**

Animaciones fluidas y personalizables de polylines y marcadores sobre Google Maps en Flutter. Útil para transporte, entregas, logística, seguimiento o cualquier app que necesite rutas animadas.

> Fork de [google_map_animation](https://github.com/manishrelani/google_map_animation) de Manish Relani (BSD-3-Clause). Ver [Créditos y licencia](#créditos-y-licencia).

<p align="center">
  <img src="https://raw.githubusercontent.com/VMichael1999/polyline_animation_plus/main/doc/demo.gif" width="30%" alt="Polyline animada dibujándose sobre Google Maps" />
  <br>
  <em>Una polyline animada con este paquete.</em>
</p>

## Contenido

- [Características](#características)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Inicio rápido](#inicio-rápido)
- [Animators incluidos](#animators-incluidos)
- [Crea tu propio animator](#crea-tu-propio-animator)
- [Marcadores animados](#marcadores-animados)
- [Importante: no repitas IDs en `GoogleMap`](#importante-no-repitas-ids-en-googlemap)
- [Contribuir](#contribuir)
- [Créditos y licencia](#créditos-y-licencia)

## Características

- Polylines animadas con efectos de dibujo progresivo.
- Animaciones que se repiten o se reproducen una sola vez, con duración, curva y retrasos configurables.
- Varias polylines animadas al mismo tiempo.
- Marcadores animados que se deslizan entre posiciones y giran hacia la dirección del recorrido.
- Funciona en Android, iOS y web.
- Se basa en `google_maps_flutter_platform_interface`, por lo que no depende de una versión concreta del widget del mapa.

## Requisitos

- Flutter 3.22 o superior (Dart 3.4 o superior).
- Un mapa que use [`google_maps_flutter`](https://pub.dev/packages/google_maps_flutter), ya configurado con sus claves de API.

## Instalación

```yaml
dependencies:
  polyline_animation_plus: ^1.1.0
```

```dart
import 'package:polyline_animation_plus/polyline_animation_plus.dart';
```

## Inicio rápido

Crea un `MapAnimationController` cuando el mapa esté listo y pásale las polylines a dibujar. Una polyline con animator se anima; una polyline sin animator se dibuja tal cual.

```dart
final Set<AnimatedPolyline> polylines = {
  AnimatedPolyline(
    polyline: Polyline(
      polylineId: const PolylineId('front'),
      color: Colors.blue,
      width: 4,
      points: MapAnimationUtils.generateEquidistantPolylineByDuration(
        path: tusCoordenadas,
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
  // Sin animator: se dibuja tal cual.
  AnimatedPolyline(
    polyline: Polyline(
      polylineId: const PolylineId('back'),
      color: Colors.grey,
      width: 4,
      points: tusCoordenadas,
    ),
  ),
};

late MapAnimationController mapAnimationController;

void onMapCreated(GoogleMapController controller) {
  mapAnimationController = MapAnimationController(
    mapId: controller.mapId,
    vsync: this, // un State con TickerProviderStateMixin
    polylines: polylines,
  );
}

@override
void dispose() {
  mapAnimationController.dispose();
  super.dispose();
}
```

`MapAnimationUtils.generateEquidistantPolylineByDuration` agrega puntos para que queden a la misma distancia entre sí, así las animaciones progresivas avanzan a velocidad constante. Una app completa está en la carpeta [`example`](example).

Para cambiar las polylines más tarde, llama a `mapAnimationController.updatePolylines(nuevoConjunto)`. Las polylines que no estén en el nuevo conjunto se eliminan.

## Animators incluidos

Todos comparten estas opciones: `duration`, `curve`, `repeat`, `repeatCount`, `reverse`, `delayStart` y `delayEnd`. Los retrasos se suman a `duration`; no la acortan.

| Animator | Qué hace |
| --- | --- |
| `SnackAnimator` | Dibuja la línea de inicio a fin y luego la borra en el mismo sentido. |
| `FadeInProgressiveAnimator` | Hace aparecer la línea durante el primer 30 % y luego la borra desde el inicio. |
| `ColorTransitionAnimation` | Cambia el color de forma suave a través de una lista de `colors`. |

## Crea tu propio animator

Extiende `PolylineAnimator` y devuelve la polyline a dibujar para un `progress` dado (de 0 a 1):

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

`polyline` siempre es la polyline original, no el fotograma anterior.

## Marcadores animados

Pasa los marcadores al mismo controlador y llama a `updateMarkers` cada vez que cambie una posición, por ejemplo en cada actualización del GPS. El marcador se desliza desde su posición anterior hasta la nueva y gira hacia la dirección del recorrido.

```dart
mapAnimationController = MapAnimationController(
  mapId: controller.mapId,
  vsync: this,
  markers: {
    Marker(markerId: const MarkerId('driver'), position: inicio),
  },
  // Cuánto dura cada movimiento. Por defecto: 2 segundos.
  markersAnimationDuration: const Duration(seconds: 2),
  // Se llama con los marcadores actualizados en cada fotograma.
  markerListener: (markers) {},
);

// Cuando llega una posición nueva, envía el conjunto completo de marcadores:
mapAnimationController.updateMarkers({
  Marker(markerId: const MarkerId('driver'), position: nuevaPosicion),
});
```

- `updateMarkers` recibe **todos** los marcadores: los que no incluyas se eliminan del mapa.
- Las posiciones que llegan mientras un marcador sigue en movimiento esperan en una cola y se reproducen en orden.
- Un marcador que no se mueve conserva su rotación. Usa `useMarkerRotation: true` para tomar `Marker.rotation` en lugar de la dirección entre posiciones.

### Seguimiento en vivo: no te quedes atrás del GPS

Por defecto cada posición se reproduce en orden. Si el GPS envía una posición por segundo pero cada movimiento dura 2 segundos, el marcador se queda cada vez más atrás. Para seguimiento en vivo usa `latestOnly`: el marcador va directo a la posición más reciente, partiendo desde donde se muestra en ese momento.

```dart
mapAnimationController = MapAnimationController(
  mapId: controller.mapId,
  vsync: this,
  markerAnimationMode: MarkerAnimationMode.latestOnly,
  // Cada movimiento dura lo que pasa entre posiciones, hasta 2 segundos.
  markerDuration: const MarkerDuration.adaptive(max: Duration(seconds: 2)),
);
```

| Opción | Valores | Por defecto |
| --- | --- | --- |
| `markerAnimationMode` | `queue` reproduce todas las posiciones en orden. `latestOnly` salta a la más reciente. | `queue` |
| `markerDuration` | `MarkerDuration.fixed(d)` dura siempre `d`. `MarkerDuration.adaptive(max: d)` sigue el tiempo entre posiciones, entre 100 ms y `d`. | `fixed`, tomado de `markersAnimationDuration` (2 segundos) |

Cada marcador se mueve con su propio reloj, así que uno lento no frena a los demás.

## Sigue a un vehículo por una ruta

Para un viaje o una entrega ya tienes la ruta. Pásasela al controlador junto con el marcador del vehículo y envía cada posición del GPS a `updateVehicle`. La posición se ajusta a la ruta, así el marcador no se sale de la calle, y la ruta se dibuja como la parte ya recorrida y la parte que falta.

```dart
mapAnimationController.trackVehicle(
  VehicleTracking(
    markerId: const MarkerId('driver'),
    route: puntosDeLaRuta, // por ejemplo, decodificados de una respuesta de Directions
    traveled: const RouteStyle(color: Colors.grey),
    remaining: const RouteStyle(color: Colors.blue, width: 6),
    snapToleranceMeters: 30,
    followRoute: true,
    onOffRoute: (posicion) => pedirNuevaRuta(posicion),
  ),
);

// En cada actualización del GPS:
mapAnimationController.updateVehicle(posicion);

// Cuando termina el viaje:
mapAnimationController.stopTrackingVehicle(const MarkerId('driver'));
```

| Opción | Qué hace | Por defecto |
| --- | --- | --- |
| `snapToleranceMeters` | Qué tan lejos de la ruta puede estar una posición y aun así ajustarse a ella. | 30 |
| `followRoute` | El marcador toma la ruta entre dos posiciones y gira en las esquinas, en lugar de ir en línea recta. | `false` |
| `consumeRoute` | Dibuja la parte recorrida con `traveled` (o la oculta con `visible: false`) y el resto con `remaining`. Con `false`, toda la ruta conserva el estilo `remaining`. | `true` |
| `onOffRoute` | Se llama con una posición más lejos que la tolerancia. El marcador va a esa posición tal cual y se conserva el avance en la ruta. | ninguno |

- El marcador se crea al inicio de la ruta si no existe. Mientras el vehículo está en seguimiento, `updateMarkers` no lo mueve ni lo elimina.
- Las dos líneas son polylines con los IDs `<markerId>#traveled` y `<markerId>#remaining`. No uses esos IDs para otras polylines.
- La búsqueda de la posición empieza cerca de la última conocida, así que una ruta que se cruza a sí misma, o una calle paralela, no hace saltar al vehículo. Si no hay nada cerca, se busca en toda la ruta.
- Con varios vehículos, pasa el `markerId` a `updateVehicle`.
- Combínalo con `markerAnimationMode: MarkerAnimationMode.latestOnly` para seguimiento en vivo.

## Importante: no repitas IDs en `GoogleMap`

El controlador dibuja directamente sobre el mapa usando el `mapId`. Si el widget `GoogleMap` también recibe una polyline o un marcador con el mismo ID en sus `polylines` o `markers`, el widget sobrescribe lo que dibuja el controlador. Dale al controlador sus propios IDs y no los incluyas en los conjuntos del widget.

## Contribuir

Se aceptan issues y pull requests en [github.com/VMichael1999/polyline_animation_plus](https://github.com/VMichael1999/polyline_animation_plus). Antes de abrir un pull request, ejecuta:

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

Consulta el [CHANGELOG](CHANGELOG.md) para ver qué cambió en cada versión.

## Créditos y licencia

Este paquete es un fork de [google_map_animation](https://github.com/manishrelani/google_map_animation) de Manish Relani y se apoya en su trabajo. Lo mantiene [Michael Anthony Valdiviezo Maza](https://github.com/VMichael1999).

BSD 3-Clause. El código original es © 2025 Manish Relani; los cambios de este fork son © 2025 Michael Anthony Valdiviezo Maza. Ambos avisos están en [LICENSE](LICENSE) y deben conservarse en las copias.

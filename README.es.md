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
| `PulseAnimator` | Una luz recorre una copia atenuada de la ruta, para una espera de «buscando conductor». También dibuja una polyline con el ID `<id>#glow`. |
| `DashFlowAnimator` | Una línea punteada cuyos tramos avanzan por la ruta. Mira su limitación más abajo. |

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

### Tramos que fluyen: una limitación

Google Maps no puede mover el patrón de una línea punteada, así que `DashFlowAnimator` lo simula recortando el inicio de la línea un poco más en cada frame. `dash` y `gap` se dibujan en píxeles lógicos (lo que usan los patrones de Google Maps), pero el recorte se mide en metros, así que el bucle solo es suave en el nivel de zoom donde un metro equivale a un píxel (alrededor del zoom 17). En otros niveles los tramos pueden dar un salto al reiniciar el ciclo. No se ha comprobado que el patrón quede anclado al primer punto en Android y en iOS.

## Colores por tramo

Dibuja una ruta en varios colores, por ejemplo según el tráfico. Cada segmento es una fracción de la ruta por distancia, y el animator se aplica a toda la ruta como si fuera una sola línea.

```dart
AnimatedPolyline.segmented(
  id: const PolylineId('route'),
  points: puntosDeLaRuta,
  segments: const [
    RouteSegment(from: 0.00, to: 0.35, color: Color(0xFF1E9E5A)),
    RouteSegment(from: 0.35, to: 0.60, color: Color(0xFFF2A900)),
    RouteSegment(from: 0.60, to: 0.80, color: Color(0xFFE53935)),
    RouteSegment(from: 0.80, to: 1.00, color: Color(0xFF1E9E5A)),
  ],
  polylineAnimator: const SnackAnimator(), // opcional
)
```

- Cada segmento es una polyline con el ID `<id>#<n>`; el ID en sí no se dibuja. No uses esos IDs para otras polylines.
- Los segmentos consecutivos comparten el punto donde se unen, así que no queda hueco. Una parte de la ruta que ningún segmento cubre no se dibuja.
- Del animator solo se usa la parte de la ruta que deja visible y su opacidad en los fundidos. Los colores vienen de los segmentos.

## Una cámara que sigue

Haz que la cámara siga a un marcador, por ejemplo el vehículo que estás siguiendo:

```dart
mapAnimationController.followCamera(
  CameraFollow(
    markerId: const MarkerId('driver'),
    zoom: 17,
    tilt: 45,
    bearing: CameraBearing.vehicle, // o CameraBearing.north
    onFollowStopped: () => mostrarBotonRecentrar(),
  ),
);

mapAnimationController.stopFollowingCamera();
```

La cámara se mueve como máximo unas diez veces por segundo, y se envía la última posición cuando el marcador se detiene. **El paquete no recibe por sí solo los gestos sobre el mapa.** Para dejar de seguir cuando el usuario mueve el mapa, pásale el método del controlador al widget:

```dart
GoogleMap(
  onCameraMoveStarted: mapAnimationController.onCameraMoveStarted,
  // ...
)
```

El mapa también avisa de los movimientos que hace el controlador, así que los que empiezan justo después de una actualización suya de la cámara se ignoran. Por eso se detecta al usuario cuando la cámara lleva un momento sin moverse, por ejemplo cuando el vehículo se detiene. No se ha comprobado en dispositivos cómo lo reporta cada plataforma.

## Batería y accesibilidad

- **Segundo plano.** Por defecto (`pauseInBackground: true`) las animaciones de polylines se detienen cuando la app pasa a segundo plano y continúan desde el mismo punto al volver. Una animación que pausaste con su handle sigue pausada. Los movimientos de marcadores no se pausan, porque tienen que mostrar las posiciones más recientes.
- **Reducir movimiento.** Por defecto (`respectReduceMotion: true`) el controlador sigue el ajuste del sistema. Cuando el usuario pide reducir el movimiento, las polylines se dibujan tal cual, sin animar, y los marcadores y vehículos van a su nueva posición de inmediato. Sobrescribe `PolylineAnimator.reducedMotionFrame` si tu propia animación necesita algo distinto.

## Controla una animación en marcha

Pídele al controlador el handle de una polyline para pausarla, llevarla a un punto o seguir su progreso.

```dart
final animacion = mapAnimationController
    .polylineAnimation(const PolylineId('front'));

animacion?.pause();
animacion?.seek(0.5);   // salta a la mitad del ciclo
animacion?.resume();

animacion?.progress.listen((p) => print(p)); // de 0.0 a 1.0
animacion?.onComplete = () => mostrarLlegada();
animacion?.onCycle = (ciclo) => print('terminó la pasada $ciclo');
```

- `polylineAnimation` devuelve `null` si ese ID no tiene animación.
- El progreso es la posición dentro de un ciclo, en tiempo: incluye `delayStart` y `delayEnd` y se mide antes de la curva.
- `seek` sobre una animación en marcha la mantiene corriendo desde ahí. En una pausada o terminada se queda quieta hasta `resume`.
- `onComplete` no se llama en una animación que se repite para siempre, porque nunca termina. Para esas usa `onCycle`. Con `reverse`, ir y volver cuentan como una pasada cada uno, igual que en `repeatCount`.
- El handle deja de funcionar cuando se quita la polyline, se reemplaza su animator o se hace `dispose` del controlador.

## Utilidades

```dart
// Decodifica la ruta de una respuesta de Directions y ajusta la cámara.
final ruta = PolylineCodec.decode(respuesta.overviewPolyline);
controller.animateCamera(
  CameraUpdate.newLatLngBounds(MapAnimationUtils.boundsOf(ruta), 50),
);

// Y de vuelta a texto, con 5 decimales (por defecto) o 6.
final texto = PolylineCodec.encode(ruta, precision: 6);
```

`PolylineCodec` lee y escribe el [formato de polyline codificada](https://developers.google.com/maps/documentation/utilities/polylinealgorithm). `boundsOf` no maneja rutas que cruzan el meridiano 180.

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

# Borrador de mensaje para el autor original

Para enviar por el dueño del repo (no se ha contactado a nadie).
Destino: https://github.com/manishrelani/google_map_animation

---

Hola Manish,

Mantengo `polyline_animation_plus`
(https://github.com/VMichael1999/polyline_animation_plus), un fork de tu
paquete `google_map_animation`. Restauré tu aviso BSD-3-Clause en `LICENSE`,
lo mencioné en el README y agregué un encabezado de origen en los archivos
copiados. Perdón por no haberlo hecho desde la primera versión.

Planeo corregir y agregar, entre otras cosas:
- retrasos de animación que acortaban la duración,
- puntos equidistantes en `generateEquidistantPolylineByDuration`,
- modo `latestOnly` para marcadores, seguimiento de vehículo sobre ruta,
- pausa/seek de animaciones, animators nuevos y cámara que sigue al vehículo.

Si te interesa, puedo enviarlas como PR a tu repo en lugar de mantener el
fork aparte. Dime qué prefieres.

Gracias por el trabajo original,
Michael

# polyline_animation_plus example

An app to try the package by hand. It has two screens:

- **Vehicle tracking.** A car drives along a route while a simulated GPS reports its position. Change the speed, how often the GPS reports, and how noisy it is, and try `queue` and `latestOnly`, adaptive durations, `followRoute`, `consumeRoute`, the tolerance, the position that is off the route, and the camera that follows the car. The chips on top show the frames per second, the slowest frame, the marker updates per second and the distance driven.
- **Animators.** The same route drawn with every animator (including colors by section), with a button to pause, buttons and a slider to seek, and the progress and the number of passes that the `PolylineAnimationHandle` reports.

The route is in `lib/data.dart`.

## Run it

You need a Google Maps key of your own. In your Google Cloud project enable **Maps SDK for iOS** and/or **Maps SDK for Android**, then put the key in the file that git ignores:

| Platform | Copy | To | And set |
| --- | --- | --- | --- |
| iOS | `ios/Flutter/Secrets.xcconfig.example` | `ios/Flutter/Secrets.xcconfig` | `MAPS_API_KEY=...` |
| Android | `android/secrets.properties.example` | `android/secrets.properties` | `MAPS_API_KEY=...` |

Never commit the key. The two files are in `.gitignore`.

```bash
cd example
flutter run
```

Without a key the app still runs, but the map shows no tiles. Routes, markers and animations are drawn on top.

## Things worth trying

- **Reduce motion.** Turn it on in the system accessibility settings: polylines are drawn as they are and the car goes to its position at once.
- **Background.** Send the app to the background and come back: the polyline animations go on from where they were.
- **Camera.** Turn on *Follow the car* and drag the map: the camera stops following.
- **Poor GPS.** Increase the noise and set the GPS to every 5 seconds. Compare `queue` with `latestOnly` and the adaptive duration.

## Notes

- The iOS project targets iOS 15.6 and the Android build uses Gradle 9, as current Flutter requires.
- On the iOS simulator use a recent Flutter version (the 3.47 line was used to write this).

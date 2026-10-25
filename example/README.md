# polyline_animation_plus example

An app to try the package by hand. It has two screens:

- **Vehicle tracking.** A car drives along a route while a simulated GPS reports its position. Change the speed, how often the GPS reports, and how noisy it is, and try `queue` and `latestOnly`, adaptive durations, `followRoute`, `consumeRoute`, the tolerance, the position that is off the route, and the camera that follows the car. The chips on top show the frames per second, the slowest frame, the marker updates per second and the distance driven.
- **Animators.** The same route drawn with every animator (including colors by section), with a button to pause, buttons and a slider to seek, and the progress and the number of passes that the `PolylineAnimationHandle` reports.

The route is in `lib/data.dart`.

## Run it

You need a Google Maps key of your own. In your Google Cloud project enable **Maps SDK for iOS** and/or **Maps SDK for Android**. Then create the file `.env` next to `pubspec.yaml` by copying `.env.example`, and put your key in it:

```bash
cd example
cp .env.example .env
# edit .env and replace your_key_here with your key
```

```
MAPS_API_KEY=your_key_here
```

- Write it exactly like that: one line, no quotes and no spaces around the `=`. The same file is read by the iOS build (as an `xcconfig`) and by the Android build (as a properties file).
- Never commit the key. `.env` is in `.gitignore`; `.env.example` is the one that is in the repository.
- After changing the key, do a clean build (`flutter clean`) so the platform picks it up.

```bash
flutter run
```

Without a key the app still runs, but the map shows no tiles. Routes, markers and animations are drawn on top.

## The car

The car is drawn from a single picture of it seen from above (`assets/car.png`). `tool/make_car_sprites.py` builds a small 3D model of it (roof, glass and hood from your picture, and doors, windows, wheels, lights, grille and plates drawn by the script) and renders 72 pictures, one every 5 degrees, with the camera tilted 45 degrees. They are in `assets/car_3d/`. The app shows the one that matches the direction the car faces on the screen, using `markerFrameBuilder`.

To change the car, replace `assets/car.png` (front pointing up) and run, with Pillow installed (`pip install pillow`):

```bash
python3 tool/make_car_sprites.py
```

The pictures are made for a tilt of 45 degrees. The proportions and the sides are set at the top of the script.

## Things worth trying

- **Reduce motion.** Turn it on in the system accessibility settings: polylines are drawn as they are and the car goes to its position at once.
- **Background.** Send the app to the background and come back: the polyline animations go on from where they were.
- **Camera.** The camera follows the car from the start. Drag the map and it stops following. With *North up* you see the car from the side; with *Turns with car* the map turns after it (set *Map lag* to 0 to turn at once).
- **Poor GPS.** Increase the noise and set the GPS to every 5 seconds. Compare `queue` with `latestOnly` and the adaptive duration.

## Notes

- The iOS project targets iOS 15.6 and the Android build uses Gradle 9, as current Flutter requires.
- On the iOS simulator use a recent Flutter version (the 3.47 line was used to write this).

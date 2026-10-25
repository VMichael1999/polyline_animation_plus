import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

void expectPoints(List<LatLng> actual, List<LatLng> expected, double delta) {
  expect(actual, hasLength(expected.length));
  for (var i = 0; i < expected.length; i++) {
    expect(actual[i].latitude, closeTo(expected[i].latitude, delta));
    expect(actual[i].longitude, closeTo(expected[i].longitude, delta));
  }
}

void main() {
  // The example of the Google documentation:
  // https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  const points = [
    LatLng(38.5, -120.2),
    LatLng(40.7, -120.95),
    LatLng(43.252, -126.453),
  ];
  const encoded = r'_p~iF~ps|U_ulLnnqC_mqNvxq`@';

  group('PolylineCodec.decode', () {
    test('reads the example of the documentation', () {
      expectPoints(PolylineCodec.decode(encoded), points, 1e-9);
    });

    test('reads one point', () {
      expectPoints(PolylineCodec.decode('_p~iF~ps|U'), [points.first], 1e-9);
    });

    test('an empty text has no points', () {
      expect(PolylineCodec.decode(''), isEmpty);
    });

    test('reads the origin', () {
      expect(PolylineCodec.decode('??'), [const LatLng(0, 0)]);
    });

    test('reads precision 6', () {
      final text = PolylineCodec.encode(points, precision: 6);
      expectPoints(PolylineCodec.decode(text, precision: 6), points, 1e-9);
    });

    test('rejects a character that is not part of the format', () {
      expect(() => PolylineCodec.decode('_p~iF ~ps|U'), throwsFormatException);
      expect(() => PolylineCodec.decode('_p~iFé'), throwsFormatException);
    });

    test('rejects a text that ends in the middle of a value', () {
      expect(() => PolylineCodec.decode('_p~iF~ps|'), throwsFormatException);
      expect(() => PolylineCodec.decode('_p~iF'), throwsFormatException);
    });

    test('rejects a precision that does not make sense', () {
      expect(
          () => PolylineCodec.decode(encoded, precision: -1), throwsRangeError);
      expect(
          () => PolylineCodec.decode(encoded, precision: 10), throwsRangeError);
    });
  });

  group('PolylineCodec.encode', () {
    test('writes the example of the documentation', () {
      expect(PolylineCodec.encode(points), encoded);
    });

    test('writes nothing for no points', () {
      expect(PolylineCodec.encode(const []), '');
    });

    test('writes the origin', () {
      expect(PolylineCodec.encode(const [LatLng(0, 0)]), '??');
    });

    test('rounds to the precision', () {
      final text =
          PolylineCodec.encode(const [LatLng(10.123456789, 20.987654321)]);
      expectPoints(
        PolylineCodec.decode(text),
        const [LatLng(10.12346, 20.98765)],
        1e-9,
      );
    });

    test('keeps the order and handles points that go back and forth', () {
      const zigzag = [
        LatLng(-33.8688, 151.2093),
        LatLng(48.8566, 2.3522),
        LatLng(-33.8688, 151.2093),
        LatLng(-90, -180),
        LatLng(90, 180),
      ];
      expectPoints(
        PolylineCodec.decode(PolylineCodec.encode(zigzag)),
        zigzag,
        1e-5,
      );
    });
  });

  test('a long random route survives going back and forth', () {
    final random = Random(42);
    final route = [
      for (var i = 0; i < 2000; i++)
        LatLng(
          random.nextDouble() * 180 - 90,
          random.nextDouble() * 360 - 180,
        ),
    ];

    for (final precision in [5, 6]) {
      final text = PolylineCodec.encode(route, precision: precision);
      expectPoints(
        PolylineCodec.decode(text, precision: precision),
        route,
        0.5 / pow(10, precision),
      );
    }
  });
}

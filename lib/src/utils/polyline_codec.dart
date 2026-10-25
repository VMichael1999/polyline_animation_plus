import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// Reads and writes the Google Encoded Polyline Algorithm Format.
///
/// It is the compact text that the Directions API returns in
/// `overview_polyline.points` and `polyline.points`. See
/// https://developers.google.com/maps/documentation/utilities/polylinealgorithm
final class PolylineCodec {
  PolylineCodec._();

  /// Turns an encoded polyline into its points.
  ///
  /// [precision] is the number of decimals of the coordinates: 5 for the usual
  /// format and 6 for the one some services use. Throws a [FormatException] if
  /// [encoded] is not a valid encoded polyline.
  static List<LatLng> decode(String encoded, {int precision = 5}) {
    final factor = _factor(precision);
    final points = <LatLng>[];

    var index = 0;
    var latitude = 0;
    var longitude = 0;

    int readValue() {
      var result = 0;
      var shift = 0;
      int chunk;
      do {
        if (index >= encoded.length) {
          throw FormatException('The encoded polyline ends early', encoded);
        }
        chunk = encoded.codeUnitAt(index++) - 63;
        if (chunk < 0 || chunk > 63) {
          throw FormatException(
            'Not a valid encoded polyline character',
            encoded,
            index - 1,
          );
        }
        result |= (chunk & 0x1f) << shift;
        shift += 5;
      } while (chunk >= 0x20);

      return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    }

    while (index < encoded.length) {
      latitude += readValue();
      longitude += readValue();
      points.add(LatLng(latitude / factor, longitude / factor));
    }
    return points;
  }

  /// Turns points into an encoded polyline.
  ///
  /// [precision] is the number of decimals to keep: 5 for the usual format and
  /// 6 for the one some services use.
  static String encode(List<LatLng> points, {int precision = 5}) {
    final factor = _factor(precision);
    final buffer = StringBuffer();

    var previousLatitude = 0;
    var previousLongitude = 0;
    for (final point in points) {
      final latitude = (point.latitude * factor).round();
      final longitude = (point.longitude * factor).round();

      _write(buffer, latitude - previousLatitude);
      _write(buffer, longitude - previousLongitude);

      previousLatitude = latitude;
      previousLongitude = longitude;
    }
    return buffer.toString();
  }

  static void _write(StringBuffer buffer, int value) {
    var remaining = value < 0 ? ~(value << 1) : value << 1;
    while (remaining >= 0x20) {
      buffer.writeCharCode((0x20 | (remaining & 0x1f)) + 63);
      remaining >>= 5;
    }
    buffer.writeCharCode(remaining + 63);
  }

  static int _factor(int precision) {
    if (precision < 0 || precision > 9) {
      throw RangeError.range(precision, 0, 9, 'precision');
    }
    var factor = 1;
    for (var i = 0; i < precision; i++) {
      factor *= 10;
    }
    return factor;
  }
}

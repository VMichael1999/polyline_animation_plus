// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.
// Internal, not exported: public API docs are only required for exported code.
// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../utils/spherical_util.dart';

class LocationTween extends Tween<LatLng> {
  LocationTween({required LatLng begin, required LatLng end})
      : super(begin: begin, end: end);

  @override
  LatLng get begin => super.begin!;

  @override
  LatLng get end => super.end!;

  @override
  LatLng lerp(double t) {
    return SphericalUtil.interpolate(begin, end, t);
  }

  void swap(LatLng newPosition) {
    begin = end;
    end = newPosition;
  }

  double get bearing => SphericalUtil.computeHeading(begin, end).toDouble();
}

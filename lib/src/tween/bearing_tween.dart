// Based on google_map_animation by Manish Relani (BSD-3-Clause).
// https://github.com/manishrelani/google_map_animation
// See LICENSE for the original notice and the changes made in this fork.

import 'package:flutter/material.dart';

import '../utils/spherical_util.dart';

class BearingTween extends Tween<double> {
  BearingTween({required double begin, required double end})
    : super(begin: begin, end: end);

  @override
  double get begin => super.begin!;

  @override
  double get end => super.end!;

  void swap(double newBearing) {
    begin = end;
    end = newBearing;
  }

  @override
  double lerp(double t) {
    assert(t >= 0 && t <= 1, 'value must between 0.0 and 1.0');
    if (t == 0.0) return begin;
    if (t == 1.0) return end;

    return SphericalUtil.angleLerp(begin, end, t);
  }

  @override
  double transform(double t) {
    return lerp(t);
  }
}

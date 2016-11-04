// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart';

void main() {
  test('toString control test', () {
    expect(Curves.linear, hasOneLineDescription);
    expect(new SawTooth(3), hasOneLineDescription);
    expect(new Interval(0.25, 0.75), hasOneLineDescription);
    expect(new Interval(0.25, 0.75, curve: Curves.ease), hasOneLineDescription);
  });

  test('Curve flipped control test', () {
    Curve ease = Curves.ease;
    Curve flippedEase = ease.flipped;
    expect(flippedEase.transform(0.0), lessThan(0.001));
    expect(flippedEase.transform(0.5), lessThan(ease.transform(0.5)));
    expect(flippedEase.transform(1.0), greaterThan(0.999));
    expect(flippedEase, hasOneLineDescription);
  });

  test('Threshold has a threshold', () {
    Curve step = new Threshold(0.25);
    expect(step.transform(0.0), 0.0);
    expect(step.transform(0.24), 0.0);
    expect(step.transform(0.25), 1.0);
    expect(step.transform(0.26), 1.0);
    expect(step.transform(1.0), 1.0);
  });

  void expectStaysInBounds(Curve curve) {
    expect(curve.transform(0.0), inInclusiveRange(0.0, 1.0));
    expect(curve.transform(0.1), inInclusiveRange(0.0, 1.0));
    expect(curve.transform(0.2), inInclusiveRange(0.0, 1.0));
    expect(curve.transform(0.3), inInclusiveRange(0.0, 1.0));
    expect(curve.transform(0.4), inInclusiveRange(0.0, 1.0));
    expect(curve.transform(0.5), inInclusiveRange(0.0, 1.0));
    expect(curve.transform(0.6), inInclusiveRange(0.0, 1.0));
    expect(curve.transform(0.7), inInclusiveRange(0.0, 1.0));
    expect(curve.transform(0.8), inInclusiveRange(0.0, 1.0));
    expect(curve.transform(0.9), inInclusiveRange(0.0, 1.0));
    expect(curve.transform(1.0), inInclusiveRange(0.0, 1.0));
  }

  test('Bounce stays in bounds', () {
    expectStaysInBounds(Curves.bounceIn);
    expectStaysInBounds(Curves.bounceOut);
    expectStaysInBounds(Curves.bounceInOut);
  });

  List<double> estimateBounds(Curve curve) {
    List<double> values = <double>[];

    values.add(curve.transform(0.0));
    values.add(curve.transform(0.1));
    values.add(curve.transform(0.2));
    values.add(curve.transform(0.3));
    values.add(curve.transform(0.4));
    values.add(curve.transform(0.5));
    values.add(curve.transform(0.6));
    values.add(curve.transform(0.7));
    values.add(curve.transform(0.8));
    values.add(curve.transform(0.9));
    values.add(curve.transform(1.0));

    return <double>[
      values.reduce(math.min),
      values.reduce(math.max),
    ];
  }

  test('Ellastic overshoots its bounds', () {
    expect(Curves.elasticIn, hasOneLineDescription);
    expect(Curves.elasticOut, hasOneLineDescription);
    expect(Curves.elasticInOut, hasOneLineDescription);

    List<double> bounds;
    bounds = estimateBounds(Curves.elasticIn);
    expect(bounds[0], lessThan(0.0));
    expect(bounds[1], lessThanOrEqualTo(1.0));
    bounds = estimateBounds(Curves.elasticOut);
    expect(bounds[0], greaterThanOrEqualTo(0.0));
    expect(bounds[1], greaterThan(1.0));
    bounds = estimateBounds(Curves.elasticInOut);
    expect(bounds[0], lessThan(0.0));
    expect(bounds[1], greaterThan(1.0));
  });
}

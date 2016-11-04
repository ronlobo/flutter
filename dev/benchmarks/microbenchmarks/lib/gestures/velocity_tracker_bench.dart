// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'package:flutter/gestures.dart';
import 'data/velocity_tracker_data.dart';

const int _kNumIters = 10000;

void main() {
  final VelocityTracker tracker = new VelocityTracker();
  final Stopwatch watch = new Stopwatch();
  print('Velocity tracker benchmark...');
  watch.start();
  for (int i = 0; i < _kNumIters; i += 1) {
    for (PointerEvent event in velocityEventData) {
      if (event is PointerDownEvent || event is PointerMoveEvent)
        tracker.addPosition(event.timeStamp, event.position);
      if (event is PointerUpEvent)
        tracker.getVelocity();
    }
  }
  watch.stop();
  print('Velocity tracker: ${(watch.elapsedMicroseconds / _kNumIters).toStringAsFixed(1)}µs per iteration');
  exit(0);
}

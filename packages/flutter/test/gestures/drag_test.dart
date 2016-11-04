// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/gestures.dart';

import 'gesture_tester.dart';

void main() {
  setUp(ensureGestureBinding);

  testGesture('Should recognize pan', (GestureTester tester) {
    PanGestureRecognizer pan = new PanGestureRecognizer();
    TapGestureRecognizer tap = new TapGestureRecognizer();

    bool didStartPan = false;
    pan.onStart = (_) {
      didStartPan = true;
    };

    Offset updatedScrollDelta;
    pan.onUpdate = (DragUpdateDetails details) {
      updatedScrollDelta = details.delta;
    };

    bool didEndPan = false;
    pan.onEnd = (DragEndDetails details) {
      didEndPan = true;
    };

    bool didTap = false;
    tap.onTap = () {
      didTap = true;
    };

    TestPointer pointer = new TestPointer(5);
    PointerDownEvent down = pointer.down(const Point(10.0, 10.0));
    pan.addPointer(down);
    tap.addPointer(down);
    tester.closeArena(5);
    expect(didStartPan, isFalse);
    expect(updatedScrollDelta, isNull);
    expect(didEndPan, isFalse);
    expect(didTap, isFalse);

    tester.route(down);
    expect(didStartPan, isFalse);
    expect(updatedScrollDelta, isNull);
    expect(didEndPan, isFalse);
    expect(didTap, isFalse);

    tester.route(pointer.move(const Point(20.0, 20.0)));
    expect(didStartPan, isTrue);
    didStartPan = false;
    expect(updatedScrollDelta, const Offset(10.0, 10.0));
    updatedScrollDelta = null;
    expect(didEndPan, isFalse);
    expect(didTap, isFalse);

    tester.route(pointer.move(const Point(20.0, 25.0)));
    expect(didStartPan, isFalse);
    expect(updatedScrollDelta, const Offset(0.0, 5.0));
    updatedScrollDelta = null;
    expect(didEndPan, isFalse);
    expect(didTap, isFalse);

    tester.route(pointer.up());
    expect(didStartPan, isFalse);
    expect(updatedScrollDelta, isNull);
    expect(didEndPan, isTrue);
    didEndPan = false;
    expect(didTap, isFalse);

    pan.dispose();
    tap.dispose();
  });

  testGesture('Should recognize drag', (GestureTester tester) {
    HorizontalDragGestureRecognizer drag = new HorizontalDragGestureRecognizer();

    bool didStartDrag = false;
    drag.onStart = (_) {
      didStartDrag = true;
    };

    double updatedDelta;
    drag.onUpdate = (DragUpdateDetails details) {
      updatedDelta = details.primaryDelta;
    };

    bool didEndDrag = false;
    drag.onEnd = (DragEndDetails details) {
      didEndDrag = true;
    };

    TestPointer pointer = new TestPointer(5);
    PointerDownEvent down = pointer.down(const Point(10.0, 10.0));
    drag.addPointer(down);
    tester.closeArena(5);
    expect(didStartDrag, isFalse);
    expect(updatedDelta, isNull);
    expect(didEndDrag, isFalse);

    tester.route(down);
    expect(didStartDrag, isTrue);
    expect(updatedDelta, isNull);
    expect(didEndDrag, isFalse);

    tester.route(pointer.move(const Point(20.0, 25.0)));
    expect(didStartDrag, isTrue);
    didStartDrag = false;
    expect(updatedDelta, 10.0);
    updatedDelta = null;
    expect(didEndDrag, isFalse);

    tester.route(pointer.move(const Point(20.0, 25.0)));
    expect(didStartDrag, isFalse);
    expect(updatedDelta, 0.0);
    updatedDelta = null;
    expect(didEndDrag, isFalse);

    tester.route(pointer.up());
    expect(didStartDrag, isFalse);
    expect(updatedDelta, isNull);
    expect(didEndDrag, isTrue);
    didEndDrag = false;

    drag.dispose();
  });

  testGesture('Clamp max velocity', (GestureTester tester) {
    HorizontalDragGestureRecognizer drag = new HorizontalDragGestureRecognizer();

    Velocity velocity;
    drag.onEnd = (DragEndDetails details) {
      velocity = details.velocity;
    };

    TestPointer pointer = new TestPointer(5);
    PointerDownEvent down = pointer.down(const Point(10.0, 25.0), timeStamp: const Duration(milliseconds: 10));
    drag.addPointer(down);
    tester.closeArena(5);
    tester.route(down);
    tester.route(pointer.move(const Point(20.0, 25.0), timeStamp: const Duration(milliseconds: 10)));
    tester.route(pointer.move(const Point(30.0, 25.0), timeStamp: const Duration(milliseconds: 11)));
    tester.route(pointer.move(const Point(40.0, 25.0), timeStamp: const Duration(milliseconds: 12)));
    tester.route(pointer.move(const Point(50.0, 25.0), timeStamp: const Duration(milliseconds: 13)));
    tester.route(pointer.move(const Point(60.0, 25.0), timeStamp: const Duration(milliseconds: 14)));
    tester.route(pointer.move(const Point(70.0, 25.0), timeStamp: const Duration(milliseconds: 15)));
    tester.route(pointer.move(const Point(80.0, 25.0), timeStamp: const Duration(milliseconds: 16)));
    tester.route(pointer.move(const Point(90.0, 25.0), timeStamp: const Duration(milliseconds: 17)));
    tester.route(pointer.move(const Point(100.0, 25.0), timeStamp: const Duration(milliseconds: 18)));
    tester.route(pointer.move(const Point(110.0, 25.0), timeStamp: const Duration(milliseconds: 19)));
    tester.route(pointer.move(const Point(120.0, 25.0), timeStamp: const Duration(milliseconds: 20)));
    tester.route(pointer.up(timeStamp: const Duration(milliseconds: 20)));
    expect(velocity.pixelsPerSecond.dx, inInclusiveRange(0.99 * kMaxFlingVelocity, kMaxFlingVelocity));

    drag.dispose();
  });
}

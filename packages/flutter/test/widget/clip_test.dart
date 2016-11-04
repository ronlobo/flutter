// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

final List<String> log = <String>[];

class PathClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    log.add('getClip');
    return new Path()
      ..addRect(new Rect.fromLTWH(50.0, 50.0, 100.0, 100.0));
  }
  @override
  bool shouldReclip(PathClipper oldClipper) => false;
}

class ValueClipper<T> extends CustomClipper<T> {
  ValueClipper(this.message, this.value);

  final String message;
  final T value;

  @override
  T getClip(Size size) {
    log.add(message);
    return value;
  }

  @override
  bool shouldReclip(ValueClipper<T> oldClipper) {
    return oldClipper.message != message || oldClipper.value != value;
  }
}

void main() {
  testWidgets('ClipPath', (WidgetTester tester) async {
    await tester.pumpWidget(
      new ClipPath(
        clipper: new PathClipper(),
        child: new GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () { log.add('tap'); },
        )
      )
    );
    expect(log, equals(<String>['getClip']));

    await tester.tapAt(new Point(10.0, 10.0));
    expect(log, equals(<String>['getClip']));
    log.clear();

    await tester.tapAt(new Point(100.0, 100.0));
    expect(log, equals(<String>['tap']));
    log.clear();
  });

  testWidgets('ClipOval', (WidgetTester tester) async {
    await tester.pumpWidget(
      new ClipOval(
        child: new GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () { log.add('tap'); },
        )
      )
    );
    expect(log, equals(<String>[]));

    await tester.tapAt(new Point(10.0, 10.0));
    expect(log, equals(<String>[]));
    log.clear();

    await tester.tapAt(new Point(400.0, 300.0));
    expect(log, equals(<String>['tap']));
    log.clear();
  });

  testWidgets('Transparent ClipOval hit test', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Opacity(
        opacity: 0.0,
        child: new ClipOval(
          child: new GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () { log.add('tap'); },
          )
        )
      )
    );
    expect(log, equals(<String>[]));

    await tester.tapAt(new Point(10.0, 10.0));
    expect(log, equals(<String>[]));
    log.clear();

    await tester.tapAt(new Point(400.0, 300.0));
    expect(log, equals(<String>['tap']));
    log.clear();
  });

  testWidgets('ClipRect', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Align(
        alignment: FractionalOffset.topLeft,
        child: new SizedBox(
          width: 100.0,
          height: 100.0,
          child: new ClipRect(
            clipper: new ValueClipper<Rect>('a', new Rect.fromLTWH(5.0, 5.0, 10.0, 10.0)),
            child: new GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () { log.add('tap'); },
            )
          )
        )
      )
    );
    expect(log, equals(<String>['a']));

    await tester.tapAt(new Point(10.0, 10.0));
    expect(log, equals(<String>['a', 'tap']));

    await tester.tapAt(new Point(100.0, 100.0));
    expect(log, equals(<String>['a', 'tap']));

    await tester.pumpWidget(
      new Align(
        alignment: FractionalOffset.topLeft,
        child: new SizedBox(
          width: 100.0,
          height: 100.0,
          child: new ClipRect(
            clipper: new ValueClipper<Rect>('a', new Rect.fromLTWH(5.0, 5.0, 10.0, 10.0)),
            child: new GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () { log.add('tap'); },
            )
          )
        )
      )
    );
    expect(log, equals(<String>['a', 'tap']));

    await tester.pumpWidget(
      new Align(
        alignment: FractionalOffset.topLeft,
        child: new SizedBox(
          width: 200.0,
          height: 200.0,
          child: new ClipRect(
            clipper: new ValueClipper<Rect>('a', new Rect.fromLTWH(5.0, 5.0, 10.0, 10.0)),
            child: new GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () { log.add('tap'); },
            )
          )
        )
      )
    );
    expect(log, equals(<String>['a', 'tap', 'a']));

    await tester.pumpWidget(
      new Align(
        alignment: FractionalOffset.topLeft,
        child: new SizedBox(
          width: 200.0,
          height: 200.0,
          child: new ClipRect(
            clipper: new ValueClipper<Rect>('a', new Rect.fromLTWH(5.0, 5.0, 10.0, 10.0)),
            child: new GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () { log.add('tap'); },
            )
          )
        )
      )
    );
    expect(log, equals(<String>['a', 'tap', 'a']));

    await tester.pumpWidget(
      new Align(
        alignment: FractionalOffset.topLeft,
        child: new SizedBox(
          width: 200.0,
          height: 200.0,
          child: new ClipRect(
            clipper: new ValueClipper<Rect>('b', new Rect.fromLTWH(5.0, 5.0, 10.0, 10.0)),
            child: new GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () { log.add('tap'); },
            )
          )
        )
      )
    );
    expect(log, equals(<String>['a', 'tap', 'a', 'b']));

    await tester.pumpWidget(
      new Align(
        alignment: FractionalOffset.topLeft,
        child: new SizedBox(
          width: 200.0,
          height: 200.0,
          child: new ClipRect(
            clipper: new ValueClipper<Rect>('c', new Rect.fromLTWH(25.0, 25.0, 10.0, 10.0)),
            child: new GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () { log.add('tap'); },
            )
          )
        )
      )
    );
    expect(log, equals(<String>['a', 'tap', 'a', 'b', 'c']));

    await tester.tapAt(new Point(30.0, 30.0));
    expect(log, equals(<String>['a', 'tap', 'a', 'b', 'c', 'tap']));

    await tester.tapAt(new Point(100.0, 100.0));
    expect(log, equals(<String>['a', 'tap', 'a', 'b', 'c', 'tap']));
  });

}

// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Rotated box control test', (WidgetTester tester) async {
    List<String> log = <String>[];
    Key rotatedBoxKey = new UniqueKey();

    await tester.pumpWidget(
      new Center(
        child: new RotatedBox(
          key: rotatedBoxKey,
          quarterTurns: 1,
          child: new Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              new GestureDetector(
                onTap: () { log.add('left'); },
                child: new Container(
                  width: 100.0,
                  height: 40.0,
                  decoration: new BoxDecoration(backgroundColor: Colors.blue[500])
                )
              ),
              new GestureDetector(
                onTap: () { log.add('right'); },
                child: new Container(
                  width: 75.0,
                  height: 65.0,
                  decoration: new BoxDecoration(backgroundColor: Colors.blue[500])
                )
              ),
            ]
          )
        )
      )
    );

    RenderBox box = tester.renderObject(find.byKey(rotatedBoxKey));
    expect(box.size.width, equals(65.0));
    expect(box.size.height, equals(175.0));

    await tester.tapAt(new Point(420.0, 280.0));
    expect(log, equals(<String>['left']));
    log.clear();

    await tester.tapAt(new Point(380.0, 320.0));
    expect(log, equals(<String>['right']));
    log.clear();
  });
}

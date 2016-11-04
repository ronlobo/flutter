// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Scrollbar doesn\'t show when tapping list', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Center(
        child: new Container(
          decoration: new BoxDecoration(
            border: new Border.all(color: const Color(0xFFFFFF00))
          ),
          height: 200.0,
          width: 300.0,
          child: new Scrollbar(
            child: new Block(
              children: <Widget>[
                new Container(height: 40.0, child: new Text('0')),
                new Container(height: 40.0, child: new Text('1')),
                new Container(height: 40.0, child: new Text('2')),
                new Container(height: 40.0, child: new Text('3')),
                new Container(height: 40.0, child: new Text('4')),
                new Container(height: 40.0, child: new Text('5')),
                new Container(height: 40.0, child: new Text('6')),
                new Container(height: 40.0, child: new Text('7')),
              ]
            )
          )
        )
      )
    );

    SchedulerBinding.instance.debugAssertNoTransientCallbacks('Building a list with a scrollbar triggered an animation.');
    await tester.tap(find.byType(Block));
    SchedulerBinding.instance.debugAssertNoTransientCallbacks('Tapping a block with a scrollbar triggered an animation.');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.scroll(find.byType(Block), const Offset(0.0, -10.0));
    expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
  });
}

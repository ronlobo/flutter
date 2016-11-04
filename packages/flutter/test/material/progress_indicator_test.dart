// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';

void main() {

  // The "can be constructed" tests that follow are primarily to ensure that any
  // animations started by the progress indicators are stopped at dispose() time.

  testWidgets('LinearProgressIndicator(value: 0.0) can be constructed', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Center(
        child: new SizedBox(
          width: 200.0,
          child: new LinearProgressIndicator(value: 0.0)
        )
      )
    );
  });

  testWidgets('LinearProgressIndicator(value: null) can be constructed', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Center(
        child: new SizedBox(
          width: 200.0,
          child: new LinearProgressIndicator(value: null)
        )
      )
    );
  });

  testWidgets('CircularProgressIndicator(value: 0.0) can be constructed', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Center(
        child: new CircularProgressIndicator(value: 0.0)
      )
    );
  });

  testWidgets('CircularProgressIndicator(value: null) can be constructed', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Center(
        child: new CircularProgressIndicator(value: null)
      )
    );
  });

  testWidgets('LinearProgressIndicator causes a repaint when it changes', (WidgetTester tester) async {
    await tester.pumpWidget(new Block(children: <Widget>[new LinearProgressIndicator(value: 0.0)]));
    List<Layer> layers1 = tester.layers;
    await tester.pumpWidget(new Block(children: <Widget>[new LinearProgressIndicator(value: 0.5)]));
    List<Layer> layers2 = tester.layers;
    expect(layers1, isNot(equals(layers2)));
  });
}

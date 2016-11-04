// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

void main() {
  testWidgets('FractionallySizedBox', (WidgetTester tester) async {
    GlobalKey inner = new GlobalKey();
    await tester.pumpWidget(new OverflowBox(
      minWidth: 0.0,
      maxWidth: 100.0,
      minHeight: 0.0,
      maxHeight: 100.0,
      alignment: const FractionalOffset(0.0, 0.0),
      child: new Center(
        child: new FractionallySizedBox(
          widthFactor: 0.5,
          heightFactor: 0.25,
          child: new Container(
            key: inner
          )
        )
      )
    ));
    RenderBox box = inner.currentContext.findRenderObject();
    expect(box.size, equals(const Size(50.0, 25.0)));
    expect(box.localToGlobal(Point.origin), equals(const Point(25.0, 37.5)));
  });
}

// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Floating Action Button control test', (WidgetTester tester) async {
    bool didPressButton = false;
    await tester.pumpWidget(
      new Center(
        child: new FloatingActionButton(
          onPressed: () {
            didPressButton = true;
          },
          child: new Icon(Icons.add)
        )
      )
    );

    expect(didPressButton, isFalse);
    await tester.tap(find.byType(Icon));
    expect(didPressButton, isTrue);
  });
}

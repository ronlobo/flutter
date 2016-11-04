// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

final BoxDecoration kBoxDecorationA = new BoxDecoration(
  backgroundColor: const Color(0xFFFF0000)
);

final BoxDecoration kBoxDecorationB = new BoxDecoration(
  backgroundColor: const Color(0xFF00FF00)
);

final BoxDecoration kBoxDecorationC = new BoxDecoration(
  backgroundColor: const Color(0xFF0000FF)
);

class TestBuildCounter extends StatelessWidget {
  static int buildCount = 0;

  @override
  Widget build(BuildContext context) {
    buildCount += 1;
    return new DecoratedBox(decoration: kBoxDecorationA);
  }
}


class FlipWidget extends StatefulWidget {
  FlipWidget({ Key key, this.left, this.right }) : super(key: key);

  final Widget left;
  final Widget right;

  @override
  FlipWidgetState createState() => new FlipWidgetState();
}

class FlipWidgetState extends State<FlipWidget> {
  bool _showLeft = true;

  void flip() {
    setState(() {
      _showLeft = !_showLeft;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showLeft ? config.left : config.right;
  }
}

void flipStatefulWidget(WidgetTester tester) {
  tester.state/*<FlipWidgetState>*/(find.byType(FlipWidget)).flip();
}

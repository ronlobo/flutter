// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

class Inside extends StatefulWidget {
  @override
  InsideState createState() => new InsideState();
}

class InsideState extends State<Inside> {
  @override
  Widget build(BuildContext context) {
    return new Listener(
      onPointerDown: _handlePointerDown,
      child: new Text('INSIDE')
    );
  }

  void _handlePointerDown(_) {
    setState(() { });
  }
}

class Middle extends StatefulWidget {
  Middle({ this.child });

  final Inside child;

  @override
  MiddleState createState() => new MiddleState();
}

class MiddleState extends State<Middle> {
  @override
  Widget build(BuildContext context) {
    return new Listener(
      onPointerDown: _handlePointerDown,
      child: config.child
    );
  }

  void _handlePointerDown(_) {
    setState(() { });
  }
}

class Outside extends StatefulWidget {
  @override
  OutsideState createState() => new OutsideState();
}

class OutsideState extends State<Outside> {
  @override
  Widget build(BuildContext context) {
    return new Middle(child: new Inside());
  }
}

void main() {
  testWidgets('setState() smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(new Outside());
    Point location = tester.getCenter(find.text('INSIDE'));
    TestGesture gesture = await tester.startGesture(location);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  });
}

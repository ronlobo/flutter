// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

class TestWidget extends StatefulWidget {
  TestWidget({ this.child, this.persistentState, this.syncedState });

  final Widget child;
  final int persistentState;
  final int syncedState;

  @override
  TestWidgetState createState() => new TestWidgetState();
}

class TestWidgetState extends State<TestWidget> {
  int persistentState;
  int syncedState;
  int updates = 0;

  @override
  void initState() {
    super.initState();
    persistentState = config.persistentState;
    syncedState = config.syncedState;
  }

  @override
  void didUpdateConfig(TestWidget oldConfig) {
    syncedState = config.syncedState;
    // we explicitly do NOT sync the persistentState from the new instance
    // because we're using that to track whether we got recreated
    updates += 1;
  }

  @override
  Widget build(BuildContext context) => config.child;
}

void main() {

  testWidgets('no change', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Container(
        child: new Container(
          child: new TestWidget(
            persistentState: 1,
            child: new Container()
          )
        )
      )
    );

    TestWidgetState state = tester.state(find.byType(TestWidget));

    expect(state.persistentState, equals(1));
    expect(state.updates, equals(0));

    await tester.pumpWidget(
      new Container(
        child: new Container(
          child: new TestWidget(
            persistentState: 2,
            child: new Container()
          )
        )
      )
    );

    expect(state.persistentState, equals(1));
    expect(state.updates, equals(1));

    await tester.pumpWidget(new Container());
  });

  testWidgets('remove one', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Container(
        child: new Container(
          child: new TestWidget(
            persistentState: 10,
            child: new Container()
          )
        )
      )
    );

    TestWidgetState state = tester.state(find.byType(TestWidget));

    expect(state.persistentState, equals(10));
    expect(state.updates, equals(0));

    await tester.pumpWidget(
      new Container(
        child: new TestWidget(
          persistentState: 11,
          child: new Container()
        )
      )
    );

    state = tester.state(find.byType(TestWidget));

    expect(state.persistentState, equals(11));
    expect(state.updates, equals(0));

    await tester.pumpWidget(new Container());
  });

  testWidgets('swap instances around', (WidgetTester tester) async {
    Widget a = new TestWidget(persistentState: 0x61, syncedState: 0x41, child: new Text('apple'));
    Widget b = new TestWidget(persistentState: 0x62, syncedState: 0x42, child: new Text('banana'));
    await tester.pumpWidget(new Column());

    GlobalKey keyA = new GlobalKey();
    GlobalKey keyB = new GlobalKey();

    await tester.pumpWidget(
      new Column(
        children: <Widget>[
          new Container(
            key: keyA,
            child: a
          ),
          new Container(
            key: keyB,
            child: b
          )
        ]
      )
    );

    TestWidgetState first, second;

    first = tester.state(find.byConfig(a));
    second = tester.state(find.byConfig(b));

    expect(first.config, equals(a));
    expect(first.persistentState, equals(0x61));
    expect(first.syncedState, equals(0x41));
    expect(second.config, equals(b));
    expect(second.persistentState, equals(0x62));
    expect(second.syncedState, equals(0x42));

    await tester.pumpWidget(
      new Column(
        children: <Widget>[
          new Container(
            key: keyA,
            child: a
          ),
          new Container(
            key: keyB,
            child: b
          )
        ]
      )
    );

    first = tester.state(find.byConfig(a));
    second = tester.state(find.byConfig(b));

    // same as before
    expect(first.config, equals(a));
    expect(first.persistentState, equals(0x61));
    expect(first.syncedState, equals(0x41));
    expect(second.config, equals(b));
    expect(second.persistentState, equals(0x62));
    expect(second.syncedState, equals(0x42));

    // now we swap the nodes over
    // since they are both "old" nodes, they shouldn't sync with each other even though they look alike

    await tester.pumpWidget(
      new Column(
        children: <Widget>[
          new Container(
            key: keyA,
            child: b
          ),
          new Container(
            key: keyB,
            child: a
          )
        ]
      )
    );

    first = tester.state(find.byConfig(b));
    second = tester.state(find.byConfig(a));

    expect(first.config, equals(b));
    expect(first.persistentState, equals(0x61));
    expect(first.syncedState, equals(0x42));
    expect(second.config, equals(a));
    expect(second.persistentState, equals(0x62));
    expect(second.syncedState, equals(0x41));
  });
}

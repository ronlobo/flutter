// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

class StateMarker extends StatefulWidget {
  StateMarker({ Key key, this.child }) : super(key: key);

  final Widget child;

  @override
  StateMarkerState createState() => new StateMarkerState();
}

class StateMarkerState extends State<StateMarker> {
  String marker;

  @override
  Widget build(BuildContext context) {
    if (config.child != null)
      return config.child;
    return new Container();
  }
}

class DeactivateLogger extends StatefulWidget {
  DeactivateLogger({ Key key, this.log }) : super(key: key);

  final List<String> log;

  @override
  DeactivateLoggerState createState() => new DeactivateLoggerState();
}

class DeactivateLoggerState extends State<DeactivateLogger> {
  @override
  void deactivate() {
    config.log.add('deactivate');
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    config.log.add('build');
    return new Container();
  }
}

void main() {
  testWidgets('can reparent state', (WidgetTester tester) async {
    GlobalKey left = new GlobalKey();
    GlobalKey right = new GlobalKey();

    StateMarker grandchild = new StateMarker();
    await tester.pumpWidget(
      new Stack(
        children: <Widget>[
          new Container(
            child: new StateMarker(key: left)
          ),
          new Container(
            child: new StateMarker(
              key: right,
              child: grandchild
            )
          ),
        ]
      )
    );

    StateMarkerState leftState = left.currentState;
    leftState.marker = "left";
    StateMarkerState rightState = right.currentState;
    rightState.marker = "right";

    StateMarkerState grandchildState = tester.state(find.byConfig(grandchild));
    expect(grandchildState, isNotNull);
    grandchildState.marker = "grandchild";

    StateMarker newGrandchild = new StateMarker();
    await tester.pumpWidget(
      new Stack(
        children: <Widget>[
          new Container(
            child: new StateMarker(
              key: right,
              child: newGrandchild
            )
          ),
          new Container(
            child: new StateMarker(key: left)
          ),
        ]
      )
    );

    expect(left.currentState, equals(leftState));
    expect(leftState.marker, equals("left"));
    expect(right.currentState, equals(rightState));
    expect(rightState.marker, equals("right"));

    StateMarkerState newGrandchildState = tester.state(find.byConfig(newGrandchild));
    expect(newGrandchildState, isNotNull);
    expect(newGrandchildState, equals(grandchildState));
    expect(newGrandchildState.marker, equals("grandchild"));

    await tester.pumpWidget(
      new Center(
        child: new Container(
          child: new StateMarker(
            key: left,
            child: new Container()
          )
        )
      )
    );

    expect(left.currentState, equals(leftState));
    expect(leftState.marker, equals("left"));
    expect(right.currentState, isNull);
  });

  testWidgets('can reparent state with multichild widgets', (WidgetTester tester) async {
    GlobalKey left = new GlobalKey();
    GlobalKey right = new GlobalKey();

    StateMarker grandchild = new StateMarker();
    await tester.pumpWidget(
      new Stack(
        children: <Widget>[
          new StateMarker(key: left),
          new StateMarker(
            key: right,
            child: grandchild
          )
        ]
      )
    );

    StateMarkerState leftState = left.currentState;
    leftState.marker = "left";
    StateMarkerState rightState = right.currentState;
    rightState.marker = "right";

    StateMarkerState grandchildState = tester.state(find.byConfig(grandchild));
    expect(grandchildState, isNotNull);
    grandchildState.marker = "grandchild";

    StateMarker newGrandchild = new StateMarker();
    await tester.pumpWidget(
      new Stack(
        children: <Widget>[
          new StateMarker(
            key: right,
            child: newGrandchild
          ),
          new StateMarker(key: left)
        ]
      )
    );

    expect(left.currentState, equals(leftState));
    expect(leftState.marker, equals("left"));
    expect(right.currentState, equals(rightState));
    expect(rightState.marker, equals("right"));

    StateMarkerState newGrandchildState = tester.state(find.byConfig(newGrandchild));
    expect(newGrandchildState, isNotNull);
    expect(newGrandchildState, equals(grandchildState));
    expect(newGrandchildState.marker, equals("grandchild"));

    await tester.pumpWidget(
      new Center(
        child: new Container(
          child: new StateMarker(
            key: left,
            child: new Container()
          )
        )
      )
    );

    expect(left.currentState, equals(leftState));
    expect(leftState.marker, equals("left"));
    expect(right.currentState, isNull);
  });

  testWidgets('can with scrollable list', (WidgetTester tester) async {
    GlobalKey key = new GlobalKey();

    await tester.pumpWidget(new StateMarker(key: key));

    StateMarkerState keyState = key.currentState;
    keyState.marker = "marked";

    await tester.pumpWidget(new ScrollableList(
      itemExtent: 100.0,
      children: <Widget>[
        new Container(
          key: new Key('container'),
          height: 100.0,
          child: new StateMarker(key: key)
        )
      ]
    ));

    expect(key.currentState, equals(keyState));
    expect(keyState.marker, equals("marked"));

    await tester.pumpWidget(new StateMarker(key: key));

    expect(key.currentState, equals(keyState));
    expect(keyState.marker, equals("marked"));
  });

  testWidgets('Reparent during update children', (WidgetTester tester) async {
    GlobalKey key = new GlobalKey();

    await tester.pumpWidget(new Stack(
      children: <Widget>[
        new StateMarker(key: key),
        new Container(width: 100.0, height: 100.0),
      ]
    ));

    StateMarkerState keyState = key.currentState;
    keyState.marker = "marked";

    await tester.pumpWidget(new Stack(
      children: <Widget>[
        new Container(width: 100.0, height: 100.0),
        new StateMarker(key: key),
      ]
    ));

    expect(key.currentState, equals(keyState));
    expect(keyState.marker, equals("marked"));

    await tester.pumpWidget(new Stack(
      children: <Widget>[
        new StateMarker(key: key),
        new Container(width: 100.0, height: 100.0),
      ]
    ));

    expect(key.currentState, equals(keyState));
    expect(keyState.marker, equals("marked"));
  });

  testWidgets('Reparent to child during update children', (WidgetTester tester) async {
    GlobalKey key = new GlobalKey();

    await tester.pumpWidget(new Stack(
      children: <Widget>[
        new Container(width: 100.0, height: 100.0),
        new StateMarker(key: key),
        new Container(width: 100.0, height: 100.0),
      ]
    ));

    StateMarkerState keyState = key.currentState;
    keyState.marker = "marked";

    await tester.pumpWidget(new Stack(
      children: <Widget>[
        new Container(width: 100.0, height: 100.0, child: new StateMarker(key: key)),
        new Container(width: 100.0, height: 100.0),
      ]
    ));

    expect(key.currentState, equals(keyState));
    expect(keyState.marker, equals("marked"));

    await tester.pumpWidget(new Stack(
      children: <Widget>[
        new Container(width: 100.0, height: 100.0),
        new StateMarker(key: key),
        new Container(width: 100.0, height: 100.0),
      ]
    ));

    expect(key.currentState, equals(keyState));
    expect(keyState.marker, equals("marked"));

    await tester.pumpWidget(new Stack(
      children: <Widget>[
        new Container(width: 100.0, height: 100.0),
        new Container(width: 100.0, height: 100.0, child: new StateMarker(key: key)),
      ]
    ));

    expect(key.currentState, equals(keyState));
    expect(keyState.marker, equals("marked"));

    await tester.pumpWidget(new Stack(
      children: <Widget>[
        new Container(width: 100.0, height: 100.0),
        new StateMarker(key: key),
        new Container(width: 100.0, height: 100.0),
      ]
    ));

    expect(key.currentState, equals(keyState));
    expect(keyState.marker, equals("marked"));
  });

  testWidgets('Deactivate implies build', (WidgetTester tester) async {
    GlobalKey key = new GlobalKey();
    List<String> log = <String>[];
    DeactivateLogger logger = new DeactivateLogger(key: key, log: log);

    await tester.pumpWidget(
      new Container(key: new UniqueKey(), child: logger)
    );

    expect(log, equals(<String>['build']));

    await tester.pumpWidget(
      new Container(key: new UniqueKey(), child: logger)
    );

    expect(log, equals(<String>['build', 'deactivate', 'build']));
    log.clear();

    await tester.pump();
    expect(log, isEmpty);
  });

  testWidgets('Reparenting with multiple moves', (WidgetTester tester) async {
    final GlobalKey key1 = new GlobalKey();
    final GlobalKey key2 = new GlobalKey();
    final GlobalKey key3 = new GlobalKey();

    await tester.pumpWidget(
      new Row(
        children: <Widget>[
          new StateMarker(
            key: key1,
            child: new StateMarker(
              key: key2,
              child: new StateMarker(
                key: key3,
                child: new StateMarker(child: new Container(width: 100.0))
              )
            )
          )
        ]
      )
    );

    await tester.pumpWidget(
      new Row(
        children: <Widget>[
          new StateMarker(
            key: key2,
            child: new StateMarker(child: new Container(width: 100.0))
          ),
          new StateMarker(
            key: key1,
            child: new StateMarker(
              key: key3,
              child: new StateMarker(child: new Container(width: 100.0))
            )
          ),
        ]
      )
    );
  });
}

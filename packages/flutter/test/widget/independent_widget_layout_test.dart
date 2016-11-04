// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const Size _kTestViewSize = const Size(800.0, 600.0);

class OffscreenRenderView extends RenderView {
  OffscreenRenderView() : super(configuration: new ViewConfiguration(size: _kTestViewSize));

  @override
  void compositeFrame() {
    // Don't draw to ui.window
  }
}

class OffscreenWidgetTree {
  OffscreenWidgetTree() {
    renderView.attach(pipelineOwner);
    renderView.scheduleInitialFrame();
  }

  final RenderView renderView = new OffscreenRenderView();
  final BuildOwner buildOwner = new BuildOwner();
  final PipelineOwner pipelineOwner = new PipelineOwner();
  RenderObjectToWidgetElement<RenderBox> root;

  void pumpWidget(Widget app) {
    root = new RenderObjectToWidgetAdapter<RenderBox>(
      container: renderView,
      debugShortDescription: '[root]',
      child: app
    ).attachToRenderTree(buildOwner, root);
    pumpFrame();
  }

  void pumpFrame() {
    buildOwner.buildScope(root);
    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();
    renderView.compositeFrame();
    pipelineOwner.flushSemantics();
    buildOwner.finalizeTree();
  }

}

class Counter {
  int count = 0;
}

class Trigger {
  VoidCallback callback;
  void fire() {
    if (callback != null)
      callback();
  }
}

class TriggerableWidget extends StatefulWidget {
  TriggerableWidget({ this.trigger, this.counter });
  final Trigger trigger;
  final Counter counter;
  @override
  TriggerableState createState() => new TriggerableState();
}

class TriggerableState extends State<TriggerableWidget> {
  @override
  void initState() {
    super.initState();
    config.trigger.callback = this.fire;
  }

  @override
  void didUpdateConfig(TriggerableWidget oldConfig) {
    config.trigger.callback = this.fire;
  }

  int _count = 0;
  void fire() {
    setState(() {
      _count++;
    });
  }

  @override
  Widget build(BuildContext context) {
    config.counter.count++;
    return new Text("Bang $_count!");
  }
}

void main() {
  testWidgets('no crosstalk between widget build owners', (WidgetTester tester) async {
    Trigger trigger1 = new Trigger();
    Counter counter1 = new Counter();
    Trigger trigger2 = new Trigger();
    Counter counter2 = new Counter();
    OffscreenWidgetTree tree = new OffscreenWidgetTree();
    // Both counts should start at zero
    expect(counter1.count, equals(0));
    expect(counter2.count, equals(0));
    // Lay out the "onscreen" in the default test binding
    await tester.pumpWidget(new TriggerableWidget(trigger: trigger1, counter: counter1));
    // Only the "onscreen" widget should have built
    expect(counter1.count, equals(1));
    expect(counter2.count, equals(0));
    // Lay out the "offscreen" in a separate tree
    tree.pumpWidget(new TriggerableWidget(trigger: trigger2, counter: counter2));
    // Now both widgets should have built
    expect(counter1.count, equals(1));
    expect(counter2.count, equals(1));
    // Mark both as needing layout
    trigger1.fire();
    trigger2.fire();
    // Marking as needing layout shouldn't immediately build anything
    expect(counter1.count, equals(1));
    expect(counter2.count, equals(1));
    // Pump the "onscreen" layout
    await tester.pump();
    // Only the "onscreen" widget should have rebuilt
    expect(counter1.count, equals(2));
    expect(counter2.count, equals(1));
    // Pump the "offscreen" layout
    tree.pumpFrame();
    // Now both widgets should have rebuilt
    expect(counter1.count, equals(2));
    expect(counter2.count, equals(2));
    // Mark both as needing layout, again
    trigger1.fire();
    trigger2.fire();
    // Now pump the "offscreen" layout first
    tree.pumpFrame();
    // Only the "offscreen" widget should have rebuilt
    expect(counter1.count, equals(2));
    expect(counter2.count, equals(3));
    // Pump the "onscreen" layout
    await tester.pump();
    // Now both widgets should have rebuilt
    expect(counter1.count, equals(3));
    expect(counter2.count, equals(3));
  });
}

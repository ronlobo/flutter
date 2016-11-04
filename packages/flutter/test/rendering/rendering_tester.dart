// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

enum EnginePhase {
  layout,
  compositingBits,
  paint,
  composite,
  flushSemantics
}

class TestRenderingFlutterBinding extends BindingBase with SchedulerBinding, ServicesBinding, RendererBinding, GestureBinding {
  EnginePhase phase = EnginePhase.composite;

  @override
  void beginFrame() {
    pipelineOwner.flushLayout();
    if (phase == EnginePhase.layout)
      return;
    pipelineOwner.flushCompositingBits();
    if (phase == EnginePhase.compositingBits)
      return;
    pipelineOwner.flushPaint();
    if (phase == EnginePhase.paint)
      return;
    renderView.compositeFrame();
    if (phase == EnginePhase.composite)
      return;
    pipelineOwner.flushSemantics();
    assert(phase == EnginePhase.flushSemantics);
  }
}

TestRenderingFlutterBinding _renderer;
TestRenderingFlutterBinding get renderer {
  _renderer ??= new TestRenderingFlutterBinding();
  return _renderer;
}

/// Place the box in the render tree, at the given size and with the given
/// alignment on the screen.
void layout(RenderBox box, {
  BoxConstraints constraints,
  FractionalOffset alignment: FractionalOffset.center,
  EnginePhase phase: EnginePhase.layout
}) {
  assert(box != null); // If you want to just repump the last box, call pumpFrame().
  assert(box.parent == null); // We stick the box in another, so you can't reuse it easily, sorry.

  renderer.renderView.child = null;
  if (constraints != null) {
    box = new RenderPositionedBox(
      alignment: alignment,
      child: new RenderConstrainedBox(
        additionalConstraints: constraints,
        child: box
      )
    );
  }
  renderer.renderView.child = box;

  pumpFrame(phase: phase);
}

void pumpFrame({ EnginePhase phase: EnginePhase.layout }) {
  assert(renderer != null);
  renderer.phase = phase;
  renderer.beginFrame();
}

class TestCallbackPainter extends CustomPainter {
  const TestCallbackPainter({ this.onPaint });

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
  }

  @override
  bool shouldRepaint(TestCallbackPainter oldPainter) => true;
}


class RenderSizedBox extends RenderBox {
  RenderSizedBox(this._size);

  final Size _size;

  @override
  double computeMinIntrinsicWidth(double height) {
    return _size.width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _size.width;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return _size.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _size.height;
  }

  @override
  bool get sizedByParent => true;

  @override
  void performResize() {
    size = constraints.constrain(_size);
  }

  @override
  void performLayout() { }
}

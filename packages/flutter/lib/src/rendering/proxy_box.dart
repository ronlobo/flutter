// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui show ImageFilter, Gradient;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'package:vector_math/vector_math_64.dart';

import 'box.dart';
import 'layer.dart';
import 'object.dart';

export 'package:flutter/gestures.dart' show
  PointerEvent,
  PointerDownEvent,
  PointerMoveEvent,
  PointerUpEvent,
  PointerCancelEvent;

/// A base class for render objects that resemble their children.
///
/// A proxy box has a single child and simply mimics all the properties of that
/// child by calling through to the child for each function in the render box
/// protocol. For example, a proxy box determines its size by asking its child
/// to layout with the same constraints and then matching the size.
///
/// A proxy box isn't useful on its own because you might as well just replace
/// the proxy box with its child. However, RenderProxyBox is a useful base class
/// for render objects that wish to mimic most, but not all, of the properties
/// of their child.
class RenderProxyBox extends RenderBox with RenderObjectWithChildMixin<RenderBox>, RenderProxyBoxMixin {
  /// Creates a proxy render box.
  ///
  /// Proxy render boxes are rarely created directly because they simply proxy
  /// the render box protocol to [child]. Instead, consider using one of the
  /// subclasses.
  // TODO(a14n): Remove ignore once https://github.com/dart-lang/sdk/issues/30328 is fixed
  RenderProxyBox([RenderBox child = null]) { //ignore: avoid_init_to_null
    this.child = child;
  }
}

/// Implementation of [RenderProxyBox].
///
/// This class can be used as a mixin for situations where the proxying behavior
/// of [RenderProxyBox] is desired but inheriting from [RenderProxyBox] is
/// impractical (e.g. because you want to mix in other classes as well).
// TODO(ianh): Remove this class once https://github.com/dart-lang/sdk/issues/15101 is fixed
abstract class RenderProxyBoxMixin extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  // This class is intended to be used as a mixin, and should not be
  // extended directly.
  factory RenderProxyBoxMixin._() => null;

  @override
  void setupParentData(RenderObject child) {
    // We don't actually use the offset argument in BoxParentData, so let's
    // avoid allocating it at all.
    if (child.parentData is! ParentData)
      child.parentData = new ParentData();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (child != null)
      return child.getMinIntrinsicWidth(height);
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (child != null)
      return child.getMaxIntrinsicWidth(height);
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (child != null)
      return child.getMinIntrinsicHeight(width);
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (child != null)
      return child.getMaxIntrinsicHeight(width);
    return 0.0;
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    if (child != null)
      return child.getDistanceToActualBaseline(baseline);
    return super.computeDistanceToActualBaseline(baseline);
  }

  @override
  void performLayout() {
    if (child != null) {
      child.layout(constraints, parentUsesSize: true);
      size = child.size;
    } else {
      performResize();
    }
  }

  @override
  bool hitTestChildren(HitTestResult result, { Offset position }) {
    return child?.hitTest(result, position: position) ?? false;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) { }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null)
      context.paintChild(child, offset);
  }
}

/// How to behave during hit tests.
enum HitTestBehavior {
  /// Targets that defer to their children receive events within their bounds
  /// only if one of their children is hit by the hit test.
  deferToChild,

  /// Opaque targets can be hit by hit tests, causing them to both receive
  /// events within their bounds and prevent targets visually behind them from
  /// also receiving events.
  opaque,

  /// Translucent targets both receive events within their bounds and permit
  /// targets visually behind them to also receive events.
  translucent,
}

/// A RenderProxyBox subclass that allows you to customize the
/// hit-testing behavior.
abstract class RenderProxyBoxWithHitTestBehavior extends RenderProxyBox {
  /// Initializes member variables for subclasses.
  ///
  /// By default, the [behavior] is [HitTestBehavior.deferToChild].
  RenderProxyBoxWithHitTestBehavior({
    this.behavior: HitTestBehavior.deferToChild,
    RenderBox child
  }) : super(child);

  /// How to behave during hit testing.
  HitTestBehavior behavior;

  @override
  bool hitTest(HitTestResult result, { Offset position }) {
    bool hitTarget = false;
    if (size.contains(position)) {
      hitTarget = hitTestChildren(result, position: position) || hitTestSelf(position);
      if (hitTarget || behavior == HitTestBehavior.translucent)
        result.add(new BoxHitTestEntry(this, position));
    }
    return hitTarget;
  }

  @override
  bool hitTestSelf(Offset position) => behavior == HitTestBehavior.opaque;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new EnumProperty<HitTestBehavior>('behavior', behavior, defaultValue: null));
  }
}

/// Imposes additional constraints on its child.
///
/// A render constrained box proxies most functions in the render box protocol
/// to its child, except that when laying out its child, it tightens the
/// constraints provided by its parent by enforcing the [additionalConstraints]
/// as well.
///
/// For example, if you wanted [child] to have a minimum height of 50.0 logical
/// pixels, you could use `const BoxConstraints(minHeight: 50.0)` as the
/// [additionalConstraints].
class RenderConstrainedBox extends RenderProxyBox {
  /// Creates a render box that constrains its child.
  ///
  /// The [additionalConstraints] argument must not be null and must be valid.
  RenderConstrainedBox({
    RenderBox child,
    @required BoxConstraints additionalConstraints,
  }) : assert(additionalConstraints != null),
       assert(additionalConstraints.debugAssertIsValid()),
       _additionalConstraints = additionalConstraints,
       super(child);

  /// Additional constraints to apply to [child] during layout
  BoxConstraints get additionalConstraints => _additionalConstraints;
  BoxConstraints _additionalConstraints;
  set additionalConstraints(BoxConstraints value) {
    assert(value != null);
    assert(value.debugAssertIsValid());
    if (_additionalConstraints == value)
      return;
    _additionalConstraints = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (_additionalConstraints.hasBoundedWidth && _additionalConstraints.hasTightWidth)
      return _additionalConstraints.minWidth;
    final double width = super.computeMinIntrinsicWidth(height);
    if (_additionalConstraints.hasBoundedWidth)
      return _additionalConstraints.constrainWidth(width);
    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (_additionalConstraints.hasBoundedWidth && _additionalConstraints.hasTightWidth)
      return _additionalConstraints.minWidth;
    final double width = super.computeMaxIntrinsicWidth(height);
    if (_additionalConstraints.hasBoundedWidth)
      return _additionalConstraints.constrainWidth(width);
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (_additionalConstraints.hasBoundedHeight && _additionalConstraints.hasTightHeight)
      return _additionalConstraints.minHeight;
    final double height = super.computeMinIntrinsicHeight(width);
    if (_additionalConstraints.hasBoundedHeight)
      return _additionalConstraints.constrainHeight(height);
    return height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (_additionalConstraints.hasBoundedHeight && _additionalConstraints.hasTightHeight)
      return _additionalConstraints.minHeight;
    final double height = super.computeMaxIntrinsicHeight(width);
    if (_additionalConstraints.hasBoundedHeight)
      return _additionalConstraints.constrainHeight(height);
    return height;
  }

  @override
  void performLayout() {
    if (child != null) {
      child.layout(_additionalConstraints.enforce(constraints), parentUsesSize: true);
      size = child.size;
    } else {
      size = _additionalConstraints.enforce(constraints).constrain(Size.zero);
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    super.debugPaintSize(context, offset);
    assert(() {
      Paint paint;
      if (child == null || child.size.isEmpty) {
        paint = new Paint()
          ..color = const Color(0x90909090);
        context.canvas.drawRect(offset & size, paint);
      }
      return true;
    }());
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new DiagnosticsProperty<BoxConstraints>('additionalConstraints', additionalConstraints));
  }
}

/// Constrains the child's [BoxConstraints.maxWidth] and
/// [BoxConstraints.maxHeight] if they're otherwise unconstrained.
///
/// This has the effect of giving the child a natural dimension in unbounded
/// environments. For example, by providing a [maxHeight] to a widget that
/// normally tries to be as big as possible, the widget will normally size
/// itself to fit its parent, but when placed in a vertical list, it will take
/// on the given height.
///
/// This is useful when composing widgets that normally try to match their
/// parents' size, so that they behave reasonably in lists (which are
/// unbounded).
class RenderLimitedBox extends RenderProxyBox {
  /// Creates a render box that imposes a maximum width or maximum height on its
  /// child if the child is otherwise unconstrained.
  ///
  /// The [maxWidth] and [maxHeight] arguments not be null and must be
  /// non-negative.
  RenderLimitedBox({
    RenderBox child,
    double maxWidth: double.INFINITY,
    double maxHeight: double.INFINITY
  }) : assert(maxWidth != null && maxWidth >= 0.0),
       assert(maxHeight != null && maxHeight >= 0.0),
       _maxWidth = maxWidth,
       _maxHeight = maxHeight,
       super(child);

  /// The value to use for maxWidth if the incoming maxWidth constraint is infinite.
  double get maxWidth => _maxWidth;
  double _maxWidth;
  set maxWidth(double value) {
    assert(value != null && value >= 0.0);
    if (_maxWidth == value)
      return;
    _maxWidth = value;
    markNeedsLayout();
  }

  /// The value to use for maxHeight if the incoming maxHeight constraint is infinite.
  double get maxHeight => _maxHeight;
  double _maxHeight;
  set maxHeight(double value) {
    assert(value != null && value >= 0.0);
    if (_maxHeight == value)
      return;
    _maxHeight = value;
    markNeedsLayout();
  }

  BoxConstraints _limitConstraints(BoxConstraints constraints) {
    return new BoxConstraints(
      minWidth: constraints.minWidth,
      maxWidth: constraints.hasBoundedWidth ? constraints.maxWidth : constraints.constrainWidth(maxWidth),
      minHeight: constraints.minHeight,
      maxHeight: constraints.hasBoundedHeight ? constraints.maxHeight : constraints.constrainHeight(maxHeight)
    );
  }

  @override
  void performLayout() {
    if (child != null) {
      child.layout(_limitConstraints(constraints), parentUsesSize: true);
      size = constraints.constrain(child.size);
    } else {
      size = _limitConstraints(constraints).constrain(Size.zero);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new DoubleProperty('maxWidth', maxWidth, defaultValue: double.INFINITY));
    description.add(new DoubleProperty('maxHeight', maxHeight, defaultValue: double.INFINITY));
  }
}

/// Attempts to size the child to a specific aspect ratio.
///
/// The render object first tries the largest width permitted by the layout
/// constraints. The height of the render object is determined by applying the
/// given aspect ratio to the width, expressed as a ratio of width to height.
///
/// For example, a 16:9 width:height aspect ratio would have a value of
/// 16.0/9.0. If the maximum width is infinite, the initial width is determined
/// by applying the aspect ratio to the maximum height.
///
/// Now consider a second example, this time with an aspect ratio of 2.0 and
/// layout constraints that require the width to be between 0.0 and 100.0 and
/// the height to be between 0.0 and 100.0. We'll select a width of 100.0 (the
/// biggest allowed) and a height of 50.0 (to match the aspect ratio).
///
/// In that same situation, if the aspect ratio is 0.5, we'll also select a
/// width of 100.0 (still the biggest allowed) and we'll attempt to use a height
/// of 200.0. Unfortunately, that violates the constraints because the child can
/// be at most 100.0 pixels tall. The render object will then take that value
/// and apply the aspect ratio again to obtain a width of 50.0. That width is
/// permitted by the constraints and the child receives a width of 50.0 and a
/// height of 100.0. If the width were not permitted, the render object would
/// continue iterating through the constraints. If the render object does not
/// find a feasible size after consulting each constraint, the render object
/// will eventually select a size for the child that meets the layout
/// constraints but fails to meet the aspect ratio constraints.
class RenderAspectRatio extends RenderProxyBox {
  /// Creates as render object with a specific aspect ratio.
  ///
  /// The [aspectRatio] argument must be a finite, positive value.
  RenderAspectRatio({
    RenderBox child,
    @required double aspectRatio,
  }) : assert(aspectRatio != null),
       assert(aspectRatio > 0.0),
       assert(aspectRatio.isFinite),
       _aspectRatio = aspectRatio,
       super(child);

  /// The aspect ratio to attempt to use.
  ///
  /// The aspect ratio is expressed as a ratio of width to height. For example,
  /// a 16:9 width:height aspect ratio would have a value of 16.0/9.0.
  double get aspectRatio => _aspectRatio;
  double _aspectRatio;
  set aspectRatio(double value) {
    assert(value != null);
    assert(value > 0.0);
    assert(value.isFinite);
    if (_aspectRatio == value)
      return;
    _aspectRatio = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (height.isFinite)
      return height * _aspectRatio;
    if (child != null)
      return child.getMinIntrinsicWidth(height);
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (height.isFinite)
      return height * _aspectRatio;
    if (child != null)
      return child.getMaxIntrinsicWidth(height);
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (width.isFinite)
      return width / _aspectRatio;
    if (child != null)
      return child.getMinIntrinsicHeight(width);
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (width.isFinite)
      return width / _aspectRatio;
    if (child != null)
      return child.getMaxIntrinsicHeight(width);
    return 0.0;
  }

  Size _applyAspectRatio(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    assert(() {
      if (!constraints.hasBoundedWidth && !constraints.hasBoundedHeight) {
        throw new FlutterError(
          '$runtimeType has unbounded constraints.\n'
          'This $runtimeType was given an aspect ratio of $aspectRatio but was given '
          'both unbounded width and unbounded height constraints. Because both '
          'constraints were unbounded, this render object doesn\'t know how much '
          'size to consume.'
        );
      }
      return true;
    }());

    if (constraints.isTight)
      return constraints.smallest;

    double width = constraints.maxWidth;
    double height;

    // We default to picking the height based on the width, but if the width
    // would be infinite, that's not sensible so we try to infer the height
    // from the width.
    if (width.isFinite) {
      height = width / _aspectRatio;
    } else {
      height = constraints.maxHeight;
      width = height * _aspectRatio;
    }

    // Similar to RenderImage, we iteratively attempt to fit within the given
    // constraints while maintaining the given aspect ratio. The order of
    // applying the constraints is also biased towards inferring the height
    // from the width.

    if (width > constraints.maxWidth) {
      width = constraints.maxWidth;
      height = width / _aspectRatio;
    }

    if (height > constraints.maxHeight) {
      height = constraints.maxHeight;
      width = height * _aspectRatio;
    }

    if (width < constraints.minWidth) {
      width = constraints.minWidth;
      height = width / _aspectRatio;
    }

    if (height < constraints.minHeight) {
      height = constraints.minHeight;
      width = height * _aspectRatio;
    }

    return constraints.constrain(new Size(width, height));
  }

  @override
  void performLayout() {
    size = _applyAspectRatio(constraints);
    if (child != null)
      child.layout(new BoxConstraints.tight(size));
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new DoubleProperty('aspectRatio', aspectRatio));
  }
}

/// Sizes its child to the child's intrinsic width.
///
/// Sizes its child's width to the child's maximum intrinsic width. If
/// [stepWidth] is non-null, the child's width will be snapped to a multiple of
/// the [stepWidth]. Similarly, if [stepHeight] is non-null, the child's height
/// will be snapped to a multiple of the [stepHeight].
///
/// This class is useful, for example, when unlimited width is available and
/// you would like a child that would otherwise attempt to expand infinitely to
/// instead size itself to a more reasonable width.
///
/// This class is relatively expensive, because it adds a speculative layout
/// pass before the final layout phase. Avoid using it where possible. In the
/// worst case, this render object can result in a layout that is O(N²) in the
/// depth of the tree.
class RenderIntrinsicWidth extends RenderProxyBox {
  /// Creates a render object that sizes itself to its child's intrinsic width.
  RenderIntrinsicWidth({
    double stepWidth,
    double stepHeight,
    RenderBox child
  }) : _stepWidth = stepWidth, _stepHeight = stepHeight, super(child);

  /// If non-null, force the child's width to be a multiple of this value.
  double get stepWidth => _stepWidth;
  double _stepWidth;
  set stepWidth(double value) {
    if (value == _stepWidth)
      return;
    _stepWidth = value;
    markNeedsLayout();
  }

  /// If non-null, force the child's height to be a multiple of this value.
  double get stepHeight => _stepHeight;
  double _stepHeight;
  set stepHeight(double value) {
    if (value == _stepHeight)
      return;
    _stepHeight = value;
    markNeedsLayout();
  }

  static double _applyStep(double input, double step) {
    assert(input.isFinite);
    if (step == null)
      return input;
    return (input / step).ceil() * step;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return computeMaxIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (child == null)
      return 0.0;
    final double width = child.getMaxIntrinsicWidth(height);
    return _applyStep(width, _stepWidth);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (child == null)
      return 0.0;
    if (!width.isFinite)
      width = computeMaxIntrinsicWidth(double.INFINITY);
    assert(width.isFinite);
    final double height = child.getMinIntrinsicHeight(width);
    return _applyStep(height, _stepHeight);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (child == null)
      return 0.0;
    if (!width.isFinite)
      width = computeMaxIntrinsicWidth(double.INFINITY);
    assert(width.isFinite);
    final double height = child.getMaxIntrinsicHeight(width);
    return _applyStep(height, _stepHeight);
  }

  @override
  void performLayout() {
    if (child != null) {
      BoxConstraints childConstraints = constraints;
      if (!childConstraints.hasTightWidth) {
        final double width = child.getMaxIntrinsicWidth(childConstraints.maxHeight);
        assert(width.isFinite);
        childConstraints = childConstraints.tighten(width: _applyStep(width, _stepWidth));
      }
      if (_stepHeight != null) {
        final double height = child.getMaxIntrinsicHeight(childConstraints.maxWidth);
        assert(height.isFinite);
        childConstraints = childConstraints.tighten(height: _applyStep(height, _stepHeight));
      }
      child.layout(childConstraints, parentUsesSize: true);
      size = child.size;
    } else {
      performResize();
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new DoubleProperty('stepWidth', stepWidth));
    description.add(new DoubleProperty('stepHeight', stepHeight));
  }
}

/// Sizes its child to the child's intrinsic height.
///
/// This class is useful, for example, when unlimited height is available and
/// you would like a child that would otherwise attempt to expand infinitely to
/// instead size itself to a more reasonable height.
///
/// This class is relatively expensive, because it adds a speculative layout
/// pass before the final layout phase. Avoid using it where possible. In the
/// worst case, this render object can result in a layout that is O(N²) in the
/// depth of the tree.
class RenderIntrinsicHeight extends RenderProxyBox {
  /// Creates a render object that sizes itself to its child's intrinsic height.
  RenderIntrinsicHeight({
    RenderBox child
  }) : super(child);

  @override
  double computeMinIntrinsicWidth(double height) {
    if (child == null)
      return 0.0;
    if (!height.isFinite)
      height = child.getMaxIntrinsicHeight(double.INFINITY);
    assert(height.isFinite);
    return child.getMinIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (child == null)
      return 0.0;
    if (!height.isFinite)
      height = child.getMaxIntrinsicHeight(double.INFINITY);
    assert(height.isFinite);
    return child.getMaxIntrinsicWidth(height);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return computeMaxIntrinsicHeight(width);
  }

  @override
  void performLayout() {
    if (child != null) {
      BoxConstraints childConstraints = constraints;
      if (!childConstraints.hasTightHeight) {
        final double height = child.getMaxIntrinsicHeight(childConstraints.maxWidth);
        assert(height.isFinite);
        childConstraints = childConstraints.tighten(height: height);
      }
      child.layout(childConstraints, parentUsesSize: true);
      size = child.size;
    } else {
      performResize();
    }
  }

}

int _getAlphaFromOpacity(double opacity) => (opacity * 255).round();

/// Makes its child partially transparent.
///
/// This class paints its child into an intermediate buffer and then blends the
/// child back into the scene partially transparent.
///
/// For values of opacity other than 0.0 and 1.0, this class is relatively
/// expensive because it requires painting the child into an intermediate
/// buffer. For the value 0.0, the child is simply not painted at all. For the
/// value 1.0, the child is painted immediately without an intermediate buffer.
class RenderOpacity extends RenderProxyBox {
  /// Creates a partially transparent render object.
  ///
  /// The [opacity] argument must be between 0.0 and 1.0, inclusive.
  RenderOpacity({ double opacity: 1.0, RenderBox child })
    : assert(opacity != null),
      assert(opacity >= 0.0 && opacity <= 1.0),
      _opacity = opacity,
      _alpha = _getAlphaFromOpacity(opacity),
      super(child);

  @override
  bool get alwaysNeedsCompositing => child != null && (_alpha != 0 && _alpha != 255);

  /// The fraction to scale the child's alpha value.
  ///
  /// An opacity of 1.0 is fully opaque. An opacity of 0.0 is fully transparent
  /// (i.e., invisible).
  ///
  /// The opacity must not be null.
  ///
  /// Values 1.0 and 0.0 are painted with a fast path. Other values
  /// require painting the child into an intermediate buffer, which is
  /// expensive.
  double get opacity => _opacity;
  double _opacity;
  set opacity(double value) {
    assert(value != null);
    assert(value >= 0.0 && value <= 1.0);
    if (_opacity == value)
      return;
    _opacity = value;
    _alpha = _getAlphaFromOpacity(_opacity);
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  int _alpha;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      if (_alpha == 0)
        return;
      if (_alpha == 255) {
        context.paintChild(child, offset);
        return;
      }
      assert(needsCompositing);
      context.pushOpacity(offset, _alpha, super.paint);
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (child != null && _alpha != 0)
      visitor(child);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new DoubleProperty('opacity', opacity));
  }
}

/// Signature for a function that creates a [Shader] for a given [Rect].
///
/// Used by [RenderShaderMask] and the [ShaderMask] widget.
typedef Shader ShaderCallback(Rect bounds);

/// Applies a mask generated by a [Shader] to its child.
///
/// For example, [RenderShaderMask] can be used to gradually fade out the edge
/// of a child by using a [new ui.Gradient.linear] mask.
class RenderShaderMask extends RenderProxyBox {
  /// Creates a render object that applies a mask generated by a [Shader] to its child.
  ///
  /// The [shaderCallback] and [blendMode] arguments must not be null.
  RenderShaderMask({
    RenderBox child,
    @required ShaderCallback shaderCallback,
    BlendMode blendMode: BlendMode.modulate,
  }) : assert(shaderCallback != null),
       assert(blendMode != null),
       _shaderCallback = shaderCallback,
       _blendMode = blendMode,
       super(child);

  /// Called to creates the [Shader] that generates the mask.
  ///
  /// The shader callback is called with the current size of the child so that
  /// it can customize the shader to the size and location of the child.
  // TODO(abarth): Use the delegate pattern here to avoid generating spurious
  // repaints when the ShaderCallback changes identity.
  ShaderCallback get shaderCallback => _shaderCallback;
  ShaderCallback _shaderCallback;
  set shaderCallback(ShaderCallback value) {
    assert(value != null);
    if (_shaderCallback == value)
      return;
    _shaderCallback = value;
    markNeedsPaint();
  }

  /// The [BlendMode] to use when applying the shader to the child.
  ///
  /// The default, [BlendMode.modulate], is useful for applying an alpha blend
  /// to the child. Other blend modes can be used to create other effects.
  BlendMode get blendMode => _blendMode;
  BlendMode _blendMode;
  set blendMode(BlendMode value) {
    assert(value != null);
    if (_blendMode == value)
      return;
    _blendMode = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      assert(needsCompositing);
      context.pushLayer(
        new ShaderMaskLayer(
          shader: _shaderCallback(offset & size),
          maskRect: offset & size,
          blendMode: _blendMode,
        ),
        super.paint,
        offset,
      );
    }
  }
}

/// Applies a filter to the existing painted content and then paints [child].
///
/// This effect is relatively expensive, especially if the filter is non-local,
/// such as a blur.
class RenderBackdropFilter extends RenderProxyBox {
  /// Creates a backdrop filter.
  ///
  /// The [filter] argument must not be null.
  RenderBackdropFilter({ RenderBox child, @required ui.ImageFilter filter })
    : assert(filter != null),
      _filter = filter,
      super(child);

  /// The image filter to apply to the existing painted content before painting
  /// the child.
  ///
  /// For example, consider using [new ui.ImageFilter.blur] to create a backdrop
  /// blur effect.
  ui.ImageFilter get filter => _filter;
  ui.ImageFilter _filter;
  set filter(ui.ImageFilter value) {
    assert(value != null);
    if (_filter == value)
      return;
    _filter = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      assert(needsCompositing);
      context.pushLayer(new BackdropFilterLayer(filter: _filter), super.paint, offset);
    }
  }
}

/// An interface for providing custom clips.
///
/// This class is used by a number of clip widgets (e.g., [ClipRect] and
/// [ClipPath]).
///
/// The [getClip] method is called whenever the custom clip needs to be updated.
///
/// The [shouldReclip] method is called when a new instance of the class
/// is provided, to check if the new instance actually represents different
/// information.
///
/// The most efficient way to update the clip provided by this class is to
/// supply a reclip argument to the constructor of the [CustomClipper]. The
/// custom object will listen to this animation and update the clip whenever the
/// animation ticks, avoiding both the build and layout phases of the pipeline.
///
/// See also:
///
///  * [ClipRect], which can be customized with a [CustomClipper].
///  * [ClipRRect], which can be customized with a [CustomClipper].
///  * [ClipOval], which can be customized with a [CustomClipper].
///  * [ClipPath], which can be customized with a [CustomClipper].
abstract class CustomClipper<T> {
  /// Creates a custom clipper.
  ///
  /// The clipper will update its clip whenever [reclip] notifies its listeners.
  const CustomClipper({ Listenable reclip }) : _reclip = reclip;

  final Listenable _reclip;

  /// Returns a description of the clip given that the render object being
  /// clipped is of the given size.
  T getClip(Size size);

  /// Returns an approximation of the clip returned by [getClip], as
  /// an axis-aligned Rect. This is used by the semantics layer to
  /// determine whether widgets should be excluded.
  ///
  /// By default, this returns a rectangle that is the same size as
  /// the RenderObject. If getClip returns a shape that is roughly the
  /// same size as the RenderObject (e.g. it's a rounded rectangle
  /// with very small arcs in the corners), then this may be adequate.
  Rect getApproximateClipRect(Size size) => Offset.zero & size;

  /// Called whenever a new instance of the custom clipper delegate class is
  /// provided to the clip object, or any time that a new clip object is created
  /// with a new instance of the custom painter delegate class (which amounts to
  /// the same thing, because the latter is implemented in terms of the former).
  ///
  /// If the new instance represents different information than the old
  /// instance, then the method should return true, otherwise it should return
  /// false.
  ///
  /// If the method returns false, then the [getClip] call might be optimized
  /// away.
  ///
  /// It's possible that the [getClip] method will get called even if
  /// [shouldReclip] returns false or if the [shouldReclip] method is never
  /// called at all (e.g. if the box changes size).
  bool shouldReclip(covariant CustomClipper<T> oldClipper);

  @override
  String toString() => '$runtimeType';
}

abstract class _RenderCustomClip<T> extends RenderProxyBox {
  _RenderCustomClip({
    RenderBox child,
    CustomClipper<T> clipper
  }) : _clipper = clipper, super(child);

  /// If non-null, determines which clip to use on the child.
  CustomClipper<T> get clipper => _clipper;
  CustomClipper<T> _clipper;
  set clipper(CustomClipper<T> newClipper) {
    if (_clipper == newClipper)
      return;
    final CustomClipper<T> oldClipper = _clipper;
    _clipper = newClipper;
    assert(newClipper != null || oldClipper != null);
    if (newClipper == null || oldClipper == null ||
        oldClipper.runtimeType != oldClipper.runtimeType ||
        newClipper.shouldReclip(oldClipper)) {
      _markNeedsClip();
    }
    if (attached) {
      oldClipper?._reclip?.removeListener(_markNeedsClip);
      newClipper?._reclip?.addListener(_markNeedsClip);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _clipper?._reclip?.addListener(_markNeedsClip);
 }

  @override
  void detach() {
    _clipper?._reclip?.removeListener(_markNeedsClip);
    super.detach();
  }

  void _markNeedsClip() {
    _clip = null;
    markNeedsPaint();
    markNeedsSemanticsUpdate(onlyLocalUpdates: true);
  }

  T get _defaultClip;
  T _clip;

  @override
  void performLayout() {
    final Size oldSize = hasSize ? size : null;
    super.performLayout();
    if (oldSize != size)
      _clip = null;
  }

  void _updateClip() {
    _clip ??= _clipper?.getClip(size) ?? _defaultClip;
  }

  @override
  Rect describeApproximatePaintClip(RenderObject child) {
    return _clipper?.getApproximateClipRect(size) ?? Offset.zero & size;
  }

  Paint _debugPaint;
  TextPainter _debugText;
  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      _debugPaint ??= new Paint()
        ..shader = new ui.Gradient.linear(
          const Offset(0.0, 0.0),
          const Offset(10.0, 10.0),
          <Color>[const Color(0x00000000), const Color(0xFFFF00FF), const Color(0xFFFF00FF), const Color(0x00000000)],
          <double>[0.25, 0.25, 0.75, 0.75],
          TileMode.repeated,
        )
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      _debugText ??= new TextPainter(
        text: const TextSpan(
          text: '✂',
          style: const TextStyle(
            color: const Color(0xFFFF00FF),
              fontSize: 14.0,
            ),
          ),
          textDirection: TextDirection.rtl, // doesn't matter, it's one character
        )
        ..layout();
      return true;
    }());
  }
}

/// Clips its child using a rectangle.
///
/// By default, [RenderClipRect] prevents its child from painting outside its
/// bounds, but the size and location of the clip rect can be customized using a
/// custom [clipper].
class RenderClipRect extends _RenderCustomClip<Rect> {
  /// Creates a rectangular clip.
  ///
  /// If [clipper] is null, the clip will match the layout size and position of
  /// the child.
  RenderClipRect({
    RenderBox child,
    CustomClipper<Rect> clipper
  }) : super(child: child, clipper: clipper);

  @override
  Rect get _defaultClip => Offset.zero & size;

  @override
  bool hitTest(HitTestResult result, { Offset position }) {
    if (_clipper != null) {
      _updateClip();
      assert(_clip != null);
      if (!_clip.contains(position))
        return false;
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      _updateClip();
      context.pushClipRect(needsCompositing, offset, _clip, super.paint);
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      if (child != null) {
        super.debugPaintSize(context, offset);
        context.canvas.drawRect(_clip.shift(offset), _debugPaint);
        _debugText.paint(context.canvas, offset + new Offset(_clip.width / 8.0, -_debugText.text.style.fontSize * 1.1));
      }
      return true;
    }());
  }
}

/// Clips its child using a rounded rectangle.
///
/// By default, [RenderClipRRect] uses its own bounds as the base rectangle for
/// the clip, but the size and location of the clip can be customized using a
/// custom [clipper].
class RenderClipRRect extends _RenderCustomClip<RRect> {
  /// Creates a rounded-rectangular clip.
  ///
  /// The [borderRadius] defaults to [BorderRadius.zero], i.e. a rectangle with
  /// right-angled corners.
  ///
  /// If [clipper] is non-null, then [borderRadius] is ignored.
  RenderClipRRect({
    RenderBox child,
    BorderRadius borderRadius: BorderRadius.zero,
    CustomClipper<RRect> clipper,
  }) : _borderRadius = borderRadius, super(child: child, clipper: clipper) {
    assert(_borderRadius != null || clipper != null);
  }

  /// The border radius of the rounded corners.
  ///
  /// Values are clamped so that horizontal and vertical radii sums do not
  /// exceed width/height.
  ///
  /// This value is ignored if [clipper] is non-null.
  BorderRadius get borderRadius => _borderRadius;
  BorderRadius _borderRadius;
  set borderRadius(BorderRadius value) {
    assert(value != null);
    if (_borderRadius == value)
      return;
    _borderRadius = value;
    _markNeedsClip();
  }

  @override
  RRect get _defaultClip => _borderRadius.toRRect(Offset.zero & size);

  @override
  bool hitTest(HitTestResult result, { Offset position }) {
    if (_clipper != null) {
      _updateClip();
      assert(_clip != null);
      if (!_clip.contains(position))
        return false;
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      _updateClip();
      context.pushClipRRect(needsCompositing, offset, _clip.outerRect, _clip, super.paint);
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      if (child != null) {
        super.debugPaintSize(context, offset);
        context.canvas.drawRRect(_clip.shift(offset), _debugPaint);
        _debugText.paint(context.canvas, offset + new Offset(_clip.tlRadiusX, -_debugText.text.style.fontSize * 1.1));
      }
      return true;
    }());
  }
}

/// Clips its child using an oval.
///
/// By default, inscribes an axis-aligned oval into its layout dimensions and
/// prevents its child from painting outside that oval, but the size and
/// location of the clip oval can be customized using a custom [clipper].
class RenderClipOval extends _RenderCustomClip<Rect> {
  /// Creates an oval-shaped clip.
  ///
  /// If [clipper] is null, the oval will be inscribed into the layout size and
  /// position of the child.
  RenderClipOval({
    RenderBox child,
    CustomClipper<Rect> clipper
  }) : super(child: child, clipper: clipper);

  Rect _cachedRect;
  Path _cachedPath;

  Path _getClipPath(Rect rect) {
    if (rect != _cachedRect) {
      _cachedRect = rect;
      _cachedPath = new Path()..addOval(_cachedRect);
    }
    return _cachedPath;
  }

  @override
  Rect get _defaultClip => Offset.zero & size;

  @override
  bool hitTest(HitTestResult result, { Offset position }) {
    _updateClip();
    assert(_clip != null);
    final Offset center = _clip.center;
    // convert the position to an offset from the center of the unit circle
    final Offset offset = new Offset((position.dx - center.dx) / _clip.width,
                                     (position.dy - center.dy) / _clip.height);
    // check if the point is outside the unit circle
    if (offset.distanceSquared > 0.25) // x^2 + y^2 > r^2
      return false;
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      _updateClip();
      context.pushClipPath(needsCompositing, offset, _clip, _getClipPath(_clip), super.paint);
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      if (child != null) {
        super.debugPaintSize(context, offset);
        context.canvas.drawPath(_getClipPath(_clip).shift(offset), _debugPaint);
        _debugText.paint(context.canvas, offset + new Offset((_clip.width - _debugText.width) / 2.0, -_debugText.text.style.fontSize * 1.1));
      }
      return true;
    }());
  }
}

/// Clips its child using a path.
///
/// Takes a delegate whose primary method returns a path that should
/// be used to prevent the child from painting outside the path.
///
/// Clipping to a path is expensive. Certain shapes have more
/// optimized render objects:
///
///  * To clip to a rectangle, consider [RenderClipRect].
///  * To clip to an oval or circle, consider [RenderClipOval].
///  * To clip to a rounded rectangle, consider [RenderClipRRect].
class RenderClipPath extends _RenderCustomClip<Path> {
  /// Creates a path clip.
  ///
  /// If [clipper] is null, the clip will be a rectangle that matches the layout
  /// size and location of the child. However, rather than use this default,
  /// consider using a [RenderClipRect], which can achieve the same effect more
  /// efficiently.
  RenderClipPath({
    RenderBox child,
    CustomClipper<Path> clipper
  }) : super(child: child, clipper: clipper);

  @override
  Path get _defaultClip => new Path()..addRect(Offset.zero & size);

  @override
  bool hitTest(HitTestResult result, { Offset position }) {
    if (_clipper != null) {
      _updateClip();
      assert(_clip != null);
      if (!_clip.contains(position))
        return false;
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      _updateClip();
      context.pushClipPath(needsCompositing, offset, Offset.zero & size, _clip, super.paint);
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      if (child != null) {
        super.debugPaintSize(context, offset);
        context.canvas.drawPath(_clip.shift(offset), _debugPaint);
        _debugText.paint(context.canvas, offset);
      }
      return true;
    }());
  }
}

/// Creates a physical model layer that clips its children to a rounded
/// rectangle.
///
/// A physical model layer casts a shadow based on its [elevation].
class RenderPhysicalModel extends _RenderCustomClip<RRect> {
  /// Creates a rounded-rectangular clip.
  ///
  /// The [color] is required.
  ///
  /// The [shape], [elevation], [color], and [shadowColor] must not be null.
  RenderPhysicalModel({
    RenderBox child,
    BoxShape shape: BoxShape.rectangle,
    BorderRadius borderRadius,
    double elevation: 0.0,
    @required Color color,
    Color shadowColor: const Color(0xFF000000),
  }) : assert(shape != null),
       assert(elevation != null),
       assert(color != null),
       assert(shadowColor != null),
       _shape = shape,
       _borderRadius = borderRadius,
       _elevation = elevation,
       _color = color,
       _shadowColor = shadowColor,
       super(child: child);

  /// The shape of the layer.
  ///
  /// Defaults to [BoxShape.rectangle]. The [borderRadius] affects the corners
  /// of the rectangle.
  BoxShape get shape => _shape;
  BoxShape _shape;
  set shape(BoxShape value) {
    assert(value != null);
    if (shape == value)
      return;
    _shape = value;
    _markNeedsClip();
  }

  /// The border radius of the rounded corners.
  ///
  /// Values are clamped so that horizontal and vertical radii sums do not
  /// exceed width/height.
  ///
  /// This property is ignored if the [shape] is not [BoxShape.rectangle].
  ///
  /// The value null is treated like [BorderRadius.zero].
  BorderRadius get borderRadius => _borderRadius;
  BorderRadius _borderRadius;
  set borderRadius(BorderRadius value) {
    if (borderRadius == value)
      return;
    _borderRadius = value;
    _markNeedsClip();
  }

  /// The z-coordinate at which to place this material.
  double get elevation => _elevation;
  double _elevation;
  set elevation(double value) {
    assert(value != null);
    if (elevation == value)
      return;
    _elevation = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  /// The shadow color.
  Color get shadowColor => _shadowColor;
  Color _shadowColor;
  set shadowColor(Color value) {
    assert(value != null);
    if (shadowColor == value)
      return;
    _shadowColor = value;
    markNeedsPaint();
  }

  /// The background color.
  Color get color => _color;
  Color _color;
  set color(Color value) {
    assert(value != null);
    if (color == value)
      return;
    _color = value;
    markNeedsPaint();
  }

  @override
  RRect get _defaultClip {
    assert(hasSize);
    assert(_shape != null);
    switch (_shape) {
      case BoxShape.rectangle:
        return (borderRadius ?? BorderRadius.zero).toRRect(Offset.zero & size);
      case BoxShape.circle:
        final Rect rect = Offset.zero & size;
        return new RRect.fromRectXY(rect, rect.width / 2, rect.height / 2);
    }
    return null;
  }

  @override
  bool hitTest(HitTestResult result, { Offset position }) {
    if (_clipper != null) {
      _updateClip();
      assert(_clip != null);
      if (!_clip.contains(position))
        return false;
    }
    return super.hitTest(result, position: position);
  }

  static final Paint _defaultPaint = new Paint();
  static final Paint _transparentPaint = new Paint()..color = const Color(0x00000000);

  // On Fuchsia, the system compositor is responsible for drawing shadows
  // for physical model layers with non-zero elevation.
  @override
  bool get alwaysNeedsCompositing => _elevation != 0.0 && defaultTargetPlatform == TargetPlatform.fuchsia;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      _updateClip();
      final RRect offsetClipRRect = _clip.shift(offset);
      final Rect offsetBounds = offsetClipRRect.outerRect;
      if (needsCompositing) {
        final PhysicalModelLayer physicalModel = new PhysicalModelLayer(
          clipRRect: offsetClipRRect,
          elevation: elevation,
          color: color,
        );
        context.pushLayer(physicalModel, super.paint, offset, childPaintBounds: offsetBounds);
      } else {
        final Canvas canvas = context.canvas;
        if (elevation != 0.0) {
          // The drawShadow call doesn't add the region of the shadow to the
          // picture's bounds, so we draw a hardcoded amount of extra space to
          // account for the maximum potential area of the shadow.
          // TODO(jsimmons): remove this when Skia does it for us.
          canvas.drawRect(
            offsetBounds.inflate(20.0),
            _transparentPaint,
          );
          canvas.drawShadow(
            new Path()..addRRect(offsetClipRRect),
            shadowColor,
            elevation,
            color.alpha != 0xFF,
          );
        }
        canvas.drawRRect(offsetClipRRect, new Paint()..color = color);
        canvas.save();
        canvas.clipRRect(offsetClipRRect);
        // We only use a new layer for non-rectangular clips, on the basis that
        // rectangular clips won't need antialiasing. This is not really
        // correct, because if we're e.g. rotated, rectangles will also be
        // aliased. Unfortunately, it's too much of a performance win to err on
        // the side of correctness here.
        // TODO(ianh): Find a better solution.
        if (!offsetClipRRect.isRect)
          canvas.saveLayer(offsetBounds, _defaultPaint);
        super.paint(context, offset);
        if (!offsetClipRRect.isRect)
          canvas.restore();
        canvas.restore();
        assert(context.canvas == canvas, 'canvas changed even though needsCompositing was false');
      }
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new DiagnosticsProperty<BoxShape>('shape', shape));
    description.add(new DiagnosticsProperty<BorderRadius>('borderRadius', borderRadius));
    description.add(new DoubleProperty('elevation', elevation));
    description.add(new DiagnosticsProperty<Color>('color', color));
  }
}

/// Where to paint a box decoration.
enum DecorationPosition {
  /// Paint the box decoration behind the children.
  background,

  /// Paint the box decoration in front of the children.
  foreground,
}

/// Paints a [Decoration] either before or after its child paints.
class RenderDecoratedBox extends RenderProxyBox {
  /// Creates a decorated box.
  ///
  /// The [decoration], [position], and [configuration] arguments must not be
  /// null. By default the decoration paints behind the child.
  ///
  /// The [ImageConfiguration] will be passed to the decoration (with the size
  /// filled in) to let it resolve images.
  RenderDecoratedBox({
    @required Decoration decoration,
    DecorationPosition position: DecorationPosition.background,
    ImageConfiguration configuration: ImageConfiguration.empty,
    RenderBox child,
  }) : assert(decoration != null),
       assert(position != null),
       assert(configuration != null),
       _decoration = decoration,
       _position = position,
       _configuration = configuration,
       super(child);

  BoxPainter _painter;

  /// What decoration to paint.
  ///
  /// Commonly a [BoxDecoration].
  Decoration get decoration => _decoration;
  Decoration _decoration;
  set decoration(Decoration value) {
    assert(value != null);
    if (value == _decoration)
      return;
    _painter?.dispose();
    _painter = null;
    _decoration = value;
    markNeedsPaint();
  }

  /// Whether to paint the box decoration behind or in front of the child.
  DecorationPosition get position => _position;
  DecorationPosition _position;
  set position(DecorationPosition value) {
    assert(value != null);
    if (value == _position)
      return;
    _position = value;
    markNeedsPaint();
  }

  /// The settings to pass to the decoration when painting, so that it can
  /// resolve images appropriately. See [ImageProvider.resolve] and
  /// [BoxPainter.paint].
  ///
  /// The [ImageConfiguration.textDirection] field is also used by
  /// direction-sensitive [Decoration]s for painting and hit-testing.
  ImageConfiguration get configuration => _configuration;
  ImageConfiguration _configuration;
  set configuration(ImageConfiguration value) {
    assert(value != null);
    if (value == _configuration)
      return;
    _configuration = value;
    markNeedsPaint();
  }

  @override
  void detach() {
    _painter?.dispose();
    _painter = null;
    super.detach();
  }

  @override
  bool hitTestSelf(Offset position) {
    return _decoration.hitTest(size, position, textDirection: configuration.textDirection);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    assert(size.width != null);
    assert(size.height != null);
    _painter ??= _decoration.createBoxPainter(markNeedsPaint);
    final ImageConfiguration filledConfiguration = configuration.copyWith(size: size);
    if (position == DecorationPosition.background) {
      int debugSaveCount;
      assert(() {
        debugSaveCount = context.canvas.getSaveCount();
        return true;
      }());
      _painter.paint(context.canvas, offset, filledConfiguration);
      assert(() {
        if (debugSaveCount != context.canvas.getSaveCount()) {
          throw new FlutterError(
            '${_decoration.runtimeType} painter had mismatching save and restore calls.\n'
            'Before painting the decoration, the canvas save count was $debugSaveCount. '
            'After painting it, the canvas save count was ${context.canvas.getSaveCount()}. '
            'Every call to save() or saveLayer() must be matched by a call to restore().\n'
            'The decoration was:\n'
            '  $decoration\n'
            'The painter was:\n'
            '  $_painter'
          );
        }
        return true;
      }());
      if (decoration.isComplex)
        context.setIsComplexHint();
    }
    super.paint(context, offset);
    if (position == DecorationPosition.foreground) {
      _painter.paint(context.canvas, offset, filledConfiguration);
      if (decoration.isComplex)
        context.setIsComplexHint();
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(_decoration.toDiagnosticsNode(name: 'decoration'));
    description.add(new DiagnosticsProperty<ImageConfiguration>('configuration', configuration));
  }
}

/// Applies a transformation before painting its child.
class RenderTransform extends RenderProxyBox {
  /// Creates a render object that transforms its child.
  ///
  /// The [transform] argument must not be null.
  RenderTransform({
    @required Matrix4 transform,
    Offset origin,
    AlignmentGeometry alignment,
    TextDirection textDirection,
    this.transformHitTests: true,
    RenderBox child
  }) : assert(transform != null),
       super(child) {
    this.transform = transform;
    this.alignment = alignment;
    this.textDirection = textDirection;
    this.origin = origin;
  }

  /// The origin of the coordinate system (relative to the upper left corder of
  /// this render object) in which to apply the matrix.
  ///
  /// Setting an origin is equivalent to conjugating the transform matrix by a
  /// translation. This property is provided just for convenience.
  Offset get origin => _origin;
  Offset _origin;
  set origin(Offset value) {
    if (_origin == value)
      return;
    _origin = value;
    markNeedsPaint();
  }

  /// The alignment of the origin, relative to the size of the box.
  ///
  /// This is equivalent to setting an origin based on the size of the box.
  /// If it is specified at the same time as an offset, both are applied.
  ///
  /// An [AlignmentDirectional.start] value is the same as an [Alignment]
  /// whose [Alignment.x] value is `-1.0` if [textDirection] is
  /// [TextDirection.ltr], and `1.0` if [textDirection] is [TextDirection.rtl].
  /// Similarly [AlignmentDirectional.end] is the same as an [Alignment]
  /// whose [Alignment.x] value is `1.0` if [textDirection] is
  /// [TextDirection.ltr], and `-1.0` if [textDirection] is [TextDirection.rtl].
  AlignmentGeometry get alignment => _alignment;
  AlignmentGeometry _alignment;
  set alignment(AlignmentGeometry value) {
    if (_alignment == value)
      return;
    _alignment = value;
    markNeedsPaint();
  }

  /// The text direction with which to resolve [alignment].
  ///
  /// This may be changed to null, but only after [alignment] has been changed
  /// to a value that does not depend on the direction.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value)
      return;
    _textDirection = value;
    markNeedsPaint();
  }

  /// When set to true, hit tests are performed based on the position of the
  /// child as it is painted. When set to false, hit tests are performed
  /// ignoring the transformation.
  ///
  /// [applyPaintTransform], and therefore [localToGlobal] and [globalToLocal],
  /// always honor the transformation, regardless of the value of this property.
  bool transformHitTests;

  // Note the lack of a getter for transform because Matrix4 is not immutable
  Matrix4 _transform;

  /// The matrix to transform the child by during painting.
  set transform(Matrix4 value) {
    assert(value != null);
    if (_transform == value)
      return;
    _transform = new Matrix4.copy(value);
    markNeedsPaint();
  }

  /// Sets the transform to the identity matrix.
  void setIdentity() {
    _transform.setIdentity();
    markNeedsPaint();
  }

  /// Concatenates a rotation about the x axis into the transform.
  void rotateX(double radians) {
    _transform.rotateX(radians);
    markNeedsPaint();
  }

  /// Concatenates a rotation about the y axis into the transform.
  void rotateY(double radians) {
    _transform.rotateY(radians);
    markNeedsPaint();
  }

  /// Concatenates a rotation about the z axis into the transform.
  void rotateZ(double radians) {
    _transform.rotateZ(radians);
    markNeedsPaint();
  }

  /// Concatenates a translation by (x, y, z) into the transform.
  void translate(double x, [double y = 0.0, double z = 0.0]) {
    _transform.translate(x, y, z);
    markNeedsPaint();
  }

  /// Concatenates a scale into the transform.
  void scale(double x, [double y, double z]) {
    _transform.scale(x, y, z);
    markNeedsPaint();
  }

  Matrix4 get _effectiveTransform {
    final Alignment resolvedAlignment = alignment?.resolve(textDirection);
    if (_origin == null && resolvedAlignment == null)
      return _transform;
    final Matrix4 result = new Matrix4.identity();
    if (_origin != null)
      result.translate(_origin.dx, _origin.dy);
    Offset translation;
    if (resolvedAlignment != null) {
      translation = resolvedAlignment.alongSize(size);
      result.translate(translation.dx, translation.dy);
    }
    result.multiply(_transform);
    if (resolvedAlignment != null)
      result.translate(-translation.dx, -translation.dy);
    if (_origin != null)
      result.translate(-_origin.dx, -_origin.dy);
    return result;
  }

  @override
  bool hitTest(HitTestResult result, { Offset position }) {
    if (transformHitTests) {
      Matrix4 inverse;
      try {
        inverse = new Matrix4.inverted(_effectiveTransform);
      } on ArgumentError {
        // We cannot invert the effective transform. That means the child
        // doesn't appear on screen and cannot be hit.
        return false;
      }
      position = MatrixUtils.transformPoint(inverse, position);
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      final Matrix4 transform = _effectiveTransform;
      final Offset childOffset = MatrixUtils.getAsTranslation(transform);
      if (childOffset == null)
        context.pushTransform(needsCompositing, offset, transform, super.paint);
      else
        super.paint(context, offset + childOffset);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_effectiveTransform);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new TransformProperty('transform matrix', _transform));
    description.add(new DiagnosticsProperty<Offset>('origin', origin));
    description.add(new DiagnosticsProperty<Alignment>('alignment', alignment));
    description.add(new EnumProperty<TextDirection>('textDirection', textDirection, defaultValue: null));
    description.add(new DiagnosticsProperty<bool>('transformHitTests', transformHitTests));
  }
}

/// Scales and positions its child within itself according to [fit].
class RenderFittedBox extends RenderProxyBox {
  /// Scales and positions its child within itself.
  ///
  /// The [fit] and [alignment] arguments must not be null.
  RenderFittedBox({
    BoxFit fit: BoxFit.contain,
    AlignmentGeometry alignment: Alignment.center,
    TextDirection textDirection,
    RenderBox child,
  }) : assert(fit != null),
       assert(alignment != null),
       _fit = fit,
       _alignment = alignment,
       _textDirection = textDirection,
       super(child);

  Alignment _resolvedAlignment;

  void _resolve() {
    if (_resolvedAlignment != null)
      return;
    _resolvedAlignment = alignment.resolve(textDirection);
  }

  void _markNeedResolution() {
    _resolvedAlignment = null;
    markNeedsPaint();
  }

  /// How to inscribe the child into the space allocated during layout.
  BoxFit get fit => _fit;
  BoxFit _fit;
  set fit(BoxFit value) {
    assert(value != null);
    if (_fit == value)
      return;
    _fit = value;
    _clearPaintData();
    markNeedsPaint();
  }

  /// How to align the child within its parent's bounds.
  ///
  /// An alignment of (0.0, 0.0) aligns the child to the top-left corner of its
  /// parent's bounds.  An alignment of (1.0, 0.5) aligns the child to the middle
  /// of the right edge of its parent's bounds.
  ///
  /// If this is set to an [AlignmentDirectional] object, then
  /// [textDirection] must not be null.
  AlignmentGeometry get alignment => _alignment;
  AlignmentGeometry _alignment;
  set alignment(AlignmentGeometry value) {
    assert(value != null);
    if (_alignment == value)
      return;
    _alignment = value;
    _clearPaintData();
    _markNeedResolution();
  }

  /// The text direction with which to resolve [alignment].
  ///
  /// This may be changed to null, but only after [alignment] has been changed
  /// to a value that does not depend on the direction.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value)
      return;
    _textDirection = value;
    _clearPaintData();
    _markNeedResolution();
  }

  // TODO(ianh): The intrinsic dimensions of this box are wrong.

  @override
  void performLayout() {
    if (child != null) {
      child.layout(const BoxConstraints(), parentUsesSize: true);
      size = constraints.constrainSizeAndAttemptToPreserveAspectRatio(child.size);
      _clearPaintData();
    } else {
      size = constraints.smallest;
    }
  }

  bool _hasVisualOverflow;
  Matrix4 _transform;

  void _clearPaintData() {
    _hasVisualOverflow = null;
    _transform = null;
  }

  void _updatePaintData() {
    if (_transform != null)
      return;

    if (child == null) {
      _hasVisualOverflow = false;
      _transform = new Matrix4.identity();
    } else {
      _resolve();
      final Size childSize = child.size;
      final FittedSizes sizes = applyBoxFit(_fit, childSize, size);
      final double scaleX = sizes.destination.width / sizes.source.width;
      final double scaleY = sizes.destination.height / sizes.source.height;
      final Rect sourceRect = _resolvedAlignment.inscribe(sizes.source, Offset.zero & childSize);
      final Rect destinationRect = _resolvedAlignment.inscribe(sizes.destination, Offset.zero & size);
      _hasVisualOverflow = sourceRect.width < childSize.width || sourceRect.height < childSize.width;
      _transform = new Matrix4.translationValues(destinationRect.left, destinationRect.top, 0.0)
        ..scale(scaleX, scaleY, 1.0)
        ..translate(-sourceRect.left, -sourceRect.top);
    }
  }

  void _paintChildWithTransform(PaintingContext context, Offset offset) {
    final Offset childOffset = MatrixUtils.getAsTranslation(_transform);
    if (childOffset == null)
      context.pushTransform(needsCompositing, offset, _transform, super.paint);
    else
      super.paint(context, offset + childOffset);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty)
      return;
    _updatePaintData();
    if (child != null) {
      if (_hasVisualOverflow)
        context.pushClipRect(needsCompositing, offset, Offset.zero & size, _paintChildWithTransform);
      else
        _paintChildWithTransform(context, offset);
    }
  }

  @override
  bool hitTest(HitTestResult result, { Offset position }) {
    if (size.isEmpty)
      return false;
    _updatePaintData();
    Matrix4 inverse;
    try {
      inverse = new Matrix4.inverted(_transform);
    } on ArgumentError {
      // We cannot invert the effective transform. That means the child
      // doesn't appear on screen and cannot be hit.
      return false;
    }
    position = MatrixUtils.transformPoint(inverse, position);
    return super.hitTest(result, position: position);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (size.isEmpty) {
      transform.setZero();
    } else {
      _updatePaintData();
      transform.multiply(_transform);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new EnumProperty<BoxFit>('fit', fit));
    description.add(new DiagnosticsProperty<Alignment>('alignment', alignment));
    description.add(new EnumProperty<TextDirection>('textDirection', textDirection, defaultValue: null));
  }
}

/// Applies a translation transformation before painting its child.
///
/// The translation is expressed as an [Offset] scaled to the child's size. For
/// example, an [Offset] with a `dx` of 0.25 will result in a horizontal
/// translation of one quarter the width of the child.
///
/// Hit tests will only be detected inside the bounds of the
/// [RenderFractionalTranslation], even if the contents are offset such that
/// they overflow.
class RenderFractionalTranslation extends RenderProxyBox {
  /// Creates a render object that translates its child's painting.
  ///
  /// The [translation] argument must not be null.
  RenderFractionalTranslation({
    @required Offset translation,
    this.transformHitTests: true,
    RenderBox child
  }) : assert(translation != null),
       _translation = translation,
       super(child);

  /// The translation to apply to the child, scaled to the child's size.
  ///
  /// For example, an [Offset] with a `dx` of 0.25 will result in a horizontal
  /// translation of one quarter the width of the child.
  Offset get translation => _translation;
  Offset _translation;
  set translation(Offset value) {
    assert(value != null);
    if (_translation == value)
      return;
    _translation = value;
    markNeedsPaint();
  }

  /// When set to true, hit tests are performed based on the position of the
  /// child as it is painted. When set to false, hit tests are performed
  /// ignoring the transformation.
  ///
  /// applyPaintTransform(), and therefore localToGlobal() and globalToLocal(),
  /// always honor the transformation, regardless of the value of this property.
  bool transformHitTests;

  @override
  bool hitTest(HitTestResult result, { Offset position }) {
    assert(!debugNeedsLayout);
    if (transformHitTests) {
      position = new Offset(
        position.dx - translation.dx * size.width,
        position.dy - translation.dy * size.height,
      );
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    assert(!debugNeedsLayout);
    if (child != null) {
      super.paint(context, new Offset(
        offset.dx + translation.dx * size.width,
        offset.dy + translation.dy * size.height,
      ));
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translate(
      translation.dx * size.width,
      translation.dy * size.height,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new DiagnosticsProperty<Offset>('translation', translation));
    description.add(new DiagnosticsProperty<bool>('transformHitTests', transformHitTests));
  }
}

/// The interface used by [CustomPaint] (in the widgets library) and
/// [RenderCustomPaint] (in the rendering library).
///
/// To implement a custom painter, either subclass or implement this interface
/// to define your custom paint delegate. [CustomPaint] subclasses must
/// implement the [paint] and [shouldRepaint] methods, and may optionally also
/// implement the [hitTest] method.
///
/// The [paint] method is called whenever the custom object needs to be repainted.
///
/// The [shouldRepaint] method is called when a new instance of the class
/// is provided, to check if the new instance actually represents different
/// information.
///
/// The most efficient way to trigger a repaint is to either extend this class
/// and supply a `repaint` argument to the constructor of the [CustomPainter],
/// where that object notifies its listeners when it is time to repaint, or to
/// extend [Listenable] (e.g. via [ChangeNotifier]) and implement
/// [CustomPainter], so that the object itself provides the notifications
/// directly. In either case, the [CustomPaint] widget or [RenderCustomPaint]
/// render object will listen to the [Listenable] and repaint whenever the
/// animation ticks, avoiding both the build and layout phases of the pipeline.
///
/// The [hitTest] method is called when the user interacts with the underlying
/// render object, to determine if the user hit the object or missed it.
///
/// ## Sample code
///
/// This sample extends the same code shown for [RadialGradient] to create a
/// custom painter that paints a sky.
///
/// ```dart
/// class Sky extends CustomPainter {
///   @override
///   void paint(Canvas canvas, Size size) {
///     var rect = Offset.zero & size;
///     var gradient = new RadialGradient(
///       center: const Alignment(0.7, -0.6),
///       radius: 0.2,
///       colors: [const Color(0xFFFFFF00), const Color(0xFF0099FF)],
///       stops: [0.4, 1.0],
///     );
///     canvas.drawRect(
///       rect,
///       new Paint()..shader = gradient.createShader(rect),
///     );
///   }
///
///   @override
///   bool shouldRepaint(Sky oldDelegate) {
///     // Since this Sky painter has no fields, it always paints
///     // the same thing, and therefore we return false here. If
///     // we had fields (set from the constructor) then we would
///     // return true if any of them differed from the same
///     // fields on the oldDelegate.
///     return false;
///   }
/// }
/// ```
///
/// See also:
///
///  * [Canvas], the class that a custom painter uses to paint.
///  * [CustomPaint], the widget that uses [CustomPainter], and whose sample
///    code shows how to use the above `Sky` class.
///  * [RadialGradient], whose sample code section shows a different take
///    on the sample code above.
abstract class CustomPainter extends Listenable {
  /// Creates a custom painter.
  ///
  /// The painter will repaint whenever `repaint` notifies its listeners.
  const CustomPainter({ Listenable repaint }) : _repaint = repaint;

  final Listenable _repaint;

  /// Register a closure to be notified when it is time to repaint.
  ///
  /// The [CustomPainter] implementation merely forwards to the same method on
  /// the [Listenable] provided to the constructor in the `repaint` argument, if
  /// it was not null.
  @override
  void addListener(VoidCallback listener) => _repaint?.addListener(listener);

  /// Remove a previously registered closure from the list of closures that the
  /// object notifies when it is time to repaint.
  ///
  /// The [CustomPainter] implementation merely forwards to the same method on
  /// the [Listenable] provided to the constructor in the `repaint` argument, if
  /// it was not null.
  @override
  void removeListener(VoidCallback listener) => _repaint?.removeListener(listener);

  /// Called whenever the object needs to paint. The given [Canvas] has its
  /// coordinate space configured such that the origin is at the top left of the
  /// box. The area of the box is the size of the [size] argument.
  ///
  /// Paint operations should remain inside the given area. Graphical operations
  /// outside the bounds may be silently ignored, clipped, or not clipped.
  ///
  /// Implementations should be wary of correctly pairing any calls to
  /// [Canvas.save]/[Canvas.saveLayer] and [Canvas.restore], otherwise all
  /// subsequent painting on this canvas may be affected, with potentially
  /// hilarious but confusing results.
  ///
  /// To paint text on a [Canvas], use a [TextPainter].
  ///
  /// To paint an image on a [Canvas]:
  ///
  /// 1. Obtain an [ImageStream], for example by calling [ImageProvider.resolve]
  ///    on an [AssetImage] or [NetworkImage] object.
  ///
  /// 2. Whenever the [ImageStream]'s underlying [ImageInfo] object changes
  ///    (see [ImageStream.addListener]), create a new instance of your custom
  ///    paint delegate, giving it the new [ImageInfo] object.
  ///
  /// 3. In your delegate's [paint] method, call the [Canvas.drawImage],
  ///    [Canvas.drawImageRect], or [Canvas.drawImageNine] methods to paint the
  ///    [ImageInfo.image] object, applying the [ImageInfo.scale] value to
  ///    obtain the correct rendering size.
  void paint(Canvas canvas, Size size);

  /// Called whenever a new instance of the custom painter delegate class is
  /// provided to the [RenderCustomPaint] object, or any time that a new
  /// [CustomPaint] object is created with a new instance of the custom painter
  /// delegate class (which amounts to the same thing, because the latter is
  /// implemented in terms of the former).
  ///
  /// If the new instance represents different information than the old
  /// instance, then the method should return true, otherwise it should return
  /// false.
  ///
  /// If the method returns false, then the [paint] call might be optimized
  /// away.
  ///
  /// It's possible that the [paint] method will get called even if
  /// [shouldRepaint] returns false (e.g. if an ancestor or descendant needed to
  /// be repainted). It's also possible that the [paint] method will get called
  /// without [shouldRepaint] being called at all (e.g. if the box changes
  /// size).
  ///
  /// If a custom delegate has a particularly expensive paint function such that
  /// repaints should be avoided as much as possible, a [RepaintBoundary] or
  /// [RenderRepaintBoundary] (or other render object with
  /// [RenderObject.isRepaintBoundary] set to true) might be helpful.
  bool shouldRepaint(covariant CustomPainter oldDelegate);

  /// Called whenever a hit test is being performed on an object that is using
  /// this custom paint delegate.
  ///
  /// The given point is relative to the same coordinate space as the last
  /// [paint] call.
  ///
  /// The default behavior is to consider all points to be hits for
  /// background painters, and no points to be hits for foreground painters.
  ///
  /// Return true if the given position corresponds to a point on the drawn
  /// image that should be considered a "hit", false if it corresponds to a
  /// point that should be considered outside the painted image, and null to use
  /// the default behavior.
  bool hitTest(Offset position) => null;

  @override
  String toString() => '${describeIdentity(this)}(${ _repaint?.toString() ?? "" })';
}

/// Provides a canvas on which to draw during the paint phase.
///
/// When asked to paint, [RenderCustomPaint] first asks its [painter] to paint
/// on the current canvas, then it paints its child, and then, after painting
/// its child, it asks its [foregroundPainter] to paint. The coordinate system of
/// the canvas matches the coordinate system of the [CustomPaint] object. The
/// painters are expected to paint within a rectangle starting at the origin and
/// encompassing a region of the given size. (If the painters paint outside
/// those bounds, there might be insufficient memory allocated to rasterize the
/// painting commands and the resulting behavior is undefined.)
///
/// Painters are implemented by subclassing or implementing [CustomPainter].
///
/// Because custom paint calls its painters during paint, you cannot mark the
/// tree as needing a new layout during the callback (the layout for this frame
/// has already happened).
///
/// Custom painters normally size themselves to their child. If they do not have
/// a child, they attempt to size themselves to the [preferredSize], which
/// defaults to [Size.zero].
///
/// See also:
///
///  * [CustomPainter], the class that custom painter delegates should extend.
///  * [Canvas], the API provided to custom painter delegates.
class RenderCustomPaint extends RenderProxyBox {
  /// Creates a render object that delegates its painting.
  RenderCustomPaint({
    CustomPainter painter,
    CustomPainter foregroundPainter,
    Size preferredSize: Size.zero,
    this.isComplex: false,
    this.willChange: false,
    RenderBox child,
  }) : assert(preferredSize != null),
       _painter = painter,
       _foregroundPainter = foregroundPainter,
       _preferredSize = preferredSize,
       super(child);

  /// The background custom paint delegate.
  ///
  /// This painter, if non-null, is called to paint behind the children.
  CustomPainter get painter => _painter;
  CustomPainter _painter;
  /// Set a new background custom paint delegate.
  ///
  /// If the new delegate is the same as the previous one, this does nothing.
  ///
  /// If the new delegate is the same class as the previous one, then the new
  /// delegate has its [CustomPainter.shouldRepaint] called; if the result is
  /// true, then the delegate will be called.
  ///
  /// If the new delegate is a different class than the previous one, then the
  /// delegate will be called.
  ///
  /// If the new value is null, then there is no background custom painter.
  set painter(CustomPainter value) {
    if (_painter == value)
      return;
    final CustomPainter oldPainter = _painter;
    _painter = value;
    _didUpdatePainter(_painter, oldPainter);
  }

  /// The foreground custom paint delegate.
  ///
  /// This painter, if non-null, is called to paint in front of the children.
  CustomPainter get foregroundPainter => _foregroundPainter;
  CustomPainter _foregroundPainter;
  /// Set a new foreground custom paint delegate.
  ///
  /// If the new delegate is the same as the previous one, this does nothing.
  ///
  /// If the new delegate is the same class as the previous one, then the new
  /// delegate has its [CustomPainter.shouldRepaint] called; if the result is
  /// true, then the delegate will be called.
  ///
  /// If the new delegate is a different class than the previous one, then the
  /// delegate will be called.
  ///
  /// If the new value is null, then there is no foreground custom painter.
  set foregroundPainter(CustomPainter value) {
    if (_foregroundPainter == value)
      return;
    final CustomPainter oldPainter = _foregroundPainter;
    _foregroundPainter = value;
    _didUpdatePainter(_foregroundPainter, oldPainter);
  }

  void _didUpdatePainter(CustomPainter newPainter, CustomPainter oldPainter) {
    if (newPainter == null) {
      assert(oldPainter != null); // We should be called only for changes.
      markNeedsPaint();
    } else if (oldPainter == null ||
        newPainter.runtimeType != oldPainter.runtimeType ||
        newPainter.shouldRepaint(oldPainter)) {
      markNeedsPaint();
    }
    if (attached) {
      oldPainter?.removeListener(markNeedsPaint);
      newPainter?.addListener(markNeedsPaint);
    }
  }

  /// The size that this [RenderCustomPaint] should aim for, given the layout
  /// constraints, if there is no child.
  ///
  /// Defaults to [Size.zero].
  ///
  /// If there's a child, this is ignored, and the size of the child is used
  /// instead.
  Size get preferredSize => _preferredSize;
  Size _preferredSize;
  set preferredSize(Size value) {
    assert(value != null);
    if (preferredSize == value)
      return;
    _preferredSize = value;
    markNeedsLayout();
  }

  /// Whether to hint that this layer's painting should be cached.
  ///
  /// The compositor contains a raster cache that holds bitmaps of layers in
  /// order to avoid the cost of repeatedly rendering those layers on each
  /// frame.  If this flag is not set, then the compositor will apply its own
  /// heuristics to decide whether the this layer is complex enough to benefit
  /// from caching.
  bool isComplex;

  /// Whether the raster cache should be told that this painting is likely
  /// to change in the next frame.
  bool willChange;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _painter?.addListener(markNeedsPaint);
    _foregroundPainter?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _painter?.removeListener(markNeedsPaint);
    _foregroundPainter?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool hitTestChildren(HitTestResult result, { Offset position }) {
    if (_foregroundPainter != null && (_foregroundPainter.hitTest(position) ?? false))
      return true;
    return super.hitTestChildren(result, position: position);
  }

  @override
  bool hitTestSelf(Offset position) {
    return _painter != null && (_painter.hitTest(position) ?? true);
  }

  @override
  void performResize() {
    size = constraints.constrain(preferredSize);
  }

  void _paintWithPainter(Canvas canvas, Offset offset, CustomPainter painter) {
    int debugPreviousCanvasSaveCount;
    canvas.save();
    assert(() { debugPreviousCanvasSaveCount = canvas.getSaveCount(); return true; }());
    if (offset != Offset.zero)
      canvas.translate(offset.dx, offset.dy);
    painter.paint(canvas, size);
    assert(() {
      // This isn't perfect. For example, we can't catch the case of
      // someone first restoring, then setting a transform or whatnot,
      // then saving.
      // If this becomes a real problem, we could add logic to the
      // Canvas class to lock the canvas at a particular save count
      // such that restore() fails if it would take the lock count
      // below that number.
      final int debugNewCanvasSaveCount = canvas.getSaveCount();
      if (debugNewCanvasSaveCount > debugPreviousCanvasSaveCount) {
        throw new FlutterError(
          'The $painter custom painter called canvas.save() or canvas.saveLayer() at least '
          '${debugNewCanvasSaveCount - debugPreviousCanvasSaveCount} more '
          'time${debugNewCanvasSaveCount - debugPreviousCanvasSaveCount == 1 ? '' : 's' } '
          'than it called canvas.restore().\n'
          'This leaves the canvas in an inconsistent state and will probably result in a broken display.\n'
          'You must pair each call to save()/saveLayer() with a later matching call to restore().'
        );
      }
      if (debugNewCanvasSaveCount < debugPreviousCanvasSaveCount) {
        throw new FlutterError(
          'The $painter custom painter called canvas.restore() '
          '${debugPreviousCanvasSaveCount - debugNewCanvasSaveCount} more '
          'time${debugPreviousCanvasSaveCount - debugNewCanvasSaveCount == 1 ? '' : 's' } '
          'than it called canvas.save() or canvas.saveLayer().\n'
          'This leaves the canvas in an inconsistent state and will result in a broken display.\n'
          'You should only call restore() if you first called save() or saveLayer().'
        );
      }
      return debugNewCanvasSaveCount == debugPreviousCanvasSaveCount;
    }());
    canvas.restore();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_painter != null) {
      _paintWithPainter(context.canvas, offset, _painter);
      _setRasterCacheHints(context);
    }
    super.paint(context, offset);
    if (_foregroundPainter != null) {
      _paintWithPainter(context.canvas, offset, _foregroundPainter);
      _setRasterCacheHints(context);
    }
  }

  void _setRasterCacheHints(PaintingContext context) {
    if (isComplex)
      context.setIsComplexHint();
    if (willChange)
      context.setWillChangeHint();
  }
}

/// Signature for listening to [PointerDownEvent] events.
///
/// Used by [Listener] and [RenderPointerListener].
typedef void PointerDownEventListener(PointerDownEvent event);

/// Signature for listening to [PointerMoveEvent] events.
///
/// Used by [Listener] and [RenderPointerListener].
typedef void PointerMoveEventListener(PointerMoveEvent event);

/// Signature for listening to [PointerUpEvent] events.
///
/// Used by [Listener] and [RenderPointerListener].
typedef void PointerUpEventListener(PointerUpEvent event);

/// Signature for listening to [PointerCancelEvent] events.
///
/// Used by [Listener] and [RenderPointerListener].
typedef void PointerCancelEventListener(PointerCancelEvent event);

/// Calls callbacks in response to pointer events.
///
/// If it has a child, defers to the child for sizing behavior.
///
/// If it does not have a child, grows to fit the parent-provided constraints.
class RenderPointerListener extends RenderProxyBoxWithHitTestBehavior {
  /// Creates a render object that forwards point events to callbacks.
  ///
  /// The [behavior] argument defaults to [HitTestBehavior.deferToChild].
  RenderPointerListener({
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onPointerCancel,
    HitTestBehavior behavior: HitTestBehavior.deferToChild,
    RenderBox child
  }) : super(behavior: behavior, child: child);

  /// Called when a pointer comes into contact with the screen at this object.
  PointerDownEventListener onPointerDown;

  /// Called when a pointer that triggered an [onPointerDown] changes position.
  PointerMoveEventListener onPointerMove;

  /// Called when a pointer that triggered an [onPointerDown] is no longer in
  /// contact with the screen.
  PointerUpEventListener onPointerUp;

  /// Called when the input from a pointer that triggered an [onPointerDown] is
  /// no longer directed towards this receiver.
  PointerCancelEventListener onPointerCancel;

  @override
  void performResize() {
    size = constraints.biggest;
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    if (onPointerDown != null && event is PointerDownEvent)
      return onPointerDown(event);
    if (onPointerMove != null && event is PointerMoveEvent)
      return onPointerMove(event);
    if (onPointerUp != null && event is PointerUpEvent)
      return onPointerUp(event);
    if (onPointerCancel != null && event is PointerCancelEvent)
      return onPointerCancel(event);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    final List<String> listeners = <String>[];
    if (onPointerDown != null)
      listeners.add('down');
    if (onPointerMove != null)
      listeners.add('move');
    if (onPointerUp != null)
      listeners.add('up');
    if (onPointerCancel != null)
      listeners.add('cancel');
    if (listeners.isEmpty)
      listeners.add('<none>');
    description.add(new IterableProperty<String>('listeners', listeners));
    // TODO(jacobr): add raw listeners to the diagnostics data.
  }
}

/// Creates a separate display list for its child.
///
/// This render object creates a separate display list for its child, which
/// can improve performance if the subtree repaints at different times than
/// the surrounding parts of the tree. Specifically, when the child does not
/// repaint but its parent does, we can re-use the display list we recorded
/// previously. Similarly, when the child repaints but the surround tree does
/// not, we can re-record its display list without re-recording the display list
/// for the surround tree.
///
/// In some cases, it is necessary to place _two_ (or more) repaint boundaries
/// to get a useful effect. Consider, for example, an e-mail application that
/// shows an unread count and a list of e-mails. Whenever a new e-mail comes in,
/// the list would update, but so would the unread count. If only one of these
/// two parts of the application was behind a repaint boundary, the entire
/// application would repaint each time. On the other hand, if both were behind
/// a repaint boundary, a new e-mail would only change those two parts of the
/// application and the rest of the application would not repaint.
///
/// To tell if a particular RenderRepaintBoundary is useful, run your
/// application in checked mode, interacting with it in typical ways, and then
/// call [debugDumpRenderTree]. Each RenderRepaintBoundary will include the
/// ratio of cases where the repaint boundary was useful vs the cases where it
/// was not. These counts can also be inspected programmatically using
/// [debugAsymmetricPaintCount] and [debugSymmetricPaintCount] respectively.
class RenderRepaintBoundary extends RenderProxyBox {
  /// Creates a repaint boundary around [child].
  RenderRepaintBoundary({ RenderBox child }) : super(child);

  @override
  bool get isRepaintBoundary => true;

  /// The number of times that this render object repainted at the same time as
  /// its parent. Repaint boundaries are only useful when the parent and child
  /// paint at different times. When both paint at the same time, the repaint
  /// boundary is redundant, and may be actually making performance worse.
  ///
  /// Only valid when asserts are enabled. In release builds, always returns
  /// zero.
  ///
  /// Can be reset using [debugResetMetrics]. See [debugAsymmetricPaintCount]
  /// for the corresponding count of times where only the parent or only the
  /// child painted.
  int get debugSymmetricPaintCount => _debugSymmetricPaintCount;
  int _debugSymmetricPaintCount = 0;

  /// The number of times that either this render object repainted without the
  /// parent being painted, or the parent repainted without this object being
  /// painted. When a repaint boundary is used at a seam in the render tree
  /// where the parent tends to repaint at entirely different times than the
  /// child, it can improve performance by reducing the number of paint
  /// operations that have to be recorded each frame.
  ///
  /// Only valid when asserts are enabled. In release builds, always returns
  /// zero.
  ///
  /// Can be reset using [debugResetMetrics]. See [debugSymmetricPaintCount] for
  /// the corresponding count of times where both the parent and the child
  /// painted together.
  int get debugAsymmetricPaintCount => _debugAsymmetricPaintCount;
  int _debugAsymmetricPaintCount = 0;

  /// Resets the [debugSymmetricPaintCount] and [debugAsymmetricPaintCount]
  /// counts to zero.
  ///
  /// Only valid when asserts are enabled. Does nothing in release builds.
  void debugResetMetrics() {
    assert(() {
      _debugSymmetricPaintCount = 0;
      _debugAsymmetricPaintCount = 0;
      return true;
    }());
  }

  @override
  void debugRegisterRepaintBoundaryPaint({ bool includedParent: true, bool includedChild: false }) {
    assert(() {
      if (includedParent && includedChild)
        _debugSymmetricPaintCount += 1;
      else
        _debugAsymmetricPaintCount += 1;
      return true;
    }());
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    bool inReleaseMode = true;
    assert(() {
      inReleaseMode = false;
      if (debugSymmetricPaintCount + debugAsymmetricPaintCount == 0) {
        description.add(new MessageProperty('usefulness ratio', 'no metrics collected yet (never painted)'));
      } else {
        final double fraction = debugAsymmetricPaintCount / (debugSymmetricPaintCount + debugAsymmetricPaintCount);
        String diagnosis;
        if (debugSymmetricPaintCount + debugAsymmetricPaintCount < 5) {
          diagnosis = 'insufficient data to draw conclusion (less than five repaints)';
        } else if (fraction > 0.9) {
          diagnosis = 'this is an outstandingly useful repaint boundary and should definitely be kept';
        } else if (fraction > 0.5) {
          diagnosis = 'this is a useful repaint boundary and should be kept';
        } else if (fraction > 0.30) {
          diagnosis = 'this repaint boundary is probably useful, but maybe it would be more useful in tandem with adding more repaint boundaries elsewhere';
        } else if (fraction > 0.1) {
          diagnosis = 'this repaint boundary does sometimes show value, though currently not that often';
        } else if (debugAsymmetricPaintCount == 0) {
          diagnosis = 'this repaint boundary is astoundingly ineffectual and should be removed';
        } else {
          diagnosis = 'this repaint boundary is not very effective and should probably be removed';
        }
        description.add(new PercentProperty('metrics', fraction, unit: 'useful', tooltip: '$debugSymmetricPaintCount bad vs $debugAsymmetricPaintCount good'));
        description.add(new MessageProperty('diagnosis', diagnosis));
      }
      return true;
    }());
    if (inReleaseMode)
      description.add(new DiagnosticsNode.message('(run in checked mode to collect repaint boundary statistics)'));
  }
}

/// A render object that is invisible during hit testing.
///
/// When [ignoring] is true, this render object (and its subtree) is invisible
/// to hit testing. It still consumes space during layout and paints its child
/// as usual. It just cannot be the target of located events, because its render
/// object returns false from [hitTest].
///
/// When [ignoringSemantics] is true, the subtree will be invisible to
/// the semantics layer (and thus e.g. accessibility tools). If
/// [ignoringSemantics] is null, it uses the value of [ignoring].
///
/// See also:
///
///  * [RenderAbsorbPointer], which takes the pointer events but prevents any
///    nodes in the subtree from seeing them.
class RenderIgnorePointer extends RenderProxyBox {
  /// Creates a render object that is invisible to hit testing.
  ///
  /// The [ignoring] argument must not be null. If [ignoringSemantics], this
  /// render object will be ignored for semantics if [ignoring] is true.
  RenderIgnorePointer({
    RenderBox child,
    bool ignoring: true,
    bool ignoringSemantics
  }) : _ignoring = ignoring, _ignoringSemantics = ignoringSemantics, super(child) {
    assert(_ignoring != null);
  }

  /// Whether this render object is ignored during hit testing.
  ///
  /// Regardless of whether this render object is ignored during hit testing, it
  /// will still consume space during layout and be visible during painting.
  bool get ignoring => _ignoring;
  bool _ignoring;
  set ignoring(bool value) {
    assert(value != null);
    if (value == _ignoring)
      return;
    _ignoring = value;
    if (ignoringSemantics == null)
      markNeedsSemanticsUpdate();
  }

  /// Whether the semantics of this render object is ignored when compiling the semantics tree.
  ///
  /// If null, defaults to value of [ignoring].
  ///
  /// See [SemanticsNode] for additional information about the semantics tree.
  bool get ignoringSemantics => _ignoringSemantics;
  bool _ignoringSemantics;
  set ignoringSemantics(bool value) {
    if (value == _ignoringSemantics)
      return;
    final bool oldEffectiveValue = _effectiveIgnoringSemantics;
    _ignoringSemantics = value;
    if (oldEffectiveValue != _effectiveIgnoringSemantics)
      markNeedsSemanticsUpdate();
  }

  bool get _effectiveIgnoringSemantics => ignoringSemantics == null ? ignoring : ignoringSemantics;

  @override
  bool hitTest(HitTestResult result, { Offset position }) {
    return ignoring ? false : super.hitTest(result, position: position);
  }

  // TODO(ianh): figure out a way to still include labels and flags in
  // descendants, just make them non-interactive, even when
  // _effectiveIgnoringSemantics is true
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (child != null && !_effectiveIgnoringSemantics)
      visitor(child);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new DiagnosticsProperty<bool>('ignoring', ignoring));
    description.add(
      new DiagnosticsProperty<bool>(
        'ignoringSemantics',
        _effectiveIgnoringSemantics,
        description: ignoringSemantics == null ? 'implicitly $_effectiveIgnoringSemantics' : null,
      )
    );
  }
}

/// Lays the child out as if it was in the tree, but without painting anything,
/// without making the child available for hit testing, and without taking any
/// room in the parent.
class RenderOffstage extends RenderProxyBox {
  /// Creates an offstage render object.
  RenderOffstage({
    bool offstage: true,
    RenderBox child
  }) : assert(offstage != null),
       _offstage = offstage,
       super(child);

  /// Whether the child is hidden from the rest of the tree.
  ///
  /// If true, the child is laid out as if it was in the tree, but without
  /// painting anything, without making the child available for hit testing, and
  /// without taking any room in the parent.
  ///
  /// If false, the child is included in the tree as normal.
  bool get offstage => _offstage;
  bool _offstage;
  set offstage(bool value) {
    assert(value != null);
    if (value == _offstage)
      return;
    _offstage = value;
    markNeedsLayoutForSizedByParentChange();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (offstage)
      return 0.0;
    return super.computeMinIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (offstage)
      return 0.0;
    return super.computeMaxIntrinsicWidth(height);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (offstage)
      return 0.0;
    return super.computeMinIntrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (offstage)
      return 0.0;
    return super.computeMaxIntrinsicHeight(width);
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    if (offstage)
      return null;
    return super.computeDistanceToActualBaseline(baseline);
  }

  @override
  bool get sizedByParent => offstage;

  @override
  void performResize() {
    assert(offstage);
    size = constraints.smallest;
  }

  @override
  void performLayout() {
    if (offstage) {
      child?.layout(constraints);
    } else {
      super.performLayout();
    }
  }

  @override
  bool hitTest(HitTestResult result, { Offset position }) {
    return !offstage && super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (offstage)
      return;
    super.paint(context, offset);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (offstage)
      return;
    super.visitChildrenForSemantics(visitor);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new DiagnosticsProperty<bool>('offstage', offstage));
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    if (child == null)
      return <DiagnosticsNode>[];
    return <DiagnosticsNode>[
      child.toDiagnosticsNode(
        name: 'child',
        style: offstage ? DiagnosticsTreeStyle.offstage : DiagnosticsTreeStyle.sparse,
      ),
    ];
  }
}

/// A render object that absorbs pointers during hit testing.
///
/// When [absorbing] is true, this render object prevents its subtree from
/// receiving pointer events by terminating hit testing at itself. It still
/// consumes space during layout and paints its child as usual. It just prevents
/// its children from being the target of located events, because its render
/// object returns true from [hitTest].
///
/// See also:
///
///  * [RenderIgnorePointer], which has the opposite effect: removing the
///    subtree from considering entirely for the purposes of hit testing.
class RenderAbsorbPointer extends RenderProxyBox {
  /// Creates a render object that absorbs pointers during hit testing.
  ///
  /// The [absorbing] argument must not be null.
  RenderAbsorbPointer({
    RenderBox child,
    this.absorbing: true
  }) : assert(absorbing != null),
       super(child);

  /// Whether this render object absorbs pointers during hit testing.
  ///
  /// Regardless of whether this render object absorbs pointers during hit
  /// testing, it will still consume space during layout and be visible during
  /// painting.
  bool absorbing;

  @override
  bool hitTest(HitTestResult result, { Offset position }) {
    return absorbing ? true : super.hitTest(result, position: position);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new DiagnosticsProperty<bool>('absorbing', absorbing));
  }
}

/// Holds opaque meta data in the render tree.
///
/// Useful for decorating the render tree with information that will be consumed
/// later. For example, you could store information in the render tree that will
/// be used when the user interacts with the render tree but has no visual
/// impact prior to the interaction.
class RenderMetaData extends RenderProxyBoxWithHitTestBehavior {
  /// Creates a render object that hold opaque meta data.
  ///
  /// The [behavior] argument defaults to [HitTestBehavior.deferToChild].
  RenderMetaData({
    this.metaData,
    HitTestBehavior behavior: HitTestBehavior.deferToChild,
    RenderBox child
  }) : super(behavior: behavior, child: child);

  /// Opaque meta data ignored by the render tree
  dynamic metaData;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new DiagnosticsProperty<dynamic>('metaData', metaData));
  }
}

/// Listens for the specified gestures from the semantics server (e.g.
/// an accessibility tool).
class RenderSemanticsGestureHandler extends RenderProxyBox {
  /// Creates a render object that listens for specific semantic gestures.
  ///
  /// The [scrollFactor] argument must not be null.
  RenderSemanticsGestureHandler({
    RenderBox child,
    GestureTapCallback onTap,
    GestureLongPressCallback onLongPress,
    GestureDragUpdateCallback onHorizontalDragUpdate,
    GestureDragUpdateCallback onVerticalDragUpdate,
    this.scrollFactor: 0.8
  }) : assert(scrollFactor != null),
       _onTap = onTap,
       _onLongPress = onLongPress,
       _onHorizontalDragUpdate = onHorizontalDragUpdate,
       _onVerticalDragUpdate = onVerticalDragUpdate,
       super(child);

  /// When a [SemanticsNode] that is a direct child of this object's
  /// [SemanticsNode] is tagged with [excludeFromScrolling] it will not be
  /// part of the scrolling area for semantic purposes.
  ///
  /// This behavior is only active if the [SemanticsNode] of this
  /// [RenderSemanticsGestureHandler] is tagged with [useTwoPaneSemantics].
  /// Otherwise, the [excludeFromScrolling] tag is ignored.
  ///
  /// As an example, a [RenderSliver] that stays on the screen within a
  /// [Scrollable] even though the user has scrolled past it (e.g. a pinned app
  /// bar) can tag its [SemanticsNode] with [excludeFromScrolling] to indicate
  /// that it should no longer be considered for semantic actions related to
  /// scrolling.
  static const SemanticsTag excludeFromScrolling = const SemanticsTag('RenderSemanticsGestureHandler.excludeFromScrolling');

  /// If the [SemanticsNode] of this [RenderSemanticsGestureHandler] is tagged
  /// with [useTwoPaneSemantics], two semantics nodes will be used to represent
  /// this render object in the semantics tree.
  ///
  /// Two semantics nodes are necessary to exclude certain child nodes (via the
  /// [excludeFromScrolling] tag) from the scrollable area for semantic
  /// purposes.
  ///
  /// If this tag is used, the first "outer" semantics node is the regular node
  /// of this object. The second "inner" node is introduces as a child to that
  /// node. All scrollable children are now a child of the inner node, which has
  /// the semantic scrolling logic enabled. All children that have been
  /// excluded from scrolling with [excludeFromScrolling] are turned into
  /// children of the outer node.
  static const SemanticsTag useTwoPaneSemantics = const SemanticsTag('RenderSemanticsGestureHandler.twoPane');

  /// If non-null, the set of actions to allow. Other actions will be omitted,
  /// even if their callback is provided.
  ///
  /// For example, if [onTap] is non-null but [validActions] does not contain
  /// [SemanticsAction.tap], then the semantic description of this node will
  /// not claim to support taps.
  ///
  /// This is normally used to filter the actions made available by
  /// [onHorizontalDragUpdate] and [onVerticalDragUpdate]. Normally, these make
  /// both the right and left, or up and down, actions available. For example,
  /// if [onHorizontalDragUpdate] is set but [validActions] only contains
  /// [SemanticsAction.scrollLeft], then the [SemanticsAction.scrollRight]
  /// action will be omitted.
  Set<SemanticsAction> get validActions => _validActions;
  Set<SemanticsAction> _validActions;
  set validActions(Set<SemanticsAction> value) {
    if (setEquals<SemanticsAction>(value, _validActions))
      return;
    _validActions = value;
    markNeedsSemanticsUpdate(onlyLocalUpdates: true);
  }

   /// Called when the user taps on the render object.
  GestureTapCallback get onTap => _onTap;
  GestureTapCallback _onTap;
  set onTap(GestureTapCallback value) {
    if (_onTap == value)
      return;
    final bool hadHandlers = _hasHandlers;
    final bool hadHandler = _onTap != null;
    _onTap = value;
    if ((value != null) != hadHandler)
      markNeedsSemanticsUpdate(onlyLocalUpdates: _hasHandlers == hadHandlers);
  }

  /// Called when the user presses on the render object for a long period of time.
  GestureLongPressCallback get onLongPress => _onLongPress;
  GestureLongPressCallback _onLongPress;
  set onLongPress(GestureLongPressCallback value) {
    if (_onLongPress == value)
      return;
    final bool hadHandlers = _hasHandlers;
    final bool hadHandler = _onLongPress != null;
    _onLongPress = value;
    if ((value != null) != hadHandler)
      markNeedsSemanticsUpdate(onlyLocalUpdates: _hasHandlers == hadHandlers);
  }

  /// Called when the user scrolls to the left or to the right.
  GestureDragUpdateCallback get onHorizontalDragUpdate => _onHorizontalDragUpdate;
  GestureDragUpdateCallback _onHorizontalDragUpdate;
  set onHorizontalDragUpdate(GestureDragUpdateCallback value) {
    if (_onHorizontalDragUpdate == value)
      return;
    final bool hadHandlers = _hasHandlers;
    final bool hadHandler = _onHorizontalDragUpdate != null;
    _onHorizontalDragUpdate = value;
    if ((value != null) != hadHandler)
      markNeedsSemanticsUpdate(onlyLocalUpdates: _hasHandlers == hadHandlers);
  }

  /// Called when the user scrolls up or down.
  GestureDragUpdateCallback get onVerticalDragUpdate => _onVerticalDragUpdate;
  GestureDragUpdateCallback _onVerticalDragUpdate;
  set onVerticalDragUpdate(GestureDragUpdateCallback value) {
    if (_onVerticalDragUpdate == value)
      return;
    final bool hadHandlers = _hasHandlers;
    final bool hadHandler = _onVerticalDragUpdate != null;
    _onVerticalDragUpdate = value;
    if ((value != null) != hadHandler)
      markNeedsSemanticsUpdate(onlyLocalUpdates: _hasHandlers == hadHandlers);
  }

  /// The fraction of the dimension of this render box to use when
  /// scrolling. For example, if this is 0.8 and the box is 200 pixels
  /// wide, then when a left-scroll action is received from the
  /// accessibility system, it will translate into a 160 pixel
  /// leftwards drag.
  double scrollFactor;

  bool get _hasHandlers {
    return onTap != null
        || onLongPress != null
        || onHorizontalDragUpdate != null
        || onVerticalDragUpdate != null;
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);

    config.isSemanticBoundary = _hasHandlers;

    // TODO(goderbauer): this needs to be set even when there is only potential
    //    for this to become a scroll view.
    config.explicitChildNodes = onHorizontalDragUpdate != null
        || onVerticalDragUpdate != null;

    final Map<SemanticsAction, VoidCallback> actions = <SemanticsAction, VoidCallback>{};
    if (onTap != null)
      actions[SemanticsAction.tap] = onTap;
    if (onLongPress != null)
      actions[SemanticsAction.longPress] = onLongPress;
    if (onHorizontalDragUpdate != null) {
      actions[SemanticsAction.scrollRight] = _performSemanticScrollRight;
      actions[SemanticsAction.scrollLeft] = _performSemanticScrollLeft;
    }
    if (onVerticalDragUpdate != null) {
      actions[SemanticsAction.scrollUp] = _performSemanticScrollUp;
      actions[SemanticsAction.scrollDown] = _performSemanticScrollDown;
    }

    final Iterable<SemanticsAction> actionsToAdd = validActions ?? actions.keys;

    for (SemanticsAction action in actionsToAdd) {
      final VoidCallback handler = actions[action];
      if (handler != null)
        config.addAction(action, handler);
    }
  }

  SemanticsNode _innerNode;
  SemanticsNode _annotatedNode;

  /// Sends a [SemanticsEvent] in the context of the [SemanticsNode] that is
  /// annotated with this object's semantics information.
  void sendSemanticsEvent(SemanticsEvent event) {
    _annotatedNode?.sendEvent(event);
  }

  @override
  void assembleSemanticsNode(SemanticsNode node, SemanticsConfiguration config, Iterable<SemanticsNode> children) {
    if (children.isEmpty || !children.first.isTagged(useTwoPaneSemantics)) {
      _annotatedNode = node;
      super.assembleSemanticsNode(node, config, children);
      return;
    }

    _innerNode ??= new SemanticsNode(showOnScreen: showOnScreen);
    _innerNode
      ..isMergedIntoParent = node.isPartOfNodeMerging
      ..rect = Offset.zero & node.rect.size;
    _annotatedNode = _innerNode;

    final List<SemanticsNode> excluded = <SemanticsNode>[_innerNode];
    final List<SemanticsNode> included = <SemanticsNode>[];
    for (SemanticsNode child in children) {
      assert(child.isTagged(useTwoPaneSemantics));
      if (child.isTagged(excludeFromScrolling))
        excluded.add(child);
      else
        included.add(child);
    }
    node.updateWith(config: null, childrenInInversePaintOrder: excluded);
    _innerNode.updateWith(config: config, childrenInInversePaintOrder: included);
  }

  void _performSemanticScrollLeft() {
    if (onHorizontalDragUpdate != null) {
      final double primaryDelta = size.width * -scrollFactor;
      onHorizontalDragUpdate(new DragUpdateDetails(
        delta: new Offset(primaryDelta, 0.0), primaryDelta: primaryDelta,
        globalPosition: localToGlobal(size.center(Offset.zero)),
      ));
    }
  }

  void _performSemanticScrollRight() {
    if (onHorizontalDragUpdate != null) {
      final double primaryDelta = size.width * scrollFactor;
      onHorizontalDragUpdate(new DragUpdateDetails(
        delta: new Offset(primaryDelta, 0.0), primaryDelta: primaryDelta,
        globalPosition: localToGlobal(size.center(Offset.zero)),
      ));
    }
  }

  void _performSemanticScrollUp() {
    if (onVerticalDragUpdate != null) {
      final double primaryDelta = size.height * -scrollFactor;
      onVerticalDragUpdate(new DragUpdateDetails(
        delta: new Offset(0.0, primaryDelta), primaryDelta: primaryDelta,
        globalPosition: localToGlobal(size.center(Offset.zero)),
      ));
    }
  }

  void _performSemanticScrollDown() {
    if (onVerticalDragUpdate != null) {
      final double primaryDelta = size.height * scrollFactor;
      onVerticalDragUpdate(new DragUpdateDetails(
        delta: new Offset(0.0, primaryDelta), primaryDelta: primaryDelta,
        globalPosition: localToGlobal(size.center(Offset.zero)),
      ));
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    final List<String> gestures = <String>[];
    if (onTap != null)
      gestures.add('tap');
    if (onLongPress != null)
      gestures.add('long press');
    if (onHorizontalDragUpdate != null)
      gestures.add('horizontal scroll');
    if (onVerticalDragUpdate != null)
      gestures.add('vertical scroll');
    if (gestures.isEmpty)
      gestures.add('<none>');
    description.add(new IterableProperty<String>('gestures', gestures));
  }
}

/// Add annotations to the [SemanticsNode] for this subtree.
class RenderSemanticsAnnotations extends RenderProxyBox {
  /// Creates a render object that attaches a semantic annotation.
  ///
  /// The [container] argument must not be null.
  ///
  /// If the [label] is not null, the [textDirection] must also not be null.
  RenderSemanticsAnnotations({
    RenderBox child,
    bool container: false,
    bool explicitChildNodes,
    bool checked,
    bool selected,
    bool button,
    String label,
    String value,
    String increasedValue,
    String decreasedValue,
    String hint,
    TextDirection textDirection,
    VoidCallback onTap,
    VoidCallback onLongPress,
    VoidCallback onScrollLeft,
    VoidCallback onScrollRight,
    VoidCallback onScrollUp,
    VoidCallback onScrollDown,
    VoidCallback onIncrease,
    VoidCallback onDecrease,
  }) : assert(container != null),
       _container = container,
       _explicitChildNodes = explicitChildNodes,
       _checked = checked,
       _selected = selected,
       _button = button,
       _label = label,
       _value = value,
       _increasedValue = increasedValue,
       _decreasedValue = decreasedValue,
       _hint = hint,
       _textDirection = textDirection,
       _onTap = onTap,
       _onLongPress = onLongPress,
       _onScrollLeft = onScrollLeft,
       _onScrollRight = onScrollRight,
       _onScrollUp = onScrollUp,
       _onScrollDown = onScrollDown,
       _onIncrease = onIncrease,
       _onDecrease = onDecrease,
       super(child);

  /// If 'container' is true, this [RenderObject] will introduce a new
  /// node in the semantics tree. Otherwise, the semantics will be
  /// merged with the semantics of any ancestors.
  ///
  /// Whether descendants of this [RenderObject] can add their semantic information
  /// to the [SemanticsNode] introduced by this configuration is controlled by
  /// [explicitChildNodes].
  bool get container => _container;
  bool _container;
  set container(bool value) {
    assert(value != null);
    if (container == value)
      return;
    _container = value;
    markNeedsSemanticsUpdate();
  }

  /// Whether descendants of this [RenderObject] are allowed to add semantic
  /// information to the [SemanticsNode] annotated by this widget.
  ///
  /// When set to false descendants are allowed to annotate [SemanticNode]s of
  /// their parent with the semantic information they want to contribute to the
  /// semantic tree.
  /// When set to true the only way for descendants to contribute semantic
  /// information to the semantic tree is to introduce new explicit
  /// [SemanticNode]s to the tree.
  ///
  /// This setting is often used in combination with [isSemanticBoundary] to
  /// create semantic boundaries that are either writable or not for children.
  bool get explicitChildNodes => _explicitChildNodes;
  bool _explicitChildNodes;
  set explicitChildNodes(bool value) {
    assert(value != null);
    if (_explicitChildNodes == value)
      return;
    _explicitChildNodes = value;
    markNeedsSemanticsUpdate();
  }

  /// If non-null, sets the [SemanticsNode.hasCheckedState] semantic to true and
  /// the [SemanticsNode.isChecked] semantic to the given value.
  bool get checked => _checked;
  bool _checked;
  set checked(bool value) {
    if (checked == value)
      return;
    final bool hadValue = checked != null;
    _checked = value;
    markNeedsSemanticsUpdate(onlyLocalUpdates: (value != null) == hadValue);
  }

  /// If non-null, sets the [SemanticsNode.isSelected] semantic to the given
  /// value.
  bool get selected => _selected;
  bool _selected;
  set selected(bool value) {
    if (selected == value)
      return;
    final bool hadValue = selected != null;
    _selected = value;
    markNeedsSemanticsUpdate(onlyLocalUpdates: (value != null) == hadValue);
  }

  /// If non-null, sets the [SemanticsNode.isButton] semantic to the given value.
  bool get button => _button;
  bool _button;
  set button(bool value) {
    if (button == value)
      return;
    final bool hadValue = button != null;
    _button = value;
    markNeedsSemanticsUpdate(onlyLocalUpdates: (value != null) == hadValue);
  }

  /// If non-null, sets the [SemanticsNode.label] semantic to the given value.
  ///
  /// The reading direction is given by [textDirection].
  String get label => _label;
  String _label;
  set label(String value) {
    if (_label == value)
      return;
    final bool hadValue = _label != null;
    _label = value;
    markNeedsSemanticsUpdate(onlyLocalUpdates: (value != null) == hadValue);
  }

  /// If non-null, sets the [SemanticsNode.value] semantic to the given value.
  ///
  /// The reading direction is given by [textDirection].
  String get value => _value;
  String _value;
  set value(String value) {
    if (_value == value)
      return;
    final bool hadValue = _value != null;
    _value = value;
    markNeedsSemanticsUpdate(onlyLocalUpdates: (value != null) == hadValue);
  }

  /// If non-null, sets the [SemanticsNode.increasedValue] semantic to the given
  /// value.
  ///
  /// The reading direction is given by [textDirection].
  String get increasedValue => _increasedValue;
  String _increasedValue;
  set increasedValue(String value) {
    if (_increasedValue == value)
      return;
    final bool hadValue = _increasedValue != null;
    _increasedValue = value;
    markNeedsSemanticsUpdate(onlyLocalUpdates: (value != null) == hadValue);
  }

  /// If non-null, sets the [SemanticsNode.decreasedValue] semantic to the given
  /// value.
  ///
  /// The reading direction is given by [textDirection].
  String get decreasedValue => _decreasedValue;
  String _decreasedValue;
  set decreasedValue(String value) {
    if (_decreasedValue == value)
      return;
    final bool hadValue = _decreasedValue != null;
    _decreasedValue = value;
    markNeedsSemanticsUpdate(onlyLocalUpdates: (value != null) == hadValue);
  }

  /// If non-null, sets the [SemanticsNode.hint] semantic to the given value.
  ///
  /// The reading direction is given by [textDirection].
  String get hint => _hint;
  String _hint;
  set hint(String value) {
    if (_hint == value)
      return;
    final bool hadValue = _hint != null;
    _hint = value;
    markNeedsSemanticsUpdate(onlyLocalUpdates: (value != null) == hadValue);
  }

  /// If non-null, sets the [SemanticsNode.textDirection] semantic to the given value.
  ///
  /// This must not be null if [label], [hint], [value], [increasedValue], or
  /// [decreasedValue] are not null.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (textDirection == value)
      return;
    final bool hadValue = textDirection != null;
    _textDirection = value;
    markNeedsSemanticsUpdate(onlyLocalUpdates: (value != null) == hadValue);
  }

  /// The handler for [SemanticsAction.tap].
  ///
  /// This is the semantic equivalent of a user briefly tapping the screen with
  /// the finger without moving it. For example, a button should implement this
  /// action.
  ///
  /// VoiceOver users on iOS and TalkBack users on Android can trigger this
  /// action by double-tapping the screen while an element is focused.
  VoidCallback get onTap => _onTap;
  VoidCallback _onTap;
  set onTap(VoidCallback handler) {
    if (_onTap == handler)
      return;
    final bool hadValue = _onTap != null;
    _onTap = handler;
    if ((handler != null) == hadValue)
      markNeedsSemanticsUpdate(onlyLocalUpdates: true);
  }

  /// The handler for [SemanticsAction.longPress].
  ///
  /// This is the semantic equivalent of a user pressing and holding the screen
  /// with the finger for a few seconds without moving it.
  ///
  /// VoiceOver users on iOS and TalkBack users on Android can trigger this
  /// action by double-tapping the screen without lifting the finger after the
  /// second tap.
  VoidCallback get onLongPress => _onLongPress;
  VoidCallback _onLongPress;
  set onLongPress(VoidCallback handler) {
    if (_onLongPress == handler)
      return;
    final bool hadValue = _onLongPress != null;
    _onLongPress = handler;
    if ((handler != null) != hadValue)
      markNeedsSemanticsUpdate(onlyLocalUpdates: true);
  }

  /// The handler for [SemanticsAction.scrollLeft].
  ///
  /// This is the semantic equivalent of a user moving their finger across the
  /// screen from right to left. It should be recognized by controls that are
  /// horizontally scrollable.
  ///
  /// VoiceOver users on iOS can trigger this action by swiping left with three
  /// fingers. TalkBack users on Android can trigger this action by swiping
  /// right and then left in one motion path. On Android, [onScrollUp] and
  /// [onScrollLeft] share the same gesture. Therefore, only on of them should
  /// be provided.
  VoidCallback get onScrollLeft => _onScrollLeft;
  VoidCallback _onScrollLeft;
  set onScrollLeft(VoidCallback handler) {
    if (_onScrollLeft == handler)
      return;
    final bool hadValue = _onScrollLeft != null;
    _onScrollLeft = handler;
    if ((handler != null) != hadValue)
      markNeedsSemanticsUpdate(onlyLocalUpdates: true);
  }

  /// The handler for [SemanticsAction.scrollRight].
  ///
  /// This is the semantic equivalent of a user moving their finger across the
  /// screen from left to right. It should be recognized by controls that are
  /// horizontally scrollable.
  ///
  /// VoiceOver users on iOS can trigger this action by swiping right with three
  /// fingers. TalkBack users on Android can trigger this action by swiping
  /// left and then right in one motion path. On Android, [onScrollDown] and
  /// [onScrollRight] share the same gesture. Therefore, only on of them should
  /// be provided.
  VoidCallback get onScrollRight => _onScrollRight;
  VoidCallback _onScrollRight;
  set onScrollRight(VoidCallback handler) {
    if (_onScrollRight == handler)
      return;
    final bool hadValue = _onScrollRight != null;
    _onScrollRight = handler;
    if ((handler != null) != hadValue)
      markNeedsSemanticsUpdate(onlyLocalUpdates: true);
  }

  /// The handler for [SemanticsAction.scrollUp].
  ///
  /// This is the semantic equivalent of a user moving their finger across the
  /// screen from bottom to top. It should be recognized by controls that are
  /// vertically scrollable.
  ///
  /// VoiceOver users on iOS can trigger this action by swiping up with three
  /// fingers. TalkBack users on Android can trigger this action by swiping
  /// right and then left in one motion path. On Android, [onScrollUp] and
  /// [onScrollLeft] share the same gesture. Therefore, only on of them should
  /// be provided.
  VoidCallback get onScrollUp => _onScrollUp;
  VoidCallback _onScrollUp;
  set onScrollUp(VoidCallback handler) {
    if (_onScrollUp == handler)
      return;
    final bool hadValue = _onScrollUp != null;
    _onScrollUp = handler;
    if ((handler != null) != hadValue)
      markNeedsSemanticsUpdate(onlyLocalUpdates: true);
  }

  /// The handler for [SemanticsAction.scrollDown].
  ///
  /// This is the semantic equivalent of a user moving their finger across the
  /// screen from top to bottom. It should be recognized by controls that are
  /// vertically scrollable.
  ///
  /// VoiceOver users on iOS can trigger this action by swiping down with three
  /// fingers. TalkBack users on Android can trigger this action by swiping
  /// left and then right in one motion path. On Android, [onScrollDown] and
  /// [onScrollRight] share the same gesture. Therefore, only on of them should
  /// be provided.
  VoidCallback get onScrollDown => _onScrollDown;
  VoidCallback _onScrollDown;
  set onScrollDown(VoidCallback handler) {
    if (_onScrollDown == handler)
      return;
    final bool hadValue = _onScrollDown != null;
    _onScrollDown = handler;
    if ((handler != null) != hadValue)
      markNeedsSemanticsUpdate(onlyLocalUpdates: true);
  }

  /// The handler for [SemanticsAction.increase].
  ///
  /// This is a request to increase the value represented by the widget. For
  /// example, this action might be recognized by a slider control.
  ///
  /// VoiceOver users on iOS can trigger this action by swiping up with one
  /// finger. TalkBack users on Android can trigger this action by pressing the
  /// volume up button.
  VoidCallback get onIncrease => _onIncrease;
  VoidCallback _onIncrease;
  set onIncrease(VoidCallback handler) {
    if (_onIncrease == handler)
      return;
    final bool hadValue = _onIncrease != null;
    _onIncrease = handler;
    if ((handler != null) != hadValue)
      markNeedsSemanticsUpdate(onlyLocalUpdates: true);
  }

  /// The handler for [SemanticsAction.decrease].
  ///
  /// This is a request to decrease the value represented by the widget. For
  /// example, this action might be recognized by a slider control.
  ///
  /// VoiceOver users on iOS can trigger this action by swiping down with one
  /// finger. TalkBack users on Android can trigger this action by pressing the
  /// volume down button.
  VoidCallback get onDecrease => _onDecrease;
  VoidCallback _onDecrease;
  set onDecrease(VoidCallback handler) {
    if (_onDecrease == handler)
      return;
    final bool hadValue = _onDecrease != null;
    _onDecrease = handler;
    if ((handler != null) != hadValue)
      markNeedsSemanticsUpdate(onlyLocalUpdates: true);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    assert(
      onIncrease == null || (value == null) == (increasedValue == null),
      'If "onIncrease" is set either both "value" and "increasedValue" or neither have to be set.',
    );
    assert(
      onDecrease == null || (value == null) == (decreasedValue == null),
      'If "onDecrease" is set either both "value" and "decreasedValue" or neither have to be set.',
    );

    config.isSemanticBoundary = container;
    config.explicitChildNodes = explicitChildNodes;

    if (checked != null)
      config.isChecked = checked;
    if (selected != null)
      config.isSelected = selected;
    if (button != null)
      config.isButton = button;
    if (label != null)
      config.label = label;
    if (value != null)
      config.value = value;
    if (increasedValue != null)
      config.increasedValue = increasedValue;
    if (decreasedValue != null)
      config.decreasedValue = decreasedValue;
    if (hint != null)
      config.hint = hint;
    if (textDirection != null)
      config.textDirection = textDirection;
    // Registering _perform* as action handlers instead of the user provided
    // ones to ensure that changing a user provided handler from a non-null to
    // another non-null value doesn't require a semantics update.
    if (onTap != null)
      config.addAction(SemanticsAction.tap, _performTap);
    if (onLongPress != null)
      config.addAction(SemanticsAction.longPress, _performLongPress);
    if (onScrollLeft != null)
      config.addAction(SemanticsAction.scrollLeft, _performScrollLeft);
    if (onScrollRight != null)
      config.addAction(SemanticsAction.scrollRight, _performScrollRight);
    if (onScrollUp != null)
      config.addAction(SemanticsAction.scrollUp, _performScrollUp);
    if (onScrollDown != null)
      config.addAction(SemanticsAction.scrollDown, _performScrollDown);
    if (onIncrease != null)
      config.addAction(SemanticsAction.increase, _performIncrease);
    if (onDecrease != null)
      config.addAction(SemanticsAction.decrease, _performDecrease);
  }

  void _performTap() {
    if (onTap != null)
      onTap();
  }

  void _performLongPress() {
    if (onLongPress != null)
      onLongPress();
  }

  void _performScrollLeft() {
    if (onScrollLeft != null)
      onScrollLeft();
  }

  void _performScrollRight() {
    if (onScrollRight != null)
      onScrollRight();
  }

  void _performScrollUp() {
    if (onScrollUp != null)
      onScrollUp();
  }

  void _performScrollDown() {
    if (onScrollDown != null)
      onScrollDown();
  }

  void _performIncrease() {
    if (onIncrease != null)
      onIncrease();
  }

  void _performDecrease() {
    if (onDecrease != null)
      onDecrease();
  }
}

/// Causes the semantics of all earlier render objects below the same semantic
/// boundary to be dropped.
///
/// This is useful in a stack where an opaque mask should prevent interactions
/// with the render objects painted below the mask.
class RenderBlockSemantics extends RenderProxyBox {
  /// Create a render object that blocks semantics for nodes below it in paint
  /// order.
  RenderBlockSemantics({ RenderBox child }) : super(child);

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isBlockingSemanticsOfPreviouslyPaintedNodes = true;
  }
}

/// Causes the semantics of all descendants to be merged into this
/// node such that the entire subtree becomes a single leaf in the
/// semantics tree.
///
/// Useful for combining the semantics of multiple render objects that
/// form part of a single conceptual widget, e.g. a checkbox, a label,
/// and the gesture detector that goes with them.
class RenderMergeSemantics extends RenderProxyBox {
  /// Creates a render object that merges the semantics from its descendants.
  RenderMergeSemantics({ RenderBox child }) : super(child);

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..isMergingSemanticsOfDescendants = true;
  }
}

/// Excludes this subtree from the semantic tree.
///
/// When [excluding] is true, this render object (and its subtree) is excluded
/// from the semantic tree.
///
/// Useful e.g. for hiding text that is redundant with other text next
/// to it (e.g. text included only for the visual effect).
class RenderExcludeSemantics extends RenderProxyBox {
  /// Creates a render object that ignores the semantics of its subtree.
  RenderExcludeSemantics({
    RenderBox child,
    bool excluding: true,
  }) : _excluding = excluding, super(child) {
    assert(_excluding != null);
  }

  /// Whether this render object is excluded from the semantic tree.
  bool get excluding => _excluding;
  bool _excluding;
  set excluding(bool value) {
    assert(value != null);
    if (value == _excluding)
      return;
    _excluding = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (excluding)
      return;
    super.visitChildrenForSemantics(visitor);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new DiagnosticsProperty<bool>('excluding', excluding));
  }
}

/// Provides an anchor for a [RenderFollowerLayer].
///
/// See also:
///
///  * [CompositedTransformTarget], the corresponding widget.
///  * [LeaderLayer], the layer that this render object creates.
class RenderLeaderLayer extends RenderProxyBox {
  /// Creates a render object that uses a [LeaderLayer].
  ///
  /// The [link] must not be null.
  RenderLeaderLayer({
    @required LayerLink link,
    RenderBox child,
  }) : assert(link != null),
       super(child) {
    this.link = link;
  }

  /// The link object that connects this [RenderLeaderLayer] with one or more
  /// [RenderFollowerLayer]s.
  ///
  /// This property must not be null. The object must not be associated with
  /// another [RenderLeaderLayer] that is also being painted.
  LayerLink get link => _link;
  LayerLink _link;
  set link(LayerLink value) {
    assert(value != null);
    if (_link == value)
      return;
    _link = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushLayer(new LeaderLayer(link: link, offset: offset), super.paint, Offset.zero);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new DiagnosticsProperty<LayerLink>('link', link));
  }
}

/// Transform the child so that its origin is [offset] from the origin of the
/// [RenderLeaderLayer] with the same [LayerLink].
///
/// The [RenderLeaderLayer] in question must be earlier in the paint order.
///
/// Hit testing on descendants of this render object will only work if the
/// target position is within the box that this render object's parent considers
/// to be hitable.
///
/// See also:
///
///  * [CompositedTransformFollower], the corresponding widget.
///  * [FollowerLayer], the layer that this render object creates.
class RenderFollowerLayer extends RenderProxyBox {
  /// Creates a render object that uses a [FollowerLayer].
  ///
  /// The [link] and [offset] arguments must not be null.
  RenderFollowerLayer({
    @required LayerLink link,
    bool showWhenUnlinked: true,
    Offset offset: Offset.zero,
    RenderBox child,
  }) : assert(link != null),
       assert(showWhenUnlinked != null),
       assert(offset != null),
       super(child) {
    this.link = link;
    this.showWhenUnlinked = showWhenUnlinked;
    this.offset = offset;
  }

  /// The link object that connects this [RenderFollowerLayer] with a
  /// [RenderLeaderLayer] earlier in the paint order.
  LayerLink get link => _link;
  LayerLink _link;
  set link(LayerLink value) {
    assert(value != null);
    if (_link == value)
      return;
    _link = value;
    markNeedsPaint();
  }

  /// Whether to show the render object's contents when there is no
  /// corresponding [RenderLeaderLayer] with the same [link].
  ///
  /// When the render object is linked, the child is positioned such that it has
  /// the same global position as the linked [RenderLeaderLayer].
  ///
  /// When the render object is not linked, then: if [showWhenUnlinked] is true,
  /// the child is visible and not repositioned; if it is false, then child is
  /// hidden.
  bool get showWhenUnlinked => _showWhenUnlinked;
  bool _showWhenUnlinked;
  set showWhenUnlinked(bool value) {
    assert(value != null);
    if (_showWhenUnlinked == value)
      return;
    _showWhenUnlinked = value;
    markNeedsPaint();
  }

  /// The offset to apply to the origin of the linked [RenderLeaderLayer] to
  /// obtain this render object's origin.
  Offset get offset => _offset;
  Offset _offset;
  set offset(Offset value) {
    assert(value != null);
    if (_offset == value)
      return;
    _offset = value;
    markNeedsPaint();
  }

  @override
  void detach() {
    _layer = null;
    super.detach();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  /// The layer we created when we were last painted.
  FollowerLayer _layer;

  /// Return the transform that was used in the last composition phase, if any.
  ///
  /// If the [FollowerLayer] has not yet been created, was never composited, or
  /// was unable to determine the transform (see
  /// [FollowerLayer.getLastTransform]), this returns the identity matrix (see
  /// [new Matrix4.identity].
  Matrix4 getCurrentTransform() {
    return _layer?.getLastTransform() ?? new Matrix4.identity();
  }

  @override
  bool hitTest(HitTestResult result, { Offset position }) {
    Matrix4 inverse;
    try {
      inverse = new Matrix4.inverted(getCurrentTransform());
    } on ArgumentError {
      // We cannot invert the effective transform. That means the child
      // doesn't appear on screen and cannot be hit.
      return false;
    }
    position = MatrixUtils.transformPoint(inverse, position);
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    assert(showWhenUnlinked != null);
    _layer = new FollowerLayer(
      link: link,
      showWhenUnlinked: showWhenUnlinked,
      linkedOffset: this.offset,
      unlinkedOffset: offset,
    );
    context.pushLayer(
      _layer,
      super.paint,
      Offset.zero,
      childPaintBounds: new Rect.fromLTRB(
        // We don't know where we'll end up, so we have no idea what our cull rect should be.
        double.NEGATIVE_INFINITY,
        double.NEGATIVE_INFINITY,
        double.INFINITY,
        double.INFINITY,
      ),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(getCurrentTransform());
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new DiagnosticsProperty<LayerLink>('link', link));
    description.add(new DiagnosticsProperty<bool>('showWhenUnlinked', showWhenUnlinked));
    description.add(new DiagnosticsProperty<Offset>('offset', offset));
    description.add(new TransformProperty('current transform matrix', getCurrentTransform()));
  }
}

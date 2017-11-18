// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'basic_types.dart';
import 'borders.dart';
import 'box_border.dart';
import 'box_decoration.dart';
import 'box_shadow.dart';
import 'circle_border.dart';
import 'decoration.dart';
import 'edge_insets.dart';
import 'gradient.dart';
import 'images.dart';
import 'rounded_rectangle_border.dart';

/// An immutable description of how to paint an arbitrary shape.
///
/// The [ShapeDecoration] class provides a way to draw a [ShapeBorder],
/// optionally filling it with a color or a gradient, optionally painting an
/// image into it, and optionally casting a shadow.
///
/// ## Sample code
///
/// The following example uses the [Container] widget from the widgets layer to
/// draw a white rectangle with a 24-pixel multicolor outline, with the text
/// "RGB" inside it:
///
/// ```dart
/// new Container(
///   decoration: new ShapeDecoration(
///     color: Colors.white,
///     shape: new Border.all(
///       color: Colors.red,
///       width: 8.0,
///     ) + new Border.all(
///       color: Colors.green,
///       width: 8.0,
///     ) + new Border.all(
///       color: Colors.blue,
///       width: 8.0,
///     ),
///   ),
///   child: const Text('RGB', textAlign: TextAlign.center),
/// )
/// ```
///
/// See also:
///
///  * [DecoratedBox] and [Container], widgets that can be configured with
///    [ShapeDecoration] objects.
///  * [BoxDecoration], a similar [Decoration] that is optimized for rectangles
///    specifically.
///  * [ShapeBorder], the base class for the objects that are used in the
///    [shape] property.
class ShapeDecoration extends Decoration {
  /// Creates a shape decoration.
  ///
  /// * If [color] is null, this decoration does not paint a background color.
  /// * If [gradient] is null, this decoration does not paint gradients.
  /// * If [image] is null, this decoration does not paint a background image.
  /// * If [shadows] is null, this decoration does not paint a shadow.
  ///
  /// The [color] and [gradient] properties are mutually exclusive, one (or
  /// both) of them must be null.
  ///
  /// The [shape] must not be null.
  const ShapeDecoration({
    this.color,
    this.image,
    this.gradient,
    this.shadows,
    @required this.shape,
  }) : assert(!(color != null && gradient != null)),
       assert(shape != null);

  /// Creates a shape decoration configured to match a [BoxDecoration].
  ///
  /// The [BoxDecoration] class is more efficient for shapes that it can
  /// describe than the [ShapeDecoration] class is for those same shapes,
  /// because [ShapeDecoration] has to be more general as it can support any
  /// shape. However, having a [ShapeDecoration] is sometimes necessary, for
  /// example when calling [ShapeDecoration.lerp] to transition between
  /// different shapes (e.g. from a [CircleBorder] to a
  /// [RoundedRectangleBorder]; the [BoxDecoration] class cannot animate the
  /// transition from a [BoxShape.circle] to [BoxShape.rectangle]).
  factory ShapeDecoration.fromBoxDecoration(BoxDecoration source) {
    ShapeBorder shape;
    assert(source.shape != null);
    switch (source.shape) {
      case BoxShape.circle:
        if (source.border != null) {
          assert(source.border.isUniform);
          shape = new CircleBorder(side: source.border.top);
        } else {
          shape = const CircleBorder();
        }
        break;
      case BoxShape.rectangle:
        if (source.borderRadius != null) {
          assert(source.border == null || source.border.isUniform);
          shape = new RoundedRectangleBorder(
            side: source.border?.top ?? BorderSide.none,
            borderRadius: source.borderRadius,
          );
        } else {
          shape = source.border ?? const Border();
        }
        break;
    }
    return new ShapeDecoration(
      color: source.color,
      image: source.image,
      gradient: source.gradient,
      shadows: source.boxShadow,
      shape: shape,
    );
  }

  /// The color to fill in the background of the shape.
  ///
  /// The color is under the [image].
  ///
  /// If a [gradient] is specified, [color] must be null.
  final Color color;

  /// A gradient to use when filling the shape.
  ///
  /// The gradient is under the [image].
  ///
  /// If a [color] is specified, [gradient] must be null.
  final Gradient gradient;

  /// An image to paint inside the shape (clipped to its outline).
  ///
  /// The image is drawn over the [color] or [gradient].
  final DecorationImage image;

  /// A list of shadows cast by this shape behind the shape.
  final List<BoxShadow> shadows;

  /// The shape to fill the [color], [gradient], and [image] into and to cast as
  /// the [shadows].
  ///
  /// Shapes can be stacked (using the `+` operator). The color, gradient, and
  /// image are drawn into the inner-most shape specified.
  ///
  /// The [shape] property specifies the outline (border) of the decoration. The
  /// shape must not be null.
  final ShapeBorder shape;

  /// The inset space occupied by the [shape]'s border.
  ///
  /// This value may be misleading. See the discussion at [ShapeBorder.dimensions].
  @override
  EdgeInsets get padding => shape.dimensions;

  @override
  bool get isComplex => shadows != null;

  @override
  ShapeDecoration lerpFrom(Decoration a, double t) {
    if (a is BoxDecoration) {
      return ShapeDecoration.lerp(new ShapeDecoration.fromBoxDecoration(a), this, t);
    } else if (a == null || a is ShapeDecoration) {
      return ShapeDecoration.lerp(a, this, t);
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeDecoration lerpTo(Decoration b, double t) {
    if (b is BoxDecoration) {
      return ShapeDecoration.lerp(this, new ShapeDecoration.fromBoxDecoration(b), t);
    } else if (b == null || b is ShapeDecoration) {
      return ShapeDecoration.lerp(this, b, t);
    }
    return super.lerpTo(b, t);
  }

  /// Linearly interpolate between two shapes.
  ///
  /// Interpolates each parameter of the decoration separately.
  ///
  /// If both values are null, this returns null. Otherwise, it returns a
  /// non-null value. If neither value is null and `t == 0.0`, then `a` is
  /// returned unmodified; if `t == 1.0` then `b` is returned unmodified.
  /// Otherwise, the values are computed by interpolating the properties
  /// appropriately, treating a null argument like a [ShapeDecoration] whose
  /// fields are all null (including the [shape], which cannot normally be
  /// null).
  ///
  /// See also:
  ///
  ///  * [Decoration.lerp], which can interpolate between any two types of
  ///    [Decoration]s, not just [ShapeDecoration]s.
  ///  * [lerpFrom] and [lerpTo], which are used to implement [Decoration.lerp]
  ///    and which use [ShapeDecoration.lerp] when interpolating two
  ///    [ShapeDecoration]s or a [ShapeDecoration] to or from null.
  static ShapeDecoration lerp(ShapeDecoration a, ShapeDecoration b, double t) {
    if (a == null && b == null)
      return null;
    if (a != null && b != null) {
      if (t == 0.0)
        return a;
      if (t == 1.0)
        return b;
    }
    return new ShapeDecoration(
      color: Color.lerp(a?.color, b?.color, t),
      gradient: Gradient.lerp(a?.gradient, b?.gradient, t),
      image: t < 0.5 ? a.image : b.image, // TODO(ianh): cross-fade the image
      shadows: BoxShadow.lerpList(a?.shadows, b?.shadows, t),
      shape: ShapeBorder.lerp(a?.shape, b?.shape, t),
    );
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other))
      return true;
    if (runtimeType != other.runtimeType)
      return false;
    final ShapeDecoration typedOther = other;
    return color == typedOther.color
        && gradient == typedOther.gradient
        && image == typedOther.image
        && shadows == typedOther.shadows
        && shape == typedOther.shape;
  }

  @override
  int get hashCode {
    return hashValues(
      color,
      gradient,
      image,
      shape,
      shadows,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.defaultDiagnosticsTreeStyle = DiagnosticsTreeStyle.whitespace;
    properties.add(new DiagnosticsProperty<Color>('color', color, defaultValue: null));
    properties.add(new DiagnosticsProperty<Gradient>('gradient', gradient, defaultValue: null));
    properties.add(new DiagnosticsProperty<DecorationImage>('image', image, defaultValue: null));
    properties.add(new IterableProperty<BoxShadow>('shadows', shadows, defaultValue: null, style: DiagnosticsTreeStyle.whitespace));
    properties.add(new DiagnosticsProperty<ShapeBorder>('shape', shape));
  }

  @override
  bool hitTest(Size size, Offset position, { TextDirection textDirection }) {
    return shape.getOuterPath(Offset.zero & size, textDirection: textDirection).contains(position);
  }

  @override
  _ShapeDecorationPainter createBoxPainter([VoidCallback onChanged]) {
    assert(onChanged != null || image == null);
    return new _ShapeDecorationPainter(this, onChanged);
  }
}

/// An object that paints a [ShapeDecoration] into a canvas.
class _ShapeDecorationPainter extends BoxPainter {
  _ShapeDecorationPainter(this._decoration, VoidCallback onChanged)
    : assert(_decoration != null),
      super(onChanged);

  final ShapeDecoration _decoration;

  Rect _lastRect;
  Path _outerPath;
  Path _innerPath;
  Paint _interiorPaint;
  int _shadowCount;
  List<Path> _shadowPaths;
  List<Paint> _shadowPaints;

  void _precache(Rect rect) {
    assert(rect != null);
    if (rect == _lastRect)
      return;
    // We reach here in two cases:
    //  - the very first time we paint, in which case everything except _decoration is null
    //  - subsequent times, if the rect has changed, in which case we only need to update
    //    the features that depend on the actual rect.
    if (_interiorPaint == null && (_decoration.color != null || _decoration.gradient != null)) {
      _interiorPaint = new Paint();
      if (_decoration.color != null)
        _interiorPaint.color = _decoration.color;
    }
    if (_decoration.gradient != null)
      _interiorPaint.shader = _decoration.gradient.createShader(rect);
    if (_decoration.shadows != null) {
      if (_shadowCount == null) {
        _shadowCount = _decoration.shadows.length;
        _shadowPaths = new List<Path>(_shadowCount);
        _shadowPaints = new List<Paint>(_shadowCount);
        for (int index = 0; index < _shadowCount; index += 1) {
          final BoxShadow shadow = _decoration.shadows[index];
          _shadowPaints[index] = new Paint()
            ..color = shadow.color
            ..maskFilter = new MaskFilter.blur(BlurStyle.normal, shadow.blurSigma);
        }
      }
      for (int index = 0; index < _shadowCount; index += 1) {
        final BoxShadow shadow = _decoration.shadows[index];
        _shadowPaths[index] = _decoration.shape.getOuterPath(rect.shift(shadow.offset).inflate(shadow.spreadRadius));
      }
    }
    if (_interiorPaint != null || _shadowCount != null)
      _outerPath = _decoration.shape.getOuterPath(rect);
    if (_decoration.image != null)
      _innerPath = _decoration.shape.getInnerPath(rect);
    _lastRect = rect;
  }

  void _paintShadows(Canvas canvas) {
    if (_shadowCount != null) {
      for (int index = 0; index < _shadowCount; index += 1)
        canvas.drawPath(_shadowPaths[index], _shadowPaints[index]);
    }
  }

  void _paintInterior(Canvas canvas) {
    if (_interiorPaint != null)
      canvas.drawPath(_outerPath, _interiorPaint);
  }

  DecorationImagePainter _imagePainter;
  void _paintImage(Canvas canvas, ImageConfiguration configuration) {
    if (_decoration.image == null)
      return;
    _imagePainter ??= _decoration.image.createPainter(onChanged);
    _imagePainter.paint(canvas, _lastRect, _innerPath, configuration);
  }

  @override
  void dispose() {
    _imagePainter?.dispose();
    super.dispose();
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    assert(configuration != null);
    assert(configuration.size != null);
    final Rect rect = offset & configuration.size;
    _precache(rect);
    _paintShadows(canvas);
    _paintInterior(canvas);
    _paintImage(canvas, configuration);
    _decoration.shape.paint(canvas, rect);
  }
}

// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui show Gradient, TextBox, lerpDouble;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'basic_types.dart';
import 'decoration.dart';
import 'fractional_offset.dart';
import 'image_fit.dart';
import 'text_editing.dart';
import 'text_painter.dart';
import 'text_span.dart';
import 'text_style.dart';

/// Possible ways to draw Flutter's logo.
enum FlutterLogoStyle {
  /// Show only Flutter's logo, not the "Flutter" label.
  ///
  /// This is the default behavior for [FlutterLogoDecoration] objects.
  markOnly,

  /// Show Flutter's logo on the left, and the "Flutter" label to its right.
  horizontal,

  /// Show Flutter's logo above the "Flutter" label.
  stacked,
}

const int _lightShade = 400;
const int _darkShade = 900;
const Map<int, Color> _kDefaultSwatch = const <int, Color>{
  _lightShade: const Color(0xFF42A5F5),
  _darkShade: const Color(0xFF0D47A1)
};

/// An immutable description of how to paint Flutter's logo.
class FlutterLogoDecoration extends Decoration {
  /// Creates a decoration that knows how to paint Flutter's logo.
  ///
  /// The [swatch] controls the color used for the logo. The [style] controls
  /// whether and where to draw the "Flutter" label. If one is shown, the
  /// [textColor] controls the color of the label.
  ///
  /// The [swatch], [textColor], and [style] arguments must not be null.
  const FlutterLogoDecoration({
    this.swatch: _kDefaultSwatch,
    this.textColor: const Color(0xFF616161),
    FlutterLogoStyle style: FlutterLogoStyle.markOnly,
    this.margin: EdgeInsets.zero,
  }) : style = style,
       _position = style == FlutterLogoStyle.markOnly ? 0.0 : style == FlutterLogoStyle.horizontal ? 1.0 : -1.0, // ignore: CONST_EVAL_TYPE_BOOL_NUM_STRING
       // (see https://github.com/dart-lang/sdk/issues/26980 for details about that ignore statement)
       _opacity = 1.0;

  FlutterLogoDecoration._(this.swatch, this.textColor, this.style, this._position, this._opacity, this.margin);

  /// The colors to use to paint the logo. This map should contain at least two
  /// values, one for 400 and one for 900.
  ///
  /// If possible, the default should be used. It corresponds to the
  /// [Colors.blue] swatch from the Material library.
  ///
  /// If for some reason that color scheme is impractical, the [Colors.amber],
  /// [Colors.red], or [Colors.indigo] swatches can be used. These are Flutter's
  /// secondary colors.
  ///
  /// In extreme cases where none of those four color schemes will work,
  /// [Colors.pink], [Colors.purple], or [Colors.cyan] swatches can be used.
  /// These are Flutter's tertiary colors.
  final Map<int, Color> swatch;

  /// The color used to paint the "Flutter" text on the logo, if [style] is
  /// [FlutterLogoStyle.horizontal] or [FlutterLogoStyle.stacked]. The
  /// appropriate color is `const Color(0xFF616161)` (a medium gray), against a
  /// white background.
  final Color textColor;

  /// Whether and where to draw the "Flutter" text. By default, only the logo
  /// itself is drawn.
  // This property isn't actually used when painting. It's only really used to
  // set the internal _position property.
  final FlutterLogoStyle style;

  // The following are set when lerping, to represent states that can't be
  // represented by the constructor.
  final double _position; // -1.0 for stacked, 1.0 for horizontal, 0.0 for no logo
  final double _opacity; // 0.0 .. 1.0

  /// How far to inset the logo from the edge of the container.
  final EdgeInsets margin;

  bool get _inTransition => _opacity != 1.0 || (_position != -1.0 && _position != 0.0 && _position != 1.0);

  @override
  bool debugAssertIsValid() {
    assert(swatch != null
        && swatch[_lightShade] != null
        && swatch[_darkShade] != null
        && textColor != null
        && style != null
        && _position != null
        && _position.isFinite
        && _opacity != null
        && _opacity >= 0.0
        && _opacity <= 1.0
        && margin != null);
    return true;
  }

  @override
  bool get isComplex => !_inTransition;

  /// Linearly interpolate between two Flutter logo descriptions.
  ///
  /// Interpolates both the color and the style in a continuous fashion.
  ///
  /// See also [Decoration.lerp].
  static FlutterLogoDecoration lerp(FlutterLogoDecoration a, FlutterLogoDecoration b, double t) {
    assert(a == null || a.debugAssertIsValid());
    assert(b == null || b.debugAssertIsValid());
    if (a == null && b == null)
      return null;
    if (a == null) {
      return new FlutterLogoDecoration._(
        b.swatch,
        b.textColor,
        b.style,
        b._position,
        b._opacity * t.clamp(0.0, 1.0),
        b.margin * t,
      );
    }
    if (b == null) {
      return new FlutterLogoDecoration._(
        a.swatch,
        a.textColor,
        a.style,
        a._position,
        a._opacity * (1.0 - t).clamp(0.0, 1.0),
        a.margin * t,
      );
    }
    return new FlutterLogoDecoration._(
      _lerpSwatch(a.swatch, b.swatch, t),
      Color.lerp(a.textColor, b.textColor, t),
      t < 0.5 ? a.style : b.style,
      a._position + (b._position - a._position) * t,
      (a._opacity + (b._opacity - a._opacity) * t).clamp(0.0, 1.0),
      EdgeInsets.lerp(a.margin, b.margin, t),
    );
  }

  static Map<int, Color> _lerpSwatch(Map<int, Color> a, Map<int, Color> b, double t) {
    assert(a != null);
    assert(b != null);
    return <int, Color>{
      _lightShade: Color.lerp(a[_lightShade], b[_lightShade], t),
      _darkShade: Color.lerp(a[_darkShade], b[_darkShade], t),
    };
  }

  @override
  FlutterLogoDecoration lerpFrom(Decoration a, double t) {
    assert(debugAssertIsValid());
    if (a is! FlutterLogoDecoration)
      return lerp(null, this, t);
    assert(a.debugAssertIsValid);
    return lerp(a, this, t);
  }

  @override
  FlutterLogoDecoration lerpTo(Decoration b, double t) {
    assert(debugAssertIsValid());
    if (b is! FlutterLogoDecoration)
      return lerp(this, null, t);
    assert(b.debugAssertIsValid());
    return lerp(this, b, t);
  }

  @override
  // TODO(ianh): better hit testing
  bool hitTest(Size size, Point position) => true;

  @override
  BoxPainter createBoxPainter([VoidCallback onChanged]) {
    assert(debugAssertIsValid());
    return new _FlutterLogoPainter(this);
  }

  @override
  bool operator ==(dynamic other) {
    assert(debugAssertIsValid());
    if (identical(this, other))
      return true;
    if (other is! FlutterLogoDecoration)
      return false;
    final FlutterLogoDecoration typedOther = other;
    return swatch[_lightShade] == typedOther.swatch[_lightShade]
        && swatch[_darkShade] == typedOther.swatch[_darkShade]
        && textColor == typedOther.textColor
        && _position == typedOther._position
        && _opacity == typedOther._opacity;
  }

  @override
  int get hashCode {
    assert(debugAssertIsValid());
    return hashValues(
      swatch[_lightShade],
      swatch[_darkShade],
      textColor,
      _position,
      _opacity
    );
  }

  @override
  String toString([String prefix = '']) {
    final String extra = _inTransition ? ', transition $_position:$_opacity' : '';
    if (swatch == null)
      return '$prefix$runtimeType(null, $style$extra)';
    return '$prefix$runtimeType(${swatch[_lightShade]}/${swatch[_darkShade]} on $textColor, $style$extra)';
  }
}


/// An object that paints a [BoxDecoration] into a canvas.
class _FlutterLogoPainter extends BoxPainter {
  _FlutterLogoPainter(this._config) : super(null) {
    assert(_config != null);
    assert(_config.debugAssertIsValid());
    _prepareText();
  }

  final FlutterLogoDecoration _config;

  // these are configured assuming a font size of 100.0.
  TextPainter _textPainter;
  Rect _textBoundingRect;

  void _prepareText() {
    const String kLabel = 'Flutter';
    _textPainter = new TextPainter(
      text: new TextSpan(
        text: kLabel,
        style: new TextStyle(
          color: _config.textColor,
          fontFamily: 'Roboto',
          fontSize: 100.0 * 350.0 / 247.0, // 247 is the height of the F when the fontSize is 350, assuming device pixel ratio 1.0
          fontWeight: FontWeight.w300,
          textBaseline: TextBaseline.alphabetic
        )
      )
    );
    _textPainter.layout();
    final ui.TextBox textSize = _textPainter.getBoxesForSelection(new TextSelection(baseOffset: 0, extentOffset: kLabel.length)).single;
    _textBoundingRect = new Rect.fromLTRB(textSize.left, textSize.top, textSize.right, textSize.bottom);
  }

  // This class contains a lot of magic numbers. They were derived from the
  // values in the SVG files exported from the original artwork source.

  void _paintLogo(Canvas canvas, Rect rect) {
    // Our points are in a coordinate space that's 166 pixels wide and 202 pixels high.
    // First, transform the rectangle so that our coordinate space is a square 202 pixels
    // to a side, with the top left at the origin.
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / 202.0, rect.height / 202.0);
    // Next, offset it some more so that the 166 horizontal pixels are centered
    // in that square (as opposed to being on the left side of it). This means
    // that if we draw in the rectangle from 0,0 to 166,202, we are drawing in
    // the center of the given rect.
    canvas.translate((202.0 - 166.0) / 2.0, 0.0);

    // Set up the styles.
    final Paint lightPaint = new Paint()
      ..color = _config.swatch[_lightShade].withOpacity(0.8);
    final Paint mediumPaint = new Paint()
      ..color = _config.swatch[_lightShade];
    final Paint darkPaint = new Paint()
      ..color = _config.swatch[_darkShade];

    final ui.Gradient triangleGradient = new ui.Gradient.linear(
      const <Point>[
        const Point(87.2623 + 37.9092, 28.8384 + 123.4389),
        const Point(42.9205 + 37.9092, 35.0952 + 123.4389),
      ],
      <Color>[
        const Color(0xBFFFFFFF),
        const Color(0xBFFCFCFC),
        const Color(0xBFF4F4F4),
        const Color(0xBFE5E5E5),
        const Color(0xBFD1D1D1),
        const Color(0xBFB6B6B6),
        const Color(0xBF959595),
        const Color(0xBF6E6E6E),
        const Color(0xBF616161),
      ],
      <double>[ 0.2690, 0.4093, 0.4972, 0.5708, 0.6364, 0.6968, 0.7533, 0.8058, 0.8219 ]
    );
    final Paint trianglePaint = new Paint()
      ..shader = triangleGradient
      ..transferMode = TransferMode.multiply;

    final ui.Gradient rectangleGradient = new ui.Gradient.linear(
      const <Point>[
        const Point(62.3643 + 37.9092, 40.135 + 123.4389),
        const Point(54.0376 + 37.9092, 31.8083 + 123.4389),
      ],
      <Color>[
        const Color(0x80FFFFFF),
        const Color(0x80FCFCFC),
        const Color(0x80F4F4F4),
        const Color(0x80E5E5E5),
        const Color(0x80D1D1D1),
        const Color(0x80B6B6B6),
        const Color(0x80959595),
        const Color(0x806E6E6E),
        const Color(0x80616161),
      ],
      <double>[ 0.4588, 0.5509, 0.6087, 0.6570, 0.7001, 0.7397, 0.7768, 0.8113, 0.8219 ],
    );
    final Paint rectanglePaint = new Paint()
      ..shader = rectangleGradient
      ..transferMode = TransferMode.multiply;

    // Draw the basic shape.
    final Path topBeam = new Path()
      ..moveTo(37.7, 128.9)
      ..lineTo(9.8, 101.0)
      ..lineTo(100.4, 10.4)
      ..lineTo(156.2, 10.4);
    canvas.drawPath(topBeam, lightPaint);

    final Path middleBeam = new Path()
      ..moveTo(156.2, 94.0)
      ..lineTo(100.4, 94.0)
      ..lineTo(79.5, 114.9)
      ..lineTo(107.4, 142.8);
    canvas.drawPath(middleBeam, lightPaint);

    final Path bottomBeam = new Path()
      ..moveTo(79.5, 170.7)
      ..lineTo(100.4, 191.6)
      ..lineTo(156.2, 191.6)
      ..lineTo(156.2, 191.6)
      ..lineTo(107.4, 142.8);
    canvas.drawPath(bottomBeam, darkPaint);

    canvas.save();
    canvas.transform(new Float64List.fromList(const <double>[
      // careful, this is in _column_-major order
      0.7071, -0.7071, 0.0, 0.0,
      0.7071, 0.7071, 0.0, 0.0,
      0.0, 0.0, 1.0, 0.0,
      -77.697, 98.057, 0.0, 1.0,
    ]));
    canvas.drawRect(new Rect.fromLTWH(59.8, 123.1, 39.4, 39.4), mediumPaint);
    canvas.restore();

    // The two gradients.
    final Path triangle = new Path()
      ..moveTo(79.5, 170.7)
      ..lineTo(120.9, 156.4)
      ..lineTo(107.4, 142.8);
    canvas.drawPath(triangle, trianglePaint);

    final Path rectangle = new Path()
      ..moveTo(107.4, 142.8)
      ..lineTo(79.5, 170.7)
      ..lineTo(86.1, 177.3)
      ..lineTo(114.0, 149.4);
    canvas.drawPath(rectangle, rectanglePaint);

    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    offset += _config.margin.topLeft;
    Size canvasSize = _config.margin.deflateSize(configuration.size);
    Size logoSize;
    if (_config._position > 0.0) {
      // horizontal style
      logoSize = const Size(820.0, 232.0);
    } else if (_config._position < 0.0) {
      // stacked style
      logoSize = const Size(252.0, 306.0);
    } else {
      // only the mark
      logoSize = const Size(202.0, 202.0);
    }
    final FittedSizes fittedSize = applyImageFit(ImageFit.contain, logoSize, canvasSize);
    assert(fittedSize.source == logoSize);
    final Rect rect = FractionalOffset.center.inscribe(fittedSize.destination, offset & canvasSize);
    final double centerSquareHeight = canvasSize.shortestSide;
    final Rect centerSquare = new Rect.fromLTWH(
      offset.dx + (canvasSize.width - centerSquareHeight) / 2.0,
      offset.dy + (canvasSize.height - centerSquareHeight) / 2.0,
      centerSquareHeight,
      centerSquareHeight
    );

    Rect logoTargetSquare;
    if (_config._position > 0.0) {
      // horizontal style
      logoTargetSquare = new Rect.fromLTWH(rect.left, rect.top, rect.height, rect.height);
    } else if (_config._position < 0.0) {
      // stacked style
      final double logoHeight = rect.height * 191.0 / 306.0;
      logoTargetSquare = new Rect.fromLTWH(
        rect.left + (rect.width - logoHeight) / 2.0,
        rect.top,
        logoHeight,
        logoHeight
      );
    } else {
      // only the mark
      logoTargetSquare = centerSquare;
    }
    final Rect logoSquare = Rect.lerp(centerSquare, logoTargetSquare, _config._position.abs());

    if (_config._opacity < 1.0) {
      canvas.saveLayer(
        offset & canvasSize,
        new Paint()
          ..colorFilter = new ColorFilter.mode(
            const Color(0xFFFFFFFF).withOpacity(_config._opacity),
            TransferMode.modulate,
          )
      );
    }
    if (_config._position != 0.0) {
      if (_config._position > 0.0) {
        // horizontal style
        final double fontSize = 2.0 / 3.0 * logoSquare.height * (1 - (10.4 * 2.0) / 202.0);
        final double scale = fontSize / 100.0;
        final double finalLeftTextPosition = // position of text in rest position
          (256.4 / 820.0) * rect.width - // 256.4 is the distance from the left edge to the left of the F when the whole logo is 820.0 wide
          (32.0 / 350.0) * fontSize; // 32 is the distance from the text bounding box edge to the left edge of the F when the font size is 350
        final double initialLeftTextPosition = // position of text when just starting the animation
          rect.width / 2.0 - _textBoundingRect.width * scale;
        final Offset textOffset = new Offset(
          rect.left + ui.lerpDouble(initialLeftTextPosition, finalLeftTextPosition, _config._position),
          rect.top + (rect.height - _textBoundingRect.height * scale) / 2.0
        );
        canvas.save();
        if (_config._position < 1.0) {
          final Point center = logoSquare.center;
          final Path path = new Path()
            ..moveTo(center.x, center.y)
            ..lineTo(center.x + rect.width, center.y - rect.width)
            ..lineTo(center.x + rect.width, center.y + rect.width)
            ..close();
          canvas.clipPath(path);
        }
        canvas.translate(textOffset.dx, textOffset.dy);
        canvas.scale(scale, scale);
        _textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      } else if (_config._position < 0.0) {
        // stacked style
        final double fontSize = 0.35 * logoTargetSquare.height * (1 - (10.4 * 2.0) / 202.0);
        final double scale = fontSize / 100.0;
        if (_config._position > -1.0) {
          canvas.saveLayer(_textBoundingRect, new Paint());
        } else {
          canvas.save();
        }
        canvas.translate(
          logoTargetSquare.center.x - (_textBoundingRect.width * scale / 2.0),
          logoTargetSquare.bottom
        );
        canvas.scale(scale, scale);
        _textPainter.paint(canvas, Offset.zero);
        if (_config._position > -1.0) {
          canvas.drawRect(_textBoundingRect.inflate(_textBoundingRect.width * 0.5), new Paint()
            ..transferMode = TransferMode.modulate
            ..shader = new ui.Gradient.linear(
              <Point>[new Point(_textBoundingRect.width * -0.5, 0.0), new Point(_textBoundingRect.width * 1.5, 0.0)],
              <Color>[const Color(0xFFFFFFFF), const Color(0xFFFFFFFF), const Color(0x00FFFFFF), const Color(0x00FFFFFF)],
              <double>[ 0.0, math.max(0.0, _config._position.abs() - 0.1), math.min(_config._position.abs() + 0.1, 1.0), 1.0 ],
            )
          );
        }
        canvas.restore();
      }
    }
    _paintLogo(canvas, logoSquare);
    if (_config._opacity < 1.0)
      canvas.restore();
  }
}

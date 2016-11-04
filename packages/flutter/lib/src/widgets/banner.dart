// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'basic.dart';
import 'framework.dart';

const double _kOffset = 40.0; // distance to bottom of banner, at a 45 degree angle inwards
const double _kHeight = 12.0; // height of banner
const double _kBottomOffset = _kOffset + 0.707 * _kHeight; // offset plus sqrt(2)/2 * banner height
final Rect _kRect = new Rect.fromLTWH(-_kOffset, _kOffset - _kHeight, _kOffset * 2.0, _kHeight);
const TextStyle _kTextStyles = const TextStyle(
  color: const Color(0xFFFFFFFF),
  fontSize: _kHeight * 0.85,
  fontWeight: FontWeight.w900,
  height: 1.0
);

/// Where to show a [Banner].
enum BannerLocation {
  /// Show the banner in the top right corner.
  topRight,

  /// Show the banner in the top left corner.
  topLeft,

  /// Show the banner in the bottom right corner.
  bottomRight,

  /// Show the banner in the bottom left corner.
  bottomLeft,
}

/// Paints a [Banner].
class BannerPainter extends CustomPainter {
  /// Creates a banner painter.
  ///
  /// The [message] and [location] arguments must not be null.
  const BannerPainter({
    @required this.message,
    @required this.location
  });

  /// The message to show in the banner.
  final String message;

  /// Where to show the banner (e.g., the upper right corder).
  final BannerLocation location;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paintShadow = new Paint()
      ..color = const Color(0x7F000000)
      ..maskFilter = new MaskFilter.blur(BlurStyle.normal, 4.0);
    final Paint paintBanner = new Paint()
      ..color = const Color(0xA0B71C1C);
    canvas
      ..translate(_translationX(size.width), _translationY(size.height))
      ..rotate(_rotation)
      ..drawRect(_kRect, paintShadow)
      ..drawRect(_kRect, paintBanner);

    final double width = _kOffset * 2.0;
    final TextPainter textPainter = new TextPainter(
      text: new TextSpan(style: _kTextStyles, text: message),
      textAlign: TextAlign.center
    )..layout(minWidth: width, maxWidth: width);

    textPainter.paint(canvas, _kRect.topLeft.toOffset() + new Offset(0.0, (_kRect.height - textPainter.height) / 2.0));
  }

  @override
  bool shouldRepaint(BannerPainter oldPainter) => false;

  @override
  bool hitTest(Point position) => false;

  double _translationX(double width) {
    switch (location) {
      case BannerLocation.bottomRight:
        return width - _kBottomOffset;
      case BannerLocation.topRight:
        return width;
      case BannerLocation.bottomLeft:
        return _kBottomOffset;
      case BannerLocation.topLeft:
        return 0.0;
    }
    assert(location != null);
    return null;
  }

  double _translationY(double height) {
    switch (location) {
      case BannerLocation.bottomRight:
      case BannerLocation.bottomLeft:
        return height - _kBottomOffset;
      case BannerLocation.topRight:
      case BannerLocation.topLeft:
        return 0.0;
    }
    assert(location != null);
    return null;
  }

  double get _rotation {
    switch (location) {
      case BannerLocation.bottomLeft:
      case BannerLocation.topRight:
        return math.PI / 4.0;
      case BannerLocation.bottomRight:
      case BannerLocation.topLeft:
        return -math.PI / 4.0;
    }
    assert(location != null);
    return null;
  }
}

/// Displays a diagonal message above the corner of another widget.
///
/// Useful for showing the execution mode of an app (e.g., that asserts are
/// enabled.)
///
/// See also:
///
///  * [CheckedModeBanner].
class Banner extends StatelessWidget {
  /// Creates a banner.
  ///
  /// The [message] and [location] arguments must not be null.
  Banner({
    Key key,
    this.child,
    this.message,
    this.location
  }) : super(key: key) {
    assert(message != null);
    assert(location != null);
  }

  /// The widget to show behind the banner.
  final Widget child;

  /// The message to show in the banner.
  final String message;

  /// Where to show the banner (e.g., the upper right corder).
  final BannerLocation location;

  @override
  Widget build(BuildContext context) {
    return new CustomPaint(
      foregroundPainter: new BannerPainter(message: message, location: location),
      child: child
    );
  }
}

/// Displays a [Banner] saying "SLOW MODE" when running in checked mode.
/// [MaterialApp] builds one of these by default.
/// Does nothing in release mode.
class CheckedModeBanner extends StatelessWidget {
  /// Creates a checked mode banner.
  CheckedModeBanner({
    Key key,
    this.child
  }) : super(key: key);

  /// The widget to show behind the banner.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget result = child;
    assert(() {
      result = new Banner(
        child: result,
        message: 'SLOW MODE',
        location: BannerLocation.topRight);
      return true;
    });
    return result;
  }
}

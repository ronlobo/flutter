// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'material.dart';

// TODO(eseidel): Draw width should vary based on device size:
// http://material.google.com/layout/structure.html#structure-side-nav

// Mobile:
// Width = Screen width − 56 dp
// Maximum width: 320dp
// Maximum width applies only when using a left nav. When using a right nav,
// the panel can cover the full width of the screen.

// Desktop/Tablet:
// Maximum width for a left nav is 400dp.
// The right nav can vary depending on content.

const double _kWidth = 304.0;
const double _kEdgeDragWidth = 20.0;
const double _kMinFlingVelocity = 365.0;
const Duration _kBaseSettleDuration = const Duration(milliseconds: 246);

/// A material design drawer.
///
/// Typically used in the [Scaffold.drawer] property, a drawer slides in from
/// the side of the screen and displays a list of items that the user can
/// interact with.
///
/// Typically, the child of the drawer is a [Block] whose first child is a
/// [DrawerHeader] that displays status information about the current user.
///
/// The [Scaffold] automatically shows an appropriate [IconButton], and handles
/// the edge-swipe gesture, to show the drawer.
///
/// See also:
///
///  * [Scaffold.drawer], where one specifies a [Drawer] so that it can be
///    shown.
///  * [Scaffold.of], to obtain the current [ScaffoldState], which manages the
///    display and animation of the drawer.
///  * [ScaffoldState.openDrawer], which displays its [Drawer], if any.
///  * [Navigator.pop], which closes the drawer if it is open.
///  * [DrawerItem], a widget for items in drawers.
///  * [DrawerHeader], a widget for the top part of a drawer.
///  * <https://material.google.com/patterns/navigation-drawer.html>
class Drawer extends StatelessWidget {
  /// Creates a material design drawer.
  ///
  /// Typically used in the [Scaffold.drawer] property.
  Drawer({
    Key key,
    this.elevation: 16,
    this.child
  }) : super(key: key);

  /// The z-coordinate at which to place this drawer.
  ///
  /// The following elevations have defined shadows: 1, 2, 3, 4, 6, 8, 9, 12, 16, 24
  ///
  /// Defaults to 16, the appropriate elevation for drawers.
  final int elevation;

  /// The widget below this widget in the tree.
  ///
  /// Typically a [Block].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return new ConstrainedBox(
      constraints: const BoxConstraints.expand(width: _kWidth),
      child: new Material(
        elevation: elevation,
        child: child
      )
    );
  }
}

/// Provides interactive behavior for [Drawer] widgets.
///
/// Rarely used directly. Drawer controllers are typically created automatically
/// by [Scaffold] widgets.
///
/// The draw controller provides the ability to open and close a drawer, either
/// via an animation or via user interaction. When closed, the drawer collapses
/// to a translucent gesture detector that can be used to listen for edge
/// swipes.
///
/// See also:
///
///  * [Drawer]
///  * [Scaffold.drawer]
class DrawerController extends StatefulWidget {
  /// Creates a controller for a [Drawer].
  ///
  /// Rarely used directly.
  ///
  /// The [child] argument must not be null and is typically a [Drawer].
  DrawerController({
    GlobalKey key,
    this.child
  }) : super(key: key) {
    assert(child != null);
  }

  /// The widget below this widget in the tree.
  ///
  /// Typically a [Drawer].
  final Widget child;

  @override
  DrawerControllerState createState() => new DrawerControllerState();
}

/// State for a [DrawerController].
///
/// Typically used by a [Scaffold] to [open] and [close] the drawer.
class DrawerControllerState extends State<DrawerController> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _controller = new AnimationController(duration: _kBaseSettleDuration, vsync: this)
      ..addListener(_animationChanged)
      ..addStatusListener(_animationStatusChanged);
  }

  @override
  void dispose() {
    _historyEntry?.remove();
    _controller
      ..removeListener(_animationChanged)
      ..removeStatusListener(_animationStatusChanged)
      ..stop();
    super.dispose();
  }

  void _animationChanged() {
    setState(() {
      // The animation controller's state is our build state, and it changed already.
    });
  }

  LocalHistoryEntry _historyEntry;
  // TODO(abarth): This should be a GlobalValueKey when those exist.
  GlobalKey get _drawerKey => new GlobalObjectKey(config.key);

  void _ensureHistoryEntry() {
    if (_historyEntry == null) {
      ModalRoute<dynamic> route = ModalRoute.of(context);
      if (route != null) {
        _historyEntry = new LocalHistoryEntry(onRemove: _handleHistoryEntryRemoved);
        route.addLocalHistoryEntry(_historyEntry);
        Focus.moveScopeTo(_drawerKey, context: context);
      }
    }
  }

  void _animationStatusChanged(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
        _ensureHistoryEntry();
        break;
      case AnimationStatus.reverse:
        _historyEntry?.remove();
        _historyEntry = null;
        break;
      case AnimationStatus.dismissed:
        break;
      case AnimationStatus.completed:
        break;
    }
  }

  void _handleHistoryEntryRemoved() {
    _historyEntry = null;
    close();
  }

  AnimationController _controller;

  void _handleDragDown(DragDownDetails details) {
    _controller.stop();
    _ensureHistoryEntry();
  }

  void _handleDragCancel() {
    if (_controller.isDismissed || _controller.isAnimating)
      return;
    if (_controller.value < 0.5) {
      close();
    } else {
      open();
    }
  }

  double get _width {
    RenderBox drawerBox = _drawerKey.currentContext?.findRenderObject();
    if (drawerBox != null)
      return drawerBox.size.width;
    return _kWidth; // drawer not being shown currently
  }

  void _move(DragUpdateDetails details) {
    _controller.value += details.primaryDelta / _width;
  }

  void _settle(DragEndDetails details) {
    if (_controller.isDismissed)
      return;
    if (details.velocity.pixelsPerSecond.dx.abs() >= _kMinFlingVelocity) {
      _controller.fling(velocity: details.velocity.pixelsPerSecond.dx / _width);
    } else if (_controller.value < 0.5) {
      close();
    } else {
      open();
    }
  }

  /// Starts an animation to open the drawer.
  ///
  /// Typically called by [Scaffold.openDrawer].
  void open() {
    _controller.fling(velocity: 1.0);
  }

  /// Starts an animation to close the drawer.
  void close() {
    _controller.fling(velocity: -1.0);
  }

  final ColorTween _color = new ColorTween(begin: Colors.transparent, end: Colors.black54);
  final GlobalKey _gestureDetectorKey = new GlobalKey();

  @override
  Widget build(BuildContext context) {
    if (_controller.status == AnimationStatus.dismissed) {
      return new Align(
        alignment: FractionalOffset.centerLeft,
        child: new GestureDetector(
          key: _gestureDetectorKey,
          onHorizontalDragUpdate: _move,
          onHorizontalDragEnd: _settle,
          behavior: HitTestBehavior.translucent,
          excludeFromSemantics: true,
          child: new Container(width: _kEdgeDragWidth)
        )
      );
    } else {
      return new GestureDetector(
        key: _gestureDetectorKey,
        onHorizontalDragDown: _handleDragDown,
        onHorizontalDragUpdate: _move,
        onHorizontalDragEnd: _settle,
        onHorizontalDragCancel: _handleDragCancel,
        child: new RepaintBoundary(
          child: new Stack(
            children: <Widget>[
              new GestureDetector(
                onTap: close,
                child: new DecoratedBox(
                  decoration: new BoxDecoration(
                    backgroundColor: _color.evaluate(_controller)
                  ),
                  child: new Container()
                )
              ),
              new Align(
                alignment: FractionalOffset.centerLeft,
                child: new Align(
                  alignment: FractionalOffset.centerRight,
                  widthFactor: _controller.value,
                  child: new RepaintBoundary(
                    child: new Focus(
                      key: _drawerKey,
                      child: config.child
                    )
                  )
                )
              )
            ]
          )
        )
      );
    }
  }
}

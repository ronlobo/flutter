// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'colors.dart';
import 'debug.dart';
import 'icon.dart';
import 'icons.dart';
import 'ink_well.dart';
import 'scrollbar.dart';
import 'shadows.dart';
import 'theme.dart';
import 'material.dart';

const Duration _kDropdownMenuDuration = const Duration(milliseconds: 300);
const double _kMenuItemHeight = 48.0;
const EdgeInsets _kMenuVerticalPadding = const EdgeInsets.symmetric(vertical: 8.0);
const EdgeInsets _kMenuHorizontalPadding = const EdgeInsets.symmetric(horizontal: 16.0);

class _DropdownMenuPainter extends CustomPainter {
  _DropdownMenuPainter({
    Color color,
    int elevation,
    this.selectedIndex,
    Animation<double> resize
  }) : color = color,
       elevation = elevation,
       resize = resize,
       _painter = new BoxDecoration(
         // If you add a background image here, you must provide a real
         // configuration in the paint() function and you must provide some sort
         // of onChanged callback here.
         backgroundColor: color,
         borderRadius: new BorderRadius.circular(2.0),
         boxShadow: kElevationToShadow[elevation]
       ).createBoxPainter(),
       super(repaint: resize);

  final Color color;
  final int elevation;
  final int selectedIndex;
  final Animation<double> resize;

  final BoxPainter _painter;

  @override
  void paint(Canvas canvas, Size size) {
    final Tween<double> top = new Tween<double>(
      begin: (selectedIndex * _kMenuItemHeight + _kMenuVerticalPadding.top).clamp(0.0, size.height - _kMenuItemHeight),
      end: 0.0
    );

    final Tween<double> bottom = new Tween<double>(
      begin: (top.begin + _kMenuItemHeight).clamp(_kMenuItemHeight, size.height),
      end: size.height
    );

    final Rect rect = new Rect.fromLTRB(0.0, top.evaluate(resize), size.width, bottom.evaluate(resize));

    _painter.paint(canvas, rect.topLeft.toOffset(), new ImageConfiguration(size: rect.size));
  }

  @override
  bool shouldRepaint(_DropdownMenuPainter oldPainter) {
    return oldPainter.color != color
        || oldPainter.elevation != elevation
        || oldPainter.selectedIndex != selectedIndex
        || oldPainter.resize != resize;
  }
}

// Do not use the platform-specific default scroll configuration.
// Dropdown menus should never overscroll or display an overscroll indicator.
class _DropdownScrollConfigurationDelegate extends ScrollConfigurationDelegate {
  const _DropdownScrollConfigurationDelegate(this._platform);

  @override
  TargetPlatform get platform => _platform;
  final TargetPlatform _platform;

  @override
  ExtentScrollBehavior createScrollBehavior() => new OverscrollWhenScrollableBehavior(platform: platform);

  @override
  Widget wrapScrollWidget(BuildContext context, Widget scrollWidget) {
    return new ClampOverscrolls(edge: ScrollableEdge.both, child: scrollWidget);
  }

  @override
  bool updateShouldNotify(ScrollConfigurationDelegate old) => platform != old.platform;
}

class _DropdownMenu<T> extends StatefulWidget {
  _DropdownMenu({
    Key key,
    _DropdownRoute<T> route
  }) : route = route, super(key: key);

  final _DropdownRoute<T> route;

  @override
  _DropdownMenuState<T> createState() => new _DropdownMenuState<T>();
}

class _DropdownMenuState<T> extends State<_DropdownMenu<T>> {
  CurvedAnimation _fadeOpacity;
  CurvedAnimation _resize;

  @override
  void initState() {
    super.initState();
    // We need to hold these animations as state because of their curve
    // direction. When the route's animation reverses, if we were to recreate
    // the CurvedAnimation objects in build, we'd lose
    // CurvedAnimation._curveDirection.
    _fadeOpacity = new CurvedAnimation(
      parent: config.route.animation,
      curve: const Interval(0.0, 0.25),
      reverseCurve: const Interval(0.75, 1.0)
    );
    _resize = new CurvedAnimation(
      parent: config.route.animation,
      curve: const Interval(0.25, 0.5),
      reverseCurve: const Threshold(0.0)
    );
  }

  @override
  Widget build(BuildContext context) {
    // The menu is shown in three stages (unit timing in brackets):
    // [0s - 0.25s] - Fade in a rect-sized menu container with the selected item.
    // [0.25s - 0.5s] - Grow the otherwise empty menu container from the center
    //   until it's big enough for as many items as we're going to show.
    // [0.5s - 1.0s] Fade in the remaining visible items from top to bottom.
    //
    // When the menu is dismissed we just fade the entire thing out
    // in the first 0.25s.
    final _DropdownRoute<T> route = config.route;
    final double unit = 0.5 / (route.items.length + 1.5);
    final List<Widget> children = <Widget>[];
    for (int itemIndex = 0; itemIndex < route.items.length; ++itemIndex) {
      CurvedAnimation opacity;
      if (itemIndex == route.selectedIndex) {
        opacity = new CurvedAnimation(parent: route.animation, curve: const Threshold(0.0));
      } else {
        final double start = (0.5 + (itemIndex + 1) * unit).clamp(0.0, 1.0);
        final double end = (start + 1.5 * unit).clamp(0.0, 1.0);
        opacity = new CurvedAnimation(parent: route.animation, curve: new Interval(start, end));
      }
      children.add(new FadeTransition(
        opacity: opacity,
        child: new InkWell(
          child: new Container(
            padding: _kMenuHorizontalPadding,
            child: route.items[itemIndex]
          ),
          onTap: () => Navigator.pop(
            context,
            new _DropdownRouteResult<T>(route.items[itemIndex].value)
          )
        )
      ));
    }

    return new FadeTransition(
      opacity: _fadeOpacity,
      child: new CustomPaint(
        painter: new _DropdownMenuPainter(
          color: Theme.of(context).canvasColor,
          elevation: route.elevation,
          selectedIndex: route.selectedIndex,
          resize: _resize
        ),
        child: new Material(
          type: MaterialType.transparency,
          textStyle: route.style,
          child: new ScrollConfiguration(
            delegate: new _DropdownScrollConfigurationDelegate(Theme.of(context).platform),
            child: new Scrollbar(
              child: new ScrollableList(
                scrollableKey: config.route.scrollableKey,
                padding: _kMenuVerticalPadding,
                itemExtent: _kMenuItemHeight,
                children: children
              )
            )
          )
        )
      )
    );
  }
}

class _DropdownMenuRouteLayout<T> extends SingleChildLayoutDelegate {
  _DropdownMenuRouteLayout({ this.route });

  final _DropdownRoute<T> route;

  Rect get buttonRect => route.buttonRect;
  int get selectedIndex => route.selectedIndex;
  GlobalKey<ScrollableState> get scrollableKey => route.scrollableKey;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // The maximum height of a simple menu should be one or more rows less than
    // the view height. This ensures a tappable area outside of the simple menu
    // with which to dismiss the menu.
    //   -- https://material.google.com/components/menus.html#menus-simple-menus
    final double maxHeight = math.max(0.0, constraints.maxHeight - 2 * _kMenuItemHeight);
    final double width = buttonRect.width + 8.0;
    return new BoxConstraints(
      minWidth: width,
      maxWidth: width,
      minHeight: 0.0,
      maxHeight: maxHeight
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double buttonTop = buttonRect.top;
    final double selectedItemOffset = selectedIndex * _kMenuItemHeight + _kMenuVerticalPadding.top;
    double top = buttonTop - selectedItemOffset;
    final double topPreferredLimit = _kMenuItemHeight;
    if (top < topPreferredLimit)
      top = math.min(buttonTop, topPreferredLimit);
    double bottom = top + childSize.height;
    final double bottomPreferredLimit = size.height - _kMenuItemHeight;
    if (bottom > bottomPreferredLimit) {
      bottom = math.max(buttonTop + _kMenuItemHeight, bottomPreferredLimit);
      top = bottom - childSize.height;
    }
    assert(() {
      final Rect container = Point.origin & size;
      if (container.intersect(buttonRect) == buttonRect) {
        // If the button was entirely on-screen, then verify
        // that the menu is also on-screen.
        // If the button was a bit off-screen, then, oh well.
        assert(top >= 0.0);
        assert(top + childSize.height <= size.height);
      }
      return true;
    });

    if (route.initialLayout) {
      route.initialLayout = false;
      final double scrollOffset = selectedItemOffset - (buttonTop - top);
      SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
        // TODO(ianh): Compute and set this during layout instead of being
        // lagged by one frame. https://github.com/flutter/flutter/issues/5751
        scrollableKey.currentState.scrollTo(scrollOffset);
      });
    }

    return new Offset(buttonRect.left, top);
  }

  @override
  bool shouldRelayout(_DropdownMenuRouteLayout<T> oldDelegate) => oldDelegate.route != route;
}

// We box the return value so that the return value can be null. Otherwise,
// canceling the route (which returns null) would get confused with actually
// returning a real null value.
class _DropdownRouteResult<T> {
  const _DropdownRouteResult(this.result);

  final T result;

  @override
  bool operator ==(dynamic other) {
    if (other is! _DropdownRouteResult<T>)
      return false;
    final _DropdownRouteResult<T> typedOther = other;
    return result == typedOther.result;
  }

  @override
  int get hashCode => result.hashCode;
}

class _DropdownRoute<T> extends PopupRoute<_DropdownRouteResult<T>> {
  _DropdownRoute({
    this.items,
    this.buttonRect,
    this.selectedIndex,
    this.elevation: 8,
    this.theme,
    this.style,
  }) {
    assert(style != null);
  }

  final GlobalKey<ScrollableState> scrollableKey = new GlobalKey<ScrollableState>(debugLabel: '_DropdownMenu');
  final List<DropdownMenuItem<T>> items;
  final Rect buttonRect;
  final int selectedIndex;
  final int elevation;
  final ThemeData theme;
  final TextStyle style;

  // The layout gets this route's scrollableKey so that it can scroll the
  /// selected item into position, but only on the initial layout.
  bool initialLayout = true;

  @override
  Duration get transitionDuration => _kDropdownMenuDuration;

  @override
  bool get barrierDismissable => true;

  @override
  Color get barrierColor => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> forwardAnimation) {
    Widget menu = new _DropdownMenu<T>(route: this);
    if (theme != null)
      menu = new Theme(data: theme, child: menu);

    return new CustomSingleChildLayout(
      delegate: new _DropdownMenuRouteLayout<T>(route: this),
      child: menu,
    );
  }
}

/// An item in a menu created by a [DropdownButton].
///
/// The type `T` is the type of the value the entry represents. All the entries
/// in a given menu must represent values with consistent types.
class DropdownMenuItem<T> extends StatelessWidget {
  /// Creates an item for a dropdown menu.
  ///
  /// The [child] argument is required.
  DropdownMenuItem({
    Key key,
    this.value,
    this.child
  }) : super(key: key) {
    assert(child != null);
  }

  /// The widget below this widget in the tree.
  ///
  /// Typically a [Text] widget.
  final Widget child;

  /// The value to return if the user selects this menu item.
  ///
  /// Eventually returned in a call to [DropdownButton.onChanged].
  final T value;

  @override
  Widget build(BuildContext context) {
    return new Container(
      height: _kMenuItemHeight,
      alignment: FractionalOffset.centerLeft,
      child: child
    );
  }
}

/// An inherited widget that causes any descendant [DropdownButton]
/// widgets to not include their regular underline.
///
/// This is used by [DataTable] to remove the underline from any
/// [DropdownButton] widgets placed within material data tables, as
/// required by the material design specification.
class DropdownButtonHideUnderline extends InheritedWidget {
  /// Creates a [DropdownButtonHideUnderline]. A non-null [child] must
  /// be given.
  DropdownButtonHideUnderline({
    Key key,
    Widget child
  }) : super(key: key, child: child) {
    assert(child != null);
  }

  /// Returns whether the underline of [DropdownButton] widgets should
  /// be hidden.
  static bool at(BuildContext context) {
    return context.inheritFromWidgetOfExactType(DropdownButtonHideUnderline) != null;
  }

  @override
  bool updateShouldNotify(DropdownButtonHideUnderline old) => false;
}

/// A material design button for selecting from a list of items.
///
/// A dropdown button lets the user select from a number of items. The button
/// shows the currently selected item as well as an arrow that opens a menu for
/// selecting another item.
///
/// Requires one of its ancestors to be a [Material] widget.
///
/// See also:
///
///  * [RaisedButton]
///  * [FlatButton]
///  * <https://material.google.com/components/buttons.html#buttons-dropdown-buttons>
class DropdownButton<T> extends StatefulWidget {
  /// Creates a dropdown button.
  ///
  /// The [items] must have distinct values and [value] must be among them.
  ///
  /// The [elevation] and [iconSize] arguments must not be null (they both have
  /// defaults, so do not need to be specified).
  DropdownButton({
    Key key,
    @required this.items,
    @required this.value,
    @required this.onChanged,
    this.elevation: 8,
    this.style,
    this.iconSize: 24.0
  }) : super(key: key) {
    assert(items != null);
    assert(items.where((DropdownMenuItem<T> item) => item.value == value).length == 1);
  }

  /// The list of possible items to select among.
  final List<DropdownMenuItem<T>> items;

  /// The currently selected item.
  final T value;

  /// Called when the user selects an item.
  final ValueChanged<T> onChanged;

  /// The z-coordinate at which to place the menu when open.
  ///
  /// The following elevations have defined shadows: 1, 2, 3, 4, 6, 8, 9, 12, 16, 24
  ///
  /// Defaults to 8, the appropriate elevation for dropdown buttons.
  final int elevation;

  /// The text style to use for text in the dropdown button and the dropdown
  /// menu that appears when you tap the button.
  ///
  /// Defaults to the [TextTheme.subhead] value of the current
  /// [ThemeData.textTheme] of the current [Theme].
  final TextStyle style;

  /// The size to use for the drop-down button's down arrow icon button.
  ///
  /// Defaults to 24.0.
  final double iconSize;

  @override
  _DropdownButtonState<T> createState() => new _DropdownButtonState<T>();
}

class _DropdownButtonState<T> extends State<DropdownButton<T>> {
  @override
  void initState() {
    super.initState();
    _updateSelectedIndex();
    assert(_selectedIndex != null);
  }

  @override
  void didUpdateConfig(DropdownButton<T> oldConfig) {
    if (config.items[_selectedIndex].value != config.value)
      _updateSelectedIndex();
  }

  int _selectedIndex;

  void _updateSelectedIndex() {
    for (int itemIndex = 0; itemIndex < config.items.length; itemIndex++) {
      if (config.items[itemIndex].value == config.value) {
        _selectedIndex = itemIndex;
        return;
      }
    }
  }

  TextStyle get _textStyle => config.style ?? Theme.of(context).textTheme.subhead;

  void _handleTap() {
    final RenderBox itemBox = context.findRenderObject();
    final Rect itemRect = itemBox.localToGlobal(Point.origin) & itemBox.size;
    Navigator.push(context, new _DropdownRoute<T>(
      items: config.items,
      buttonRect: _kMenuHorizontalPadding.inflateRect(itemRect),
      selectedIndex: _selectedIndex,
      elevation: config.elevation,
      theme: Theme.of(context, shadowThemeOnly: true),
      style: _textStyle,
    )).then((_DropdownRouteResult<T> newValue) {
      if (!mounted || newValue == null)
        return;
      if (config.onChanged != null)
        config.onChanged(newValue.result);
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    Widget result = new DefaultTextStyle(
      style: _textStyle,
      child: new Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // We use an IndexedStack to make sure we have enough width to show any
          // possible item as the selected item without changing size.
          new IndexedStack(
            index: _selectedIndex,
            alignment: FractionalOffset.centerLeft,
            children: config.items
          ),
          new Icon(Icons.arrow_drop_down,
            size: config.iconSize,
            // These colors are not defined in the Material Design spec.
            color: Theme.of(context).brightness == Brightness.light ? Colors.grey[700] : Colors.white70
          )
        ]
      )
    );

    if (!DropdownButtonHideUnderline.at(context)) {
      result = new Stack(
        children: <Widget>[
          result,
          new Positioned(
            left: 0.0,
            right: 0.0,
            bottom: 8.0,
            child: new Container(
              height: 1.0,
              decoration: const BoxDecoration(
                border: const Border(bottom: const BorderSide(color: const Color(0xFFBDBDBD), width: 0.0))
              )
            )
          )
        ]
      );
    }

    return new GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: result
    );
  }
}

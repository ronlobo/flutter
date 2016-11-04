// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'button.dart';
import 'colors.dart';
import 'debug.dart';
import 'flat_button.dart';
import 'icon.dart';
import 'icons.dart';
import 'ink_well.dart';
import 'material.dart';
import 'theme.dart';
import 'typography.dart';

// TODO(dragostis): Missing functionality:
//   * mobile horizontal mode with adding/removing steps
//   * alternative labeling
//   * stepper feedback in the case of high-latency interactions

/// The state of a [Step] which is used to control the style of the circle and
/// text.
///
/// See also:
///
///  * [Step]
enum StepState {
  /// A step that displays its index in its circle.
  indexed,
  /// A step that displays a pencil icon in its circle.
  editing,
  /// A step that displays a tick icon in its circle.
  complete,
  /// A step that is disabled and does not to react to taps.
  disabled,
  /// A step that is currently having an error. e.g. the use has submitted wrong
  /// input.
  error
}

/// Defines the [Stepper]'s main axis.
enum StepperType {
  /// A vertical layout of the steps with their content in-between the titles.
  vertical,
  /// A horizontal layout of the steps with their content below the titles.
  horizontal
}

const TextStyle _kStepStyle = const TextStyle(
  fontSize: 12.0,
  color: Colors.white
);
final Color _kErrorLight = Colors.red[500];
final Color _kErrorDark = Colors.red[400];
const Color _kCircleActiveLight = Colors.white;
const Color _kCircleActiveDark = Colors.black87;
const Color _kDisabledLight = Colors.black38;
const Color _kDisabledDark = Colors.white30;
const double _kStepSize = 24.0;
const double _kTriangleHeight = _kStepSize * 0.866025; // Traingle height. sqrt(3.0) / 2.0

/// A material step used in [Stepper]. The step can have a title and subtitle,
/// an icon within its circle, some content and a state that governs its
/// styling.
///
/// See also:
///
///  * [Stepper]
///  * <https://material.google.com/components/steppers.html>
class Step {
  /// Creates a step for a [Stepper].
  ///
  /// The [title], [content], and [state] arguments must not be null.
  Step({
    @required this.title,
    this.subtitle,
    @required this.content,
    this.state: StepState.indexed,
    this.isActive: false
  }) {
    assert(this.title != null);
    assert(this.content != null);
    assert(this.state != null);
  }

  /// The title of the step that typically describes it.
  final Widget title;

  /// The subtitle of the step that appears below the title and has a smaller
  /// font size. It typically gives more details that complement the title.
  ///
  /// If null, the subtitle is not shown.
  final Widget subtitle;

  /// The content of the step that appears below the [title] and [subtitle].
  ///
  /// Below the content, every step has a 'continue' and 'cancel' button.
  final Widget content;

  /// The state of the step which determines the styling of its componenents
  /// and whether steps are interactive.
  final StepState state;

  /// Whether or not the step is active. The flag only influences styling.
  final bool isActive;
}

/// A material stepper widget that displays progress through a sequence of
/// steps. Steppers are particularly useful in the case of forms where one step
/// requires the completion of another one, or where multiple steps need to be
/// completed in order to submit the whole form.
///
/// The widget is a flexible wrapper. A parent class should pass [currentStep]
/// to this widget based on some logic triggered by the three callbacks that it
/// provides.
///
/// See also:
///
///  * [Step]
///  * <https://material.google.com/components/steppers.html>
class Stepper extends StatefulWidget {
  /// Creates a stepper from a list of steps.
  ///
  /// This widget is not meant to be rebuilt with a different list of steps
  /// unless a key is provided in order to distinguish the old stepper from the
  /// new one.
  ///
  /// The [steps], [type], and [currentStep] arguments must not be null.
  Stepper({
    Key key,
    this.steps,
    this.type: StepperType.vertical,
    this.currentStep: 0,
    this.onStepTapped,
    this.onStepContinue,
    this.onStepCancel
  }) : super(key: key) {
    assert(this.steps != null);
    assert(this.type != null);
    assert(this.currentStep != null);
    assert(0 <= currentStep && currentStep < this.steps.length);
  }

  /// The steps of the stepper whose titles, subtitles, icons always get shown.
  ///
  /// The length of [steps] must not change.
  final List<Step> steps;

  /// The type of stepper that determines the layout. In the case of
  /// [StepperType.horizontal], the content of the current step is displayed
  /// underneath as opposed to the [StepperType.vertical] case where it is
  /// displayed in-between.
  final StepperType type;

  /// The index into [steps] of the current step whose content is displayed.
  final int currentStep;

  /// The callback called when a step is tapped, with its index passed as
  /// an argument.
  final ValueChanged<int> onStepTapped;

  /// The callback called when the 'continue' button is tapped.
  ///
  /// If null, the 'continue' button will be disabled.
  final VoidCallback onStepContinue;

  /// The callback called when the 'cancel' button is tapped.
  ///
  /// If null, the 'cancel' button will be disabled.
  final VoidCallback onStepCancel;

  @override
  _StepperState createState() => new _StepperState();
}

class _StepperState extends State<Stepper> with TickerProviderStateMixin {
  List<GlobalKey> _keys;
  final Map<int, StepState> _oldStates = new Map<int, StepState>();

  @override
  void initState() {
    super.initState();
    _keys = new List<GlobalKey>.generate(
      config.steps.length,
      (int i) => new GlobalKey()
    );

    for (int i = 0; i < config.steps.length; i += 1)
      _oldStates[i] = config.steps[i].state;
  }

  @override
  void didUpdateConfig(Stepper oldConfig) {
    super.didUpdateConfig(oldConfig);
    assert(config.steps.length == oldConfig.steps.length);

    for (int i = 0; i < oldConfig.steps.length; i += 1)
      _oldStates[i] = oldConfig.steps[i].state;
  }

  bool _isFirst(int index) {
    return index == 0;
  }

  bool _isLast(int index) {
    return config.steps.length - 1 == index;
  }

  bool _isCurrent(int index) {
    return config.currentStep == index;
  }

  bool _isDark() {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Widget _buildLine(bool visible) {
    return new Container(
      width: visible ? 1.0 : 0.0,
      height: 16.0,
      decoration: new BoxDecoration(
        backgroundColor: Colors.grey[400]
      )
    );
  }

  Widget _buildCircleChild(int index, bool oldState) {
    final StepState state = oldState ? _oldStates[index] : config.steps[index].state;
    final bool isDarkActive = _isDark() && config.steps[index].isActive;
    assert(state != null);
    switch (state) {
      case StepState.indexed:
      case StepState.disabled:
        return new Text(
          '${index + 1}',
          style: isDarkActive ? _kStepStyle.copyWith(color: Colors.black87) : _kStepStyle
        );
      case StepState.editing:
        return new Icon(
          Icons.edit,
          color: isDarkActive ? _kCircleActiveDark : _kCircleActiveLight
        );
      case StepState.complete:
        return new Icon(
          Icons.check,
          color: isDarkActive ? _kCircleActiveDark : _kCircleActiveLight
        );
      case StepState.error:
        return new Text('!', style: _kStepStyle);
    }
    return null;
  }

  Color _circleColor(int index) {
    final ThemeData themeData = Theme.of(context);
    if (!_isDark()) {
      return config.steps[index].isActive ? themeData.primaryColor : Colors.black38;
    } else {
      return config.steps[index].isActive ? themeData.accentColor : themeData.backgroundColor;
    }
  }

  Widget _buildCircle(int index, bool oldState) {
    return new Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      width: _kStepSize,
      height: _kStepSize,
      child: new AnimatedContainer(
        curve: Curves.fastOutSlowIn,
        duration: kThemeAnimationDuration,
        decoration: new BoxDecoration(
          backgroundColor: _circleColor(index),
          shape: BoxShape.circle
        ),
        child: new Center(
          child: _buildCircleChild(index, oldState && config.steps[index].state == StepState.error)
        )
      )
    );
  }

  Widget _buildTriangle(int index, bool oldState) {
    return new Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      width: _kStepSize,
      height: _kStepSize,
      child: new Center(
        child: new SizedBox(
          width: _kStepSize,
          height: _kTriangleHeight, // Height of 24dp-long-sided equilateral triangle.
          child: new CustomPaint(
            painter: new _TrianglePainter(
              color: _isDark() ? _kErrorDark : _kErrorLight
            ),
            child: new Align(
              alignment: const FractionalOffset(0.5, 0.9), // 0.9 looks better than the geometrical 0.66.
              child: _buildCircleChild(index, oldState && config.steps[index].state != StepState.error)
            )
          )
        )
      )
    );
  }

  Widget _buildIcon(int index) {
    if (config.steps[index].state != _oldStates[index]) {
      return new AnimatedCrossFade(
        firstChild: _buildCircle(index, true),
        secondChild: _buildTriangle(index, true),
        firstCurve: new Interval(0.0, 0.6, curve: Curves.fastOutSlowIn),
        secondCurve: new Interval(0.4, 1.0, curve: Curves.fastOutSlowIn),
        sizeCurve: Curves.fastOutSlowIn,
        crossFadeState: config.steps[index].state == StepState.error ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: kThemeAnimationDuration,
      );
    } else {
      if (config.steps[index].state != StepState.error)
        return _buildCircle(index, false);
      else
        return _buildTriangle(index, false);
    }
  }

  Widget _buildVerticalControls() {
    Color cancelColor;

    switch (Theme.of(context).brightness) {
      case Brightness.light:
        cancelColor = Colors.black54;
        break;
      case Brightness.dark:
        cancelColor = Colors.white70;
        break;
    }

    assert(cancelColor != null);

    final ThemeData themeData = Theme.of(context);

    return new Container(
      margin: const EdgeInsets.only(top: 16.0),
      child: new ConstrainedBox(
        constraints: const BoxConstraints.tightFor(height: 48.0),
        child: new Row(
          children: <Widget>[
            new FlatButton(
              onPressed: config.onStepContinue,
              color: _isDark() ? themeData.backgroundColor : themeData.primaryColor,
              textColor: Colors.white,
              textTheme: ButtonTextTheme.normal,
              child: new Text('CONTINUE')
            ),
            new Container(
              margin: const EdgeInsets.only(left: 8.0),
              child: new FlatButton(
                onPressed: config.onStepCancel,
                textColor: cancelColor,
                textTheme: ButtonTextTheme.normal,
                child: new Text('CANCEL')
              )
            )
          ]
        )
      )
    );
  }

  TextStyle _titleStyle(int index) {
    final ThemeData themeData = Theme.of(context);
    final TextTheme textTheme = themeData.textTheme;

    assert(config.steps[index].state != null);
    switch (config.steps[index].state) {
      case StepState.indexed:
      case StepState.editing:
      case StepState.complete:
        return textTheme.body2;
      case StepState.disabled:
        return textTheme.body2.copyWith(
          color: _isDark() ? _kDisabledDark : _kDisabledLight
        );
      case StepState.error:
        return textTheme.body2.copyWith(
          color: _isDark() ? _kErrorDark : _kErrorLight
        );
    }
    return null;
  }

  TextStyle _subtitleStyle(int index) {
    final ThemeData themeData = Theme.of(context);
    final TextTheme textTheme = themeData.textTheme;

    assert(config.steps[index].state != null);
    switch (config.steps[index].state) {
      case StepState.indexed:
      case StepState.editing:
      case StepState.complete:
        return textTheme.caption;
      case StepState.disabled:
        return textTheme.caption.copyWith(
          color: _isDark() ? _kDisabledDark : _kDisabledLight
        );
      case StepState.error:
        return textTheme.caption.copyWith(
          color: _isDark() ? _kErrorDark : _kErrorLight
        );
    }
    return null;
  }

  Widget _buildHeaderText(int index) {
    final List<Widget> children = <Widget>[
      new AnimatedDefaultTextStyle(
        style: _titleStyle(index),
        duration: kThemeAnimationDuration,
        curve: Curves.fastOutSlowIn,
        child: config.steps[index].title
      )
    ];

    if (config.steps[index].subtitle != null)
      children.add(
        new Container(
          margin: const EdgeInsets.only(top: 2.0),
          child: new AnimatedDefaultTextStyle(
            style: _subtitleStyle(index),
            duration: kThemeAnimationDuration,
            curve: Curves.fastOutSlowIn,
            child: config.steps[index].subtitle
          )
        )
      );

    return new Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children
    );
  }

  Widget _buildVerticalHeader(int index) {
    return new Container(
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      child: new Row(
        children: <Widget>[
          new Column(
            children: <Widget>[
              // Line parts are always added in order for the ink splash to
              // flood the tips of the connector lines.
              _buildLine(!_isFirst(index)),
              _buildIcon(index),
              _buildLine(!_isLast(index)),
            ]
          ),
          new Container(
            margin: const EdgeInsets.only(
              left: 12.0
            ),
            child: _buildHeaderText(index)
          )
        ]
      )
    );
  }

  Widget _buildVerticalBody(int index) {
    return new Stack(
      children: <Widget>[
        new Positioned(
          left: 24.0,
          top: 0.0,
          bottom: 0.0,
          child: new SizedBox(
            width: 24.0,
            child: new Center(
              child: new SizedBox(
                width: _isLast(index) ? 0.0 : 1.0,
                child: new Container(
                  decoration: new BoxDecoration(
                    backgroundColor: Colors.grey[400]
                  )
                )
              )
            )
          )
        ),
        new AnimatedCrossFade(
          firstChild: new Container(height: 0.0),
          secondChild: new Container(
            margin: const EdgeInsets.only(
              left: 60.0,
              right: 24.0,
              bottom: 24.0
            ),
            child: new Column(
              children: <Widget>[
                config.steps[index].content,
                _buildVerticalControls()
              ]
            )
          ),
          firstCurve: new Interval(0.0, 0.6, curve: Curves.fastOutSlowIn),
          secondCurve: new Interval(0.4, 1.0, curve: Curves.fastOutSlowIn),
          sizeCurve: Curves.fastOutSlowIn,
          crossFadeState: _isCurrent(index) ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: kThemeAnimationDuration,
        )
      ]
    );
  }

  Widget _buildVertical() {
    List<Widget> children = <Widget>[];

    for (int i = 0; i < config.steps.length; i += 1) {
      children.add(
        new Column(
          key: _keys[i],
          children: <Widget>[
            new InkWell(
              onTap: config.steps[i].state != StepState.disabled ? () {
                // In the vertical case we need to scroll to the newly tapped
                // step.
                Scrollable.ensureVisible(
                  _keys[i].currentContext,
                  curve: Curves.fastOutSlowIn,
                  duration: kThemeAnimationDuration
                );

                if (config.onStepTapped != null)
                  config.onStepTapped(i);
              } : null,
              child: _buildVerticalHeader(i)
            ),
            _buildVerticalBody(i)
          ]
        )
      );
    }

    return new Block(
      children: children
    );
  }

  Widget _buildHorizontal() {
    final List<Widget> children = <Widget>[];

    for (int i = 0; i < config.steps.length; i += 1) {
      children.add(
        new InkResponse(
          onTap: config.steps[i].state != StepState.disabled ? () {
            if (config.onStepTapped != null)
              config.onStepTapped(i);
          } : null,
          child: new Row(
            children: <Widget>[
              new Container(
                height: 72.0,
                child: new Center(
                  child: _buildIcon(i)
                )
              ),
              new Container(
                margin: const EdgeInsets.only(left: 12.0),
                child: _buildHeaderText(i)
              )
            ]
          )
        )
      );

      if (!_isLast(i))
        children.add(
          new Flexible(
            child: new Container(
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              height: 1.0,
              decoration: new BoxDecoration(
                backgroundColor: Colors.grey[400]
              )
            )
          )
        );
    }

    return new Column(
      children: <Widget>[
        new Material(
          elevation: 2,
          child: new Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            child: new Row(
              children: children
            )
          )
        ),
        new Flexible(
          child: new ScrollableViewport(
            child: new Container(
              margin: const EdgeInsets.all(24.0),
              child: new Column(
                children: <Widget>[
                  new AnimatedSize(
                    curve: Curves.fastOutSlowIn,
                    duration: kThemeAnimationDuration,
                    vsync: this,
                    child: config.steps[config.currentStep].content,
                  ),
                  _buildVerticalControls()
                ]
              )
            )
          )
        )
      ]
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    assert(() {
      if (context.ancestorWidgetOfExactType(Stepper) != null)
        throw new FlutterError(
          'Steppers must not be nested. The material specification advises '
          'that one should avoid embedding steppers within steppers. '
          'https://material.google.com/components/steppers.html#steppers-usage\n'
        );
      return true;
    });
    assert(config.type != null);
    switch (config.type) {
      case StepperType.vertical:
        return _buildVertical();
      case StepperType.horizontal:
        return _buildHorizontal();
    }
    return null;
  }
}

// Paints a triangle whose base is the bottom of the bounding rectangle and its
// top vertex the middle of its top.
class _TrianglePainter extends CustomPainter {
  _TrianglePainter({
    this.color
  });

  final Color color;

  @override
  bool hitTest(Point point) => true; // Hitting the rectangle is fine enough.

  @override
  bool shouldRepaint(_TrianglePainter oldPainter) {
    return oldPainter.color != color;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double base = size.width;
    final double halfBase = size.width / 2.0;
    final double height = size.height;
    final List<Point> points = <Point>[
      new Point(0.0, height),
      new Point(base, height),
      new Point(halfBase, 0.0)
    ];

    canvas.drawPath(
      new Path()..addPolygon(points, true),
      new Paint()..color = color
    );
  }
}

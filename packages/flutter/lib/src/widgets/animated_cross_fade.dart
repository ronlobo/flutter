// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import 'animated_size.dart';
import 'basic.dart';
import 'framework.dart';
import 'ticker_provider.dart';
import 'transitions.dart';

/// Specifies which of the children to show. See [AnimatedCrossFade].
///
/// The child that is shown will fade in, while the other will fade out.
enum CrossFadeState {
  /// Show the first child and hide the second.
  showFirst,
  /// Show the second child and hide the first.
  showSecond
}

/// A widget that cross-fades between two children and animates itself between
/// their sizes. The animation is controlled through the [crossFadeState]
/// parameter. [firstCurve] and [secondCurve] represent the opacity curves of
/// the two children. Note that [firstCurve] is inverted, i.e. it fades out when
/// providing a growing curve like [Curves.linear]. [sizeCurve] is the curve
/// used to animated between the size of the fading out child and the size of
/// the fading in child.
///
/// This widget is intended to be used to fade a pair of widgets with the same
/// width. In the case where the two children have different heights, the
/// animation crops overflowing children during the animation by aligning their
/// top edge, which means that the bottom will be clipped.
class AnimatedCrossFade extends StatefulWidget {
  /// Creates a cross-fade animation widget.
  ///
  /// The [duration] of the animation is the same for all components (fade in,
  /// fade out, and size), and you can pass [Interval]s instead of [Curve]s in
  /// order to have finer control, e.g., creating an overlap between the fades.
  AnimatedCrossFade({
    Key key,
    this.firstChild,
    this.secondChild,
    this.firstCurve: Curves.linear,
    this.secondCurve: Curves.linear,
    this.sizeCurve: Curves.linear,
    @required this.crossFadeState,
    @required this.duration
  }) : super(key: key) {
    assert(this.firstCurve != null);
    assert(this.secondCurve != null);
    assert(this.sizeCurve != null);
  }

  /// The child that is visible when [crossFadeState] is [showFirst]. It fades
  /// out when transitioning from [showFirst] to [showSecond] and vice versa.
  final Widget firstChild;

  /// The child that is visible when [crossFadeState] is [showSecond]. It fades
  /// in when transitioning from [showFirst] to [showSecond] and vice versa.
  final Widget secondChild;

  /// The child that will be shown when the animation has completed.
  final CrossFadeState crossFadeState;

  /// The duration of the whole orchestrated animation.
  final Duration duration;

  /// The fade curve of the first child.
  final Curve firstCurve;

  /// The fade curve of the second child.
  final Curve secondCurve;

  /// The curve of the animation between the two children's sizes.
  final Curve sizeCurve;

  @override
  _AnimatedCrossFadeState createState() => new _AnimatedCrossFadeState();
}

class _AnimatedCrossFadeState extends State<AnimatedCrossFade> with TickerProviderStateMixin {
  _AnimatedCrossFadeState() : super();

  AnimationController _controller;
  Animation<double> _firstAnimation;
  Animation<double> _secondAnimation;

  @override
  void initState() {
    super.initState();
    _controller = new AnimationController(duration: config.duration, vsync: this);
    if (config.crossFadeState == CrossFadeState.showSecond)
      _controller.value = 1.0;
    _firstAnimation = _initAnimation(config.firstCurve, true);
    _secondAnimation = _initAnimation(config.secondCurve, false);
  }

  Animation<double> _initAnimation(Curve curve, bool inverted) {
    final CurvedAnimation animation = new CurvedAnimation(
      parent: _controller,
      curve: curve
    );

    return inverted ? new Tween<double>(
      begin: 1.0,
      end: 0.0
    ).animate(animation) : animation;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateConfig(AnimatedCrossFade oldConfig) {
    super.didUpdateConfig(oldConfig);
    if (config.duration != oldConfig.duration)
      _controller.duration = config.duration;
    if (config.firstCurve != oldConfig.firstCurve)
      _firstAnimation = _initAnimation(config.firstCurve, true);
    if (config.secondCurve != oldConfig.secondCurve)
      _secondAnimation = _initAnimation(config.secondCurve, false);
    if (config.crossFadeState != oldConfig.crossFadeState) {
      switch (config.crossFadeState) {
        case CrossFadeState.showFirst:
          _controller.reverse();
          break;
        case CrossFadeState.showSecond:
          _controller.forward();
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children;

    if (_controller.status == AnimationStatus.completed ||
        _controller.status == AnimationStatus.forward) {
      children = <Widget>[
        new FadeTransition(
          opacity: _secondAnimation,
          child: config.secondChild
        ),
        new Positioned(
          // TODO(dragostis): Add a way to crop from top right for
          // right-to-left languages.
          left: 0.0,
          top: 0.0,
          right: 0.0,
          child: new FadeTransition(
            opacity: _firstAnimation,
            child: config.firstChild
          )
        )
      ];
    } else {
      children = <Widget>[
        new FadeTransition(
          opacity: _firstAnimation,
          child: config.firstChild
        ),
        new Positioned(
          // TODO(dragostis): Add a way to crop from top right for
          // right-to-left languages.
          left: 0.0,
          top: 0.0,
          right: 0.0,
          child: new FadeTransition(
            opacity: _secondAnimation,
            child: config.secondChild
          )
        )
      ];
    }

    return new ClipRect(
      child: new AnimatedSize(
        key: new ValueKey<Key>(config.key),
        alignment: FractionalOffset.topCenter,
        duration: config.duration,
        curve: config.sizeCurve,
        vsync: this,
        child: new Stack(
          overflow: Overflow.visible,
          children: children
        )
      )
    );
  }
}

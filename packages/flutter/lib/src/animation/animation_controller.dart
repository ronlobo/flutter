// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' as ui show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';

import 'animation.dart';
import 'curves.dart';
import 'forces.dart';
import 'listener_helpers.dart';

/// The direction in which an animation is running.
enum _AnimationDirection {
  /// The animation is running from beginning to end.
  forward,

  /// The animation is running backwards, from end to beginning.
  reverse,
}

/// A controller for an animation.
///
/// This class lets you perform tasks such as:
///
/// * Play an animation [forward] or in [reverse], or [stop] an animation.
/// * Set the animation to a specific [value].
/// * Define the [upperBound] and [lowerBound] values of an animation.
/// * Create a [fling] animation effect using a physics simulation.
///
/// By default, an [AnimationController] linearly produces values that range from 0.0 to 1.0, during
/// a given duration. The animation controller generates a new value whenever the device running
/// your app is ready to display a new frame (typically, this rate is around 60 values per second).
///
/// An AnimationController needs a [TickerProvider], which is configured using the `vsync` argument
/// on the constructor. If you are creating an AnimationController from a [State], then you can use
/// the [TickerProviderStateMixin] and [SingleTickerProviderStateMixin] classes to obtain a suitable
/// [TickerProvider]. The widget test framework [WidgetTester] object can be used as a ticker provider
/// in the context of tests. In other contexts, you will have to either pass a [TickerProvider] from
/// a higher level (e.g. indirectly from a [State] that mixes in [TickerProviderStateMixin]), or
/// create a custom [TickerProvider] subclass.
class AnimationController extends Animation<double>
  with AnimationEagerListenerMixin, AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {

  /// Creates an animation controller.
  ///
  /// * [value] is the initial value of the animation.
  /// * [duration] is the length of time this animation should last.
  /// * [debugLabel] is a string to help identify this animation during debugging (used by [toString]).
  /// * [lowerBound] is the smallest value this animation can obtain and the value at which this animation is deemed to be dismissed.
  /// * [upperBound] is the largest value this animation can obtain and the value at which this animation is deemed to be completed.
  /// * `vsync` is the [TickerProvider] for the current context. It can be changed by calling [resync].
  AnimationController({
    double value,
    this.duration,
    this.debugLabel,
    this.lowerBound: 0.0,
    this.upperBound: 1.0,
    @required TickerProvider vsync,
  }) {
    assert(upperBound >= lowerBound);
    assert(vsync != null);
    _direction = _AnimationDirection.forward;
    _ticker = vsync.createTicker(_tick);
    _internalSetValue(value ?? lowerBound);
  }

  /// Creates an animation controller with no upper or lower bound for its value.
  ///
  /// * [value] is the initial value of the animation.
  /// * [duration] is the length of time this animation should last.
  /// * [debugLabel] is a string to help identify this animation during debugging (used by [toString]).
  /// * `vsync` is the [TickerProvider] for the current context. It can be changed by calling [resync].
  ///
  /// This constructor is most useful for animations that will be driven using a
  /// physics simulation, especially when the physics simulation has no
  /// pre-determined bounds.
  AnimationController.unbounded({
    double value: 0.0,
    this.duration,
    this.debugLabel,
    @required TickerProvider vsync,
  }) : lowerBound = double.NEGATIVE_INFINITY,
       upperBound = double.INFINITY {
    assert(value != null);
    assert(vsync != null);
    _direction = _AnimationDirection.forward;
    _ticker = vsync.createTicker(_tick);
    _internalSetValue(value);
  }

  /// The value at which this animation is deemed to be dismissed.
  final double lowerBound;

  /// The value at which this animation is deemed to be completed.
  final double upperBound;

  /// A label that is used in the [toString] output. Intended to aid with
  /// identifying animation controller instances in debug output.
  final String debugLabel;

  /// Returns an [Animated<double>] for this animation controller,
  /// so that a pointer to this object can be passed around without
  /// allowing users of that pointer to mutate the AnimationController state.
  Animation<double> get view => this;

  /// The length of time this animation should last.
  Duration duration;

  Ticker _ticker;

  /// Recreates the [Ticker] with the new [TickerProvider].
  void resync(TickerProvider vsync) {
    Ticker oldTicker = _ticker;
    _ticker = vsync.createTicker(_tick);
    _ticker.absorbTicker(oldTicker);
  }

  Simulation _simulation;

  /// The current value of the animation.
  ///
  /// Setting this value notifies all the listeners that the value
  /// changed.
  ///
  /// Setting this value also stops the controller if it is currently
  /// running; if this happens, it also notifies all the status
  /// listeners.
  @override
  double get value => _value;
  double _value;
  /// Stops the animation controller and sets the current value of the
  /// animation.
  ///
  /// The new value is clamped to the range set by [lowerBound] and [upperBound].
  ///
  /// Value listeners are notified even if this does not change the value.
  /// Status listeners are notified if the animation was previously playing.
  set value(double newValue) {
    assert(newValue != null);
    stop();
    _internalSetValue(newValue);
    notifyListeners();
    _checkStatusChanged();
  }

  void _internalSetValue(double newValue) {
    _value = newValue.clamp(lowerBound, upperBound);
    if (_value == lowerBound) {
      _status = AnimationStatus.dismissed;
    } else if (_value == upperBound) {
      _status = AnimationStatus.completed;
    } else
      _status = (_direction == _AnimationDirection.forward) ?
        AnimationStatus.forward :
        AnimationStatus.reverse;
  }

  /// The amount of time that has passed between the time the animation started and the most recent tick of the animation.
  ///
  /// If the controller is not animating, the last elapsed duration is null.
  Duration get lastElapsedDuration => _lastElapsedDuration;
  Duration _lastElapsedDuration;

  /// Whether this animation is currently animating in either the forward or reverse direction.
  ///
  /// This is separate from whether it is actively ticking. An animation
  /// controller's ticker might get muted, in which case the animation
  /// controller's callbacks will no longer fire even though time is continuing
  /// to pass. See [Ticker.muted] and [TickerMode].
  bool get isAnimating => _ticker.isActive;

  _AnimationDirection _direction;

  @override
  AnimationStatus get status => _status;
  AnimationStatus _status;

  /// Starts running this animation forwards (towards the end).
  ///
  /// Returns a [Future] that completes when the animation is complete.
  Future<Null> forward({ double from }) {
    assert(() {
      if (duration == null) {
        throw new FlutterError(
          'AnimationController.forward() called with no default Duration.\n'
          'The "duration" property should be set, either in the constructor or later, before '
          'calling the forward() function.'
        );
      }
      return true;
    });
    _direction = _AnimationDirection.forward;
    if (from != null)
      value = from;
    return animateTo(upperBound);
  }

  /// Starts running this animation in reverse (towards the beginning).
  ///
  /// Returns a [Future] that completes when the animation is complete.
  Future<Null> reverse({ double from }) {
    assert(() {
      if (duration == null) {
        throw new FlutterError(
          'AnimationController.reverse() called with no default Duration.\n'
          'The "duration" property should be set, either in the constructor or later, before '
          'calling the reverse() function.'
        );
      }
      return true;
    });
    _direction = _AnimationDirection.reverse;
    if (from != null)
      value = from;
    return animateTo(lowerBound);
  }

  /// Drives the animation from its current value to target.
  ///
  /// Returns a [Future] that completes when the animation is complete.
  Future<Null> animateTo(double target, { Duration duration, Curve curve: Curves.linear }) {
    Duration simulationDuration = duration;
    if (simulationDuration == null) {
      assert(() {
        if (this.duration == null) {
          throw new FlutterError(
            'AnimationController.animateTo() called with no explicit Duration and no default Duration.\n'
            'Either the "duration" argument to the animateTo() method should be provided, or the '
            '"duration" property should be set, either in the constructor or later, before '
            'calling the animateTo() function.'
          );
        }
        return true;
      });
      double range = upperBound - lowerBound;
      double remainingFraction = range.isFinite ? (target - _value).abs() / range : 1.0;
      simulationDuration = this.duration * remainingFraction;
    }
    stop();
    if (simulationDuration == Duration.ZERO) {
      assert(value == target);
      _status = (_direction == _AnimationDirection.forward) ?
        AnimationStatus.completed :
        AnimationStatus.dismissed;
      _checkStatusChanged();
      return new Future<Null>.value();
    }
    assert(simulationDuration > Duration.ZERO);
    assert(!isAnimating);
    return _startSimulation(new _InterpolationSimulation(_value, target, simulationDuration, curve));
  }

  /// Starts running this animation in the forward direction, and
  /// restarts the animation when it completes.
  ///
  /// Defaults to repeating between the lower and upper bounds.
  Future<Null> repeat({ double min, double max, Duration period }) {
    min ??= lowerBound;
    max ??= upperBound;
    period ??= duration;
    assert(() {
      if (duration == null) {
        throw new FlutterError(
          'AnimationController.repeat() called with no explicit Duration and default Duration.\n'
          'Either the "duration" argument to the repeat() method should be provided, or the '
          '"duration" property should be set, either in the constructor or later, before '
          'calling the repeat() function.'
        );
      }
      return true;
    });
    return animateWith(new _RepeatingSimulation(min, max, period));
  }

  /// Flings the timeline with an optional force (defaults to a critically
  /// damped spring within [lowerBound] and [upperBound]) and initial velocity.
  /// If velocity is positive, the animation will complete, otherwise it will dismiss.
  Future<Null> fling({ double velocity: 1.0, Force force }) {
    force ??= kDefaultSpringForce.copyWith(left: lowerBound, right: upperBound);
    _direction = velocity < 0.0 ? _AnimationDirection.reverse : _AnimationDirection.forward;
    return animateWith(force.release(value, velocity));
  }

  /// Drives the animation according to the given simulation.
  Future<Null> animateWith(Simulation simulation) {
    stop();
    return _startSimulation(simulation);
  }

  Future<Null> _startSimulation(Simulation simulation) {
    assert(simulation != null);
    assert(!isAnimating);
    _simulation = simulation;
    _lastElapsedDuration = Duration.ZERO;
    _value = simulation.x(0.0).clamp(lowerBound, upperBound);
    Future<Null> result = _ticker.start();
    _status = (_direction == _AnimationDirection.forward) ?
      AnimationStatus.forward :
      AnimationStatus.reverse;
    _checkStatusChanged();
    return result;
  }

  /// Stops running this animation.
  ///
  /// This does not trigger any notifications. The animation stops in its
  /// current state.
  void stop() {
    _simulation = null;
    _lastElapsedDuration = null;
    _ticker.stop();
  }

  /// Release the resources used by this object. The object is no longer usable
  /// after this method is called.
  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  AnimationStatus _lastReportedStatus = AnimationStatus.dismissed;
  void _checkStatusChanged() {
    AnimationStatus newStatus = status;
    if (_lastReportedStatus != newStatus) {
      _lastReportedStatus = newStatus;
      notifyStatusListeners(newStatus);
    }
  }

  void _tick(Duration elapsed) {
    _lastElapsedDuration = elapsed;
    double elapsedInSeconds = elapsed.inMicroseconds.toDouble() / Duration.MICROSECONDS_PER_SECOND;
    _value = _simulation.x(elapsedInSeconds).clamp(lowerBound, upperBound);
    if (_simulation.isDone(elapsedInSeconds)) {
      _status = (_direction == _AnimationDirection.forward) ?
        AnimationStatus.completed :
        AnimationStatus.dismissed;
      stop();
    }
    notifyListeners();
    _checkStatusChanged();
  }

  @override
  String toStringDetails() {
    String paused = isAnimating ? '' : '; paused';
    String silenced = _ticker.muted ? '; silenced' : '';
    String label = debugLabel == null ? '' : '; for $debugLabel';
    String more = '${super.toStringDetails()} ${value.toStringAsFixed(3)}';
    return '$more$paused$silenced$label';
  }
}

class _InterpolationSimulation extends Simulation {
  _InterpolationSimulation(this._begin, this._end, Duration duration, this._curve)
    : _durationInSeconds = duration.inMicroseconds / Duration.MICROSECONDS_PER_SECOND {
    assert(_durationInSeconds > 0.0);
    assert(_begin != null);
    assert(_end != null);
  }

  final double _durationInSeconds;
  final double _begin;
  final double _end;
  final Curve _curve;

  @override
  double x(double timeInSeconds) {
    assert(timeInSeconds >= 0.0);
    double t = (timeInSeconds / _durationInSeconds).clamp(0.0, 1.0);
    if (t == 0.0)
      return _begin;
    else if (t == 1.0)
      return _end;
    else
      return _begin + (_end - _begin) * _curve.transform(t);
  }

  @override
  double dx(double timeInSeconds) => 1.0;

  @override
  bool isDone(double timeInSeconds) => timeInSeconds > _durationInSeconds;
}

class _RepeatingSimulation extends Simulation {
  _RepeatingSimulation(this.min, this.max, Duration period)
    : _periodInSeconds = period.inMicroseconds / Duration.MICROSECONDS_PER_SECOND {
    assert(_periodInSeconds > 0.0);
  }

  final double min;
  final double max;

  final double _periodInSeconds;

  @override
  double x(double timeInSeconds) {
    assert(timeInSeconds >= 0.0);
    final double t = (timeInSeconds / _periodInSeconds) % 1.0;
    return ui.lerpDouble(min, max, t);
  }

  @override
  double dx(double timeInSeconds) => 1.0;

  @override
  bool isDone(double timeInSeconds) => false;
}

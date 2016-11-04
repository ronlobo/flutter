// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/physics.dart';

export 'package:flutter/physics.dart' show SpringDescription;

/// A factory for simulations.
abstract class Force {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const Force();

  /// Creates a new physics simulation with the given initial conditions.
  Simulation release(double position, double velocity);
}

/// A factory for spring-based physics simulations.
class SpringForce extends Force {
  /// Creates a spring force.
  ///
  /// The [spring], [left], and [right] arguments must not be null. The [left]
  /// argument defaults to 0.0 and the [right] argument defaults to 1.0.
  const SpringForce(this.spring, { this.left: 0.0, this.right: 1.0 });

  /// The description of the spring to be used in the created simulations.
  final SpringDescription spring;

  /// Where to put the spring's resting point when releasing left.
  final double left;

  /// Where to put the spring's resting point when releasing right.
  final double right;

  /// Creates a copy of this spring force but with the given fields replaced with the new values.
  SpringForce copyWith({
    SpringDescription spring,
    double left,
    double right
  }) {
    return new SpringForce(
      spring ?? this.spring,
      left: left ?? this.left,
      right: right ?? this.right
    );
  }

  /// How pricely to terminate the simulation.
  ///
  /// We overshoot the target by this distance, but stop the simulation when
  /// the spring gets within this distance (regardless of how fast it's moving).
  /// This causes the spring to settle a bit faster than it otherwise would.
  static const Tolerance tolerance = const Tolerance(
    velocity: double.INFINITY,
    distance: 0.01
  );

  @override
  Simulation release(double position, double velocity) {
    double target = velocity < 0.0 ? this.left - tolerance.distance
                                   : this.right + tolerance.distance;
    return new SpringSimulation(spring, position, target, velocity)
      ..tolerance = tolerance;
  }
}

final SpringDescription _kDefaultSpringDesc = new SpringDescription.withDampingRatio(
  mass: 1.0,
  springConstant: 500.0,
  ratio: 1.0
);

/// A spring force with reasonable default values.
final SpringForce kDefaultSpringForce = new SpringForce(_kDefaultSpringDesc);

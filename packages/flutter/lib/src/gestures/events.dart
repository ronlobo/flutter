// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show Point, Offset, PointerDeviceKind;

import 'package:flutter/foundation.dart';

export 'dart:ui' show Point, Offset, PointerDeviceKind;

/// The bit of [PointerEvent.buttons] that corresponds to the primary mouse button.
///
/// The primary mouse button is typically the left button on the top of the
/// mouse but can be reconfigured to be a different physical button.
const int kPrimaryMouseButton = 0x01;

/// The bit of [PointerEvent.buttons] that corresponds to the secondary mouse button.
///
/// The secondary mouse button is typically the right button on the top of the
/// mouse but can be reconfigured to be a different physical button.
const int kSecondaryMouseButton = 0x02;

/// The bit of [PointerEvent.buttons] that corresponds to the primary stylus button.
///
/// The primary stylus button is typically the top of the stylus and near the
/// tip but can be reconfigured to be a different physical button.
const int kPrimaryStylusButton = 0x02;

/// The bit of [PointerEvent.buttons] that corresponds to the middle mouse button.
///
/// The middle mouse button is typically between the left and right buttons on
/// the top of the mouse but can be reconfigured to be a different physical
/// button.
const int kMiddleMouseButton = 0x04;

/// The bit of [PointerEvent.buttons] that corresponds to the secondary stylus button.
///
/// The secondary stylus button is typically on the end of the stylus fartherest
/// from the tip but can be reconfigured to be a different physical button.
const int kSecondaryStylusButton = 0x04;

/// The bit of [PointerEvent.buttons] that corresponds to the back mouse button.
///
/// The back mouse button is typically on the left side of the mouse but can be
/// reconfigured to be a different physical button.
const int kBackMouseButton = 0x08;

/// The bit of [PointerEvent.buttons] that corresponds to the forward mouse button.
///
/// The forward mouse button is typically on the right side of the mouse but can
/// be reconfigured to be a different physical button.
const int kForwardMouseButton = 0x10;

/// The bit of [PointerEvent.buttons] that corresponds to the nth mouse button.
///
/// The number argument can be at most 62.
///
/// See [kPrimaryMouseButton], [kSecondaryMouseButton], [kMiddleMouseButton],
/// [kBackMouseButton], and [kForwardMouseButton] for semantic names for some
/// mouse buttons.
int nthMouseButton(int number) => (kPrimaryMouseButton << (number - 1)) & kMaxUnsignedSMI;

/// The bit of [PointerEvent.buttons] that corresponds to the nth stylus button.
///
/// The number argument can be at most 62.
///
/// See [kPrimaryStylusButton] and [kSecondaryStylusButton] for semantic names
/// for some stylus buttons.
int nthStylusButton(int number) => (kPrimaryStylusButton << (number - 1)) & kMaxUnsignedSMI;

/// Base class for touch, stylus, or mouse events.
abstract class PointerEvent {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const PointerEvent({
    this.timeStamp: Duration.ZERO,
    this.pointer: 0,
    this.kind: PointerDeviceKind.touch,
    this.position: Point.origin,
    this.delta: Offset.zero,
    this.buttons: 0,
    this.down: false,
    this.obscured: false,
    this.pressure: 1.0,
    this.pressureMin: 1.0,
    this.pressureMax: 1.0,
    this.distance: 0.0,
    this.distanceMax: 0.0,
    this.radiusMajor: 0.0,
    this.radiusMinor: 0.0,
    this.radiusMin: 0.0,
    this.radiusMax: 0.0,
    this.orientation: 0.0,
    this.tilt: 0.0
  });

  /// Time of event dispatch, relative to an arbitrary timeline.
  final Duration timeStamp;

  /// Unique identifier for the pointer, not reused.
  final int pointer;

  /// The kind of input device for which the event was generated.
  final PointerDeviceKind kind;

  /// Coordinate of the position of the pointer, in logical pixels in the global
  /// coordinate space.
  final Point position;

  /// Distance in logical pixels that the pointer moved since the last
  /// PointerMoveEvent. Always 0.0 for down, up, and cancel events.
  final Offset delta;

  /// Bit field using the *Button constants (primaryMouseButton,
  /// secondaryStylusButton, etc). For example, if this has the value 6 and the
  /// [kind] is [PointerDeviceKind.invertedStylus], then this indicates an
  /// upside-down stylus with both its primary and secondary buttons pressed.
  final int buttons;

  /// Set if the pointer is currently down. For touch and stylus pointers, this
  /// means the object (finger, pen) is in contact with the input surface. For
  /// mice, it means a button is pressed.
  final bool down;

  /// Set if an application from a different security domain is in any way
  /// obscuring this application's window. (Aspirational; not currently
  /// implemented.)
  final bool obscured;

  /// The pressure of the touch as a number ranging from 0.0, indicating a touch
  /// with no discernible pressure, to 1.0, indicating a touch with "normal"
  /// pressure, and possibly beyond, indicating a stronger touch. For devices
  /// that do not detect pressure (e.g. mice), returns 1.0.
  final double pressure;

  /// The minimum value that [pressure] can return for this pointer. For devices
  /// that do not detect pressure (e.g. mice), returns 1.0. This will always be
  /// a number less than or equal to 1.0.
  final double pressureMin;

  /// The maximum value that [pressure] can return for this pointer. For devices
  /// that do not detect pressure (e.g. mice), returns 1.0. This will always be
  /// a greater than or equal to 1.0.
  final double pressureMax;

  /// The distance of the detected object from the input surface (e.g. the
  /// distance of a stylus or finger from a touch screen), in arbitrary units on
  /// an arbitrary (not necessarily linear) scale. If the pointer is down, this
  /// is 0.0 by definition.
  final double distance;

  /// The minimum value that a distance can return for this pointer (always 0.0).
  final double distanceMin = 0.0;

  /// The maximum value that a distance can return for this pointer. If this
  /// input device cannot detect "hover touch" input events, then this will be
  /// 0.0.
  final double distanceMax;

  /// The radius of the contact ellipse along the major axis, in logical pixels.
  final double radiusMajor;

  /// The radius of the contact ellipse along the minor axis, in logical pixels.
  final double radiusMinor;

  /// The minimum value that could be reported for radiusMajor and radiusMinor
  /// for this pointer, in logical pixels.
  final double radiusMin;

  /// The minimum value that could be reported for radiusMajor and radiusMinor
  /// for this pointer, in logical pixels.
  final double radiusMax;

  /// For PointerDeviceKind.touch events:
  ///
  /// The angle of the contact ellipse, in radius in the range:
  ///
  ///    -pi/2 < orientation <= pi/2
  ///
  /// ...giving the angle of the major axis of the ellipse with the y-axis
  /// (negative angles indicating an orientation along the top-left /
  /// bottom-right diagonal, positive angles indicating an orientation along the
  /// top-right / bottom-left diagonal, and zero indicating an orientation
  /// parallel with the y-axis).
  ///
  /// For PointerDeviceKind.stylus and PointerDeviceKind.invertedStylus events:
  ///
  /// The angle of the stylus, in radians in the range:
  ///
  ///    -pi < orientation <= pi
  ///
  /// ...giving the angle of the axis of the stylus projected onto the input
  /// surface, relative to the positive y-axis of that surface (thus 0.0
  /// indicates the stylus, if projected onto that surface, would go from the
  /// contact point vertically up in the positive y-axis direction, pi would
  /// indicate that the stylus would go down in the negative y-axis direction;
  /// pi/4 would indicate that the stylus goes up and to the right, -pi/2 would
  /// indicate that the stylus goes to the left, etc).
  final double orientation;

  /// For PointerDeviceKind.stylus and PointerDeviceKind.invertedStylus events:
  ///
  /// The angle of the stylus, in radians in the range:
  ///
  ///    0 <= tilt <= pi/2
  ///
  /// ...giving the angle of the axis of the stylus, relative to the axis
  /// perpendicular to the input surface (thus 0.0 indicates the stylus is
  /// orthogonal to the plane of the input surface, while pi/2 indicates that
  /// the stylus is flat on that surface).
  final double tilt;

  @override
  String toString() => '$runtimeType($position)';

  /// Returns a complete textual description of this event.
  String toStringFull() {
    return '$runtimeType('
             'timeStamp: $timeStamp, '
             'pointer: $pointer, '
             'kind: $kind, '
             'position: $position, '
             'delta: $delta, '
             'buttons: $buttons, '
             'down: $down, '
             'obscured: $obscured, '
             'pressure: $pressure, '
             'pressureMin: $pressureMin, '
             'pressureMax: $pressureMax, '
             'distance: $distance, '
             'distanceMin: $distanceMin, '
             'distanceMax: $distanceMax, '
             'radiusMajor: $radiusMajor, '
             'radiusMinor: $radiusMinor, '
             'radiusMin: $radiusMin, '
             'radiusMax: $radiusMax, '
             'orientation: $orientation, '
             'tilt: $tilt'
           ')';
  }
}

/// The device has started tracking the pointer.
///
/// For example, the pointer might be hovering above the device, having not yet
/// made contact with the surface of the device.
class PointerAddedEvent extends PointerEvent {
  /// Creates a pointer added event.
  ///
  /// All of the argument must be non-null.
  const PointerAddedEvent({
    Duration timeStamp: Duration.ZERO,
    int pointer: 0,
    PointerDeviceKind kind: PointerDeviceKind.touch,
    Point position: Point.origin,
    bool obscured: false,
    double pressureMin: 1.0,
    double pressureMax: 1.0,
    double distance: 0.0,
    double distanceMax: 0.0,
    double radiusMin: 0.0,
    double radiusMax: 0.0,
    double orientation: 0.0,
    double tilt: 0.0
  }) : super(
    timeStamp: timeStamp,
    pointer: pointer,
    kind: kind,
    position: position,
    obscured: obscured,
    pressureMin: pressureMin,
    pressureMax: pressureMax,
    distance: distance,
    distanceMax: distanceMax,
    radiusMin: radiusMin,
    radiusMax: radiusMax,
    orientation: orientation,
    tilt: tilt
  );
}

/// The device is no longer tracking the pointer.
///
/// For example, the pointer might have drifted out of the device's hover
/// detection range or might have been disconnected from the system entirely.
class PointerRemovedEvent extends PointerEvent {
  /// Creates a pointer removed event.
  ///
  /// All of the argument must be non-null.
  const PointerRemovedEvent({
    Duration timeStamp: Duration.ZERO,
    int pointer: 0,
    PointerDeviceKind kind: PointerDeviceKind.touch,
    bool obscured: false,
    double pressureMin: 1.0,
    double pressureMax: 1.0,
    double distanceMax: 0.0,
    double radiusMin: 0.0,
    double radiusMax: 0.0
  }) : super(
    timeStamp: timeStamp,
    pointer: pointer,
    kind: kind,
    position: null,
    obscured: obscured,
    pressureMin: pressureMin,
    pressureMax: pressureMax,
    distanceMax: distanceMax,
    radiusMin: radiusMin,
    radiusMax: radiusMax
  );
}

/// The pointer has made contact with the device.
class PointerDownEvent extends PointerEvent {
  /// Creates a pointer down event.
  ///
  /// All of the argument must be non-null.
  const PointerDownEvent({
    Duration timeStamp: Duration.ZERO,
    int pointer: 0,
    PointerDeviceKind kind: PointerDeviceKind.touch,
    Point position: Point.origin,
    int buttons: 0,
    bool obscured: false,
    double pressure: 1.0,
    double pressureMin: 1.0,
    double pressureMax: 1.0,
    double distanceMax: 0.0,
    double radiusMajor: 0.0,
    double radiusMinor: 0.0,
    double radiusMin: 0.0,
    double radiusMax: 0.0,
    double orientation: 0.0,
    double tilt: 0.0
  }) : super(
    timeStamp: timeStamp,
    pointer: pointer,
    kind: kind,
    position: position,
    buttons: buttons,
    down: true,
    obscured: obscured,
    pressure: pressure,
    pressureMin: pressureMin,
    pressureMax: pressureMax,
    distance: 0.0,
    distanceMax: distanceMax,
    radiusMajor: radiusMajor,
    radiusMinor: radiusMinor,
    radiusMin: radiusMin,
    radiusMax: radiusMax,
    orientation: orientation,
    tilt: tilt
  );
}

/// The pointer has moved with respect to the device.
class PointerMoveEvent extends PointerEvent {
  /// Creates a pointer move event.
  ///
  /// All of the argument must be non-null.
  const PointerMoveEvent({
    Duration timeStamp: Duration.ZERO,
    int pointer: 0,
    PointerDeviceKind kind: PointerDeviceKind.touch,
    Point position: Point.origin,
    Offset delta: Offset.zero,
    int buttons: 0,
    bool down: false,
    bool obscured: false,
    double pressure: 1.0,
    double pressureMin: 1.0,
    double pressureMax: 1.0,
    double distance: 0.0,
    double distanceMax: 0.0,
    double radiusMajor: 0.0,
    double radiusMinor: 0.0,
    double radiusMin: 0.0,
    double radiusMax: 0.0,
    double orientation: 0.0,
    double tilt: 0.0
  }) : super(
    timeStamp: timeStamp,
    pointer: pointer,
    kind: kind,
    position: position,
    delta: delta,
    buttons: buttons,
    down: down,
    obscured: obscured,
    pressure: pressure,
    pressureMin: pressureMin,
    pressureMax: pressureMax,
    distance: distance,
    distanceMax: distanceMax,
    radiusMajor: radiusMajor,
    radiusMinor: radiusMinor,
    radiusMin: radiusMin,
    radiusMax: radiusMax,
    orientation: orientation,
    tilt: tilt
  );
}

/// The pointer has stopped making contact with the device.
class PointerUpEvent extends PointerEvent {
  /// Creates a pointer up event.
  ///
  /// All of the argument must be non-null.
  const PointerUpEvent({
    Duration timeStamp: Duration.ZERO,
    int pointer: 0,
    PointerDeviceKind kind: PointerDeviceKind.touch,
    Point position: Point.origin,
    int buttons: 0,
    bool obscured: false,
    double pressureMin: 1.0,
    double pressureMax: 1.0,
    double distance: 0.0,
    double distanceMax: 0.0,
    double radiusMin: 0.0,
    double radiusMax: 0.0,
    double orientation: 0.0,
    double tilt: 0.0
  }) : super(
    timeStamp: timeStamp,
    pointer: pointer,
    kind: kind,
    position: position,
    buttons: buttons,
    obscured: obscured,
    pressureMin: pressureMin,
    pressureMax: pressureMax,
    distance: distance,
    distanceMax: distanceMax,
    radiusMin: radiusMin,
    radiusMax: radiusMax,
    orientation: orientation,
    tilt: tilt
  );
}

/// The input from the pointer is no longer directed towards this receiver.
class PointerCancelEvent extends PointerEvent {
  /// Creates a pointer cancel event.
  ///
  /// All of the argument must be non-null.
  const PointerCancelEvent({
    Duration timeStamp: Duration.ZERO,
    int pointer: 0,
    PointerDeviceKind kind: PointerDeviceKind.touch,
    Point position: Point.origin,
    int buttons: 0,
    bool obscured: false,
    double pressureMin: 1.0,
    double pressureMax: 1.0,
    double distance: 0.0,
    double distanceMax: 0.0,
    double radiusMin: 0.0,
    double radiusMax: 0.0,
    double orientation: 0.0,
    double tilt: 0.0
  }) : super(
    timeStamp: timeStamp,
    pointer: pointer,
    kind: kind,
    position: position,
    buttons: buttons,
    obscured: obscured,
    pressureMin: pressureMin,
    pressureMax: pressureMax,
    distance: distance,
    distanceMax: distanceMax,
    radiusMin: radiusMin,
    radiusMax: radiusMax,
    orientation: orientation,
    tilt: tilt
  );
}

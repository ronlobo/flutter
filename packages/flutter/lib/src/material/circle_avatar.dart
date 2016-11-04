// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'constants.dart';
import 'theme.dart';

/// A circle that represents a user.
///
/// Typicially used with a user's profile image, or, in the absence of
/// such an image, the user's initials. A given user's initials should
/// always be paired with the same background color, for consistency.
///
/// See also:
///
///  * [Chip]
///  * [ListItem]
///  * <https://material.google.com/components/chips.html#chips-contact-chips>
class CircleAvatar extends StatelessWidget {
  /// Creates a circle that represents a user.
  CircleAvatar({
    Key key,
    this.child,
    this.backgroundColor,
    this.backgroundImage,
    this.radius: 20.0
  }) : super(key: key);

  /// The widget below this widget in the tree.
  final Widget child;

  /// The color with which to fill the circle. Changing the background
  /// color will cause the avatar to animate to the new color.
  final Color backgroundColor;

  /// The background image of the circle. Changing the background
  /// image will cause the avatar to animate to the new image.
  final ImageProvider backgroundImage;

  /// The size of the avatar. Changing the radius will cause the
  /// avatar to animate to the new size.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = backgroundColor ?? theme.primaryColor;

    return new AnimatedContainer(
      width: radius * 2.0,
      height: radius * 2.0,
      duration: kThemeChangeDuration,
      decoration: new BoxDecoration(
        backgroundColor: color,
        backgroundImage: backgroundImage != null ? new BackgroundImage(
          image: backgroundImage
        ) : null,
        shape: BoxShape.circle
      ),
      child: new Center(
        child: new DefaultTextStyle(
          style: theme.primaryTextTheme.title,
          child: child
        )
      )
    );
  }
}

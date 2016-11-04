// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

/// A tile in a material design grid list.
///
/// A grid list is a [ScrollableGrid] of tiles in a vertical and horizontal
/// array. Each tile typically contains some visually rich content (e.g., an
/// image) together with a [GridTileBar] in either a [header] or a [footer].
///
/// See also:
///
///  * [ScrollableGrid]
///  * [GridTileBar]
///  * <https://material.google.com/components/grid-lists.html>
class GridTile extends StatelessWidget {
  /// Creates a grid tile.
  ///
  /// Must have a child. Does not typically have both a header and a footer.
  GridTile({ Key key, this.header, this.footer, this.child }) : super(key: key) {
    assert(child != null);
  }

  /// The widget to show over the top of this grid tile.
  final Widget header;

  /// The widget to show over the bottom of this grid tile.
  final Widget footer;

  /// The widget that fills the tile.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (header == null && footer == null)
      return child;

    final List<Widget> children = <Widget>[
      new Positioned.fill(
        child: child
      )
    ];
    if (header != null) {
      children.add(new Positioned(
        top: 0.0,
        left: 0.0,
        right: 0.0,
        child: header
      ));
    }
    if (footer != null) {
      children.add(new Positioned(
        left: 0.0,
        bottom: 0.0,
        right: 0.0,
        child: footer
      ));
    }
    return new Stack(children: children);
  }
}

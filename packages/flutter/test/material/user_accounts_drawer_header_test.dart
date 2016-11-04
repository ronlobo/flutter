// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('UserAccountsDrawerHeader test', (WidgetTester tester) async {
    final Key avatarA = new Key('A');
    final Key avatarC = new Key('C');
    final Key avatarD = new Key('D');

    await tester.pumpWidget(
      new Material(
        child: new UserAccountsDrawerHeader(
          currentAccountPicture: new CircleAvatar(
            key: avatarA,
            child: new Text('A')
          ),
          otherAccountsPictures: <Widget>[
            new CircleAvatar(
              child: new Text('B')
            ),
            new CircleAvatar(
              key: avatarC,
              child: new Text('C')
            ),
            new CircleAvatar(
              key: avatarD,
              child: new Text('D')
            ),
            new CircleAvatar(
              child: new Text('E')
            )
          ],
          accountName: new Text("name"),
          accountEmail: new Text("email")
        )
      )
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(find.text('E'), findsNothing);

    expect(find.text('name'), findsOneWidget);
    expect(find.text('email'), findsOneWidget);

    RenderBox box = tester.renderObject(find.byKey(avatarA));
    expect(box.size.width, equals(72.0));
    expect(box.size.height, equals(72.0));

    box = tester.renderObject(find.byKey(avatarC));
    expect(box.size.width, equals(40.0));
    expect(box.size.height, equals(40.0));

    Point topLeft = tester.getTopLeft(find.byType(UserAccountsDrawerHeader));
    Point topRight = tester.getTopRight(find.byType(UserAccountsDrawerHeader));

    Point avatarATopLeft = tester.getTopLeft(find.byKey(avatarA));
    Point avatarDTopRight = tester.getTopRight(find.byKey(avatarD));
    Point avatarCTopRight = tester.getTopRight(find.byKey(avatarC));

    expect(avatarATopLeft.x - topLeft.x, equals(16.0));
    expect(avatarATopLeft.y - topLeft.y, equals(16.0));
    expect(topRight.x - avatarDTopRight.x, equals(16.0));
    expect(avatarDTopRight.y - topRight.y, equals(16.0));
    expect(avatarDTopRight.x - avatarCTopRight.x, equals(40.0 + 16.0)); // size + space between
  });
}

// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show Shader;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

Shader createShader(Rect bounds) {
  return new LinearGradient(
    begin: FractionalOffset.topLeft,
    end: FractionalOffset.bottomLeft,
    colors: <Color>[const Color(0x00FFFFFF), const Color(0xFFFFFFFF)],
    stops: <double>[0.1, 0.35]
  ).createShader(bounds);
}


void main() {
  testWidgets('Can be constructed', (WidgetTester tester) async {
    Widget child = new Container(width: 100.0, height: 100.0);
    await tester.pumpWidget(new ShaderMask(child: child, shaderCallback: createShader));
  });
}

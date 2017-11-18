// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

class TestValueKey<T> extends ValueKey<T> {
  const TestValueKey(T value) : super(value);
}

class NotEquals {
  const NotEquals();
  @override
  bool operator ==(dynamic other) => false;
  @override
  int get hashCode => 0;
}

void main() {
  testWidgets('Keys', (WidgetTester tester) async {
    final int int3 = 3; // we want these instances to be separate instances so that we're not just checking with a single object
    expect(new ValueKey<int>(int3) == new ValueKey<int>(int3), isTrue);
    expect(new ValueKey<num>(int3) == new ValueKey<int>(int3), isFalse);
    final int int2 = 2; // we want these instances to be separate instances so that we're not just checking with a single object
    expect(new ValueKey<int>(int3) == new ValueKey<int>(int2), isFalse);
    expect(const ValueKey<double>(double.NAN) == const ValueKey<double>(double.NAN), isFalse);

    final String empty = ''; // we want these instances to be separate instances so that we're not just checking with a single object
    expect(new Key(empty) == new ValueKey<String>(empty), isTrue);
    expect(new ValueKey<String>(empty) == new ValueKey<String>(empty), isTrue);
    expect(new TestValueKey<String>(empty) == new ValueKey<String>(empty), isFalse);
    expect(new TestValueKey<String>(empty) == new TestValueKey<String>(empty), isTrue);

    expect(new ValueKey<String>(empty) == new ValueKey<dynamic>(empty), isFalse);
    expect(new TestValueKey<String>(empty) == new TestValueKey<dynamic>(empty), isFalse);

    expect(new UniqueKey() == new UniqueKey(), isFalse);
    final LocalKey k = new UniqueKey();
    expect(new UniqueKey() == new UniqueKey(), isFalse);
    expect(k == k, isTrue);

    expect(new ValueKey<LocalKey>(k) == new ValueKey<LocalKey>(k), isTrue);
    expect(new ValueKey<LocalKey>(k) == new ValueKey<UniqueKey>(k), isFalse);
    expect(new ObjectKey(k) == new ObjectKey(k), isTrue);

    final NotEquals constNotEquals = const NotEquals(); // we want these instances to be separate instances so that we're not just checking with a single object
    expect(new ValueKey<NotEquals>(constNotEquals) == new ValueKey<NotEquals>(constNotEquals), isFalse);
    expect(new ObjectKey(constNotEquals) == new ObjectKey(constNotEquals), isTrue);

    final Object constObject = const Object(); // we want these instances to be separate instances so that we're not just checking with a single object
    expect(new ObjectKey(constObject) == new ObjectKey(constObject), isTrue);
    expect(new ObjectKey(new Object()) == new ObjectKey(new Object()), isFalse);

    expect(const ValueKey<bool>(true), hasOneLineDescription);
    expect(new UniqueKey(), hasOneLineDescription);
    expect(const ObjectKey(true), hasOneLineDescription);
    expect(new GlobalKey(), hasOneLineDescription);
    expect(new GlobalKey(debugLabel: 'hello'), hasOneLineDescription);
    expect(const GlobalObjectKey(true), hasOneLineDescription);
  });
}

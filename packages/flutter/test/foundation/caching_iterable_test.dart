// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:test/test.dart';

int yieldCount;

Iterable<int> range(int start, int end) sync* {
  assert(yieldCount == 0);
  for (int index = start; index <= end; index += 1) {
    yieldCount += 1;
    yield index;
  }
 }

void main() {
  setUp(() {
    yieldCount = 0;
  });

  test('The Caching Iterable: length caches', () {
    Iterable<int> i = new CachingIterable<int>(range(1, 5).iterator);
    expect(yieldCount, equals(0));
    expect(i.length, equals(5));
    expect(yieldCount, equals(5));

    expect(i.length, equals(5));
    expect(yieldCount, equals(5));

    expect(i.last, equals(5));
    expect(yieldCount, equals(5));

    expect(i, equals(<int>[1, 2, 3, 4, 5]));
    expect(yieldCount, equals(5));
  });

  test('The Caching Iterable: laziness', () {
    Iterable<int> i = new CachingIterable<int>(range(1, 5).iterator);
    expect(yieldCount, equals(0));

    expect(i.first, equals(1));
    expect(yieldCount, equals(1));

    expect(i.firstWhere((int i) => i == 3), equals(3));
    expect(yieldCount, equals(3));

    expect(i.last, equals(5));
    expect(yieldCount, equals(5));
  });

  test('The Caching Iterable: where and map', () {
    Iterable<int> integers = new CachingIterable<int>(range(1, 5).iterator);
    expect(yieldCount, equals(0));

    Iterable<int> evens = integers.where((int i) => i % 2 == 0);
    expect(yieldCount, equals(0));

    expect(evens.first, equals(2));
    expect(yieldCount, equals(2));

    expect(integers.first, equals(1));
    expect(yieldCount, equals(2));

    expect(evens.map((int i) => i + 1), equals(<int>[3, 5]));
    expect(yieldCount, equals(5));

    expect(evens, equals(<int>[2, 4]));
    expect(yieldCount, equals(5));

    expect(integers, equals(<int>[1, 2, 3, 4, 5]));
    expect(yieldCount, equals(5));
  });
}

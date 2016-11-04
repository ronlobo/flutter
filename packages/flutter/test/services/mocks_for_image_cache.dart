// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' as ui show Image;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TestImageInfo implements ImageInfo {
  const TestImageInfo(this.value) : image = null, scale = null;

  @override
  final ui.Image image; // ignored in test

  @override
  final double scale; // ignored in test

  final int value;

  @override
  String toString() => '$runtimeType($value)';
}

class TestProvider extends ImageProvider<int> {
  const TestProvider(this.key, this.imageValue);
  final int key;
  final int imageValue;

  @override
  Future<int> obtainKey(ImageConfiguration configuration) {
    return new Future<int>.value(key);
  }

  @override
  ImageStreamCompleter load(int key) {
    return new OneFrameImageStreamCompleter(
      new SynchronousFuture<ImageInfo>(new TestImageInfo(imageValue))
    );
  }

  @override
  String toString() => '$runtimeType($key, $imageValue)';
}

Future<ImageInfo> extractOneFrame(ImageStream stream) {
  Completer<ImageInfo> completer = new Completer<ImageInfo>();
  void listener(ImageInfo image, bool synchronousCall) {
    completer.complete(image);
    stream.removeListener(listener);
  }
  stream.addListener(listener);
  return completer.future;
}
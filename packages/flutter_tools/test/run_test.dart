// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/commands/run.dart';
import 'package:test/test.dart';

import 'src/common.dart';
import 'src/context.dart';
import 'src/mocks.dart';

void main() {
  group('run', () {
    testUsingContext('fails when target not found', () {
      RunCommand command = new RunCommand();
      applyMocksToCommand(command);
      return createTestCommandRunner(command).run(<String>['run', '-t', 'abc123']).then((int code) {
        expect(code, 1);
      });
    });
  });
}

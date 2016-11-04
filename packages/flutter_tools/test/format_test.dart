// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/create.dart';
import 'package:flutter_tools/src/commands/format.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'src/common.dart';
import 'src/context.dart';

void main() {
  group('format', () {
    Directory temp;

    setUp(() {
      Cache.disableLocking();
      temp = Directory.systemTemp.createTempSync('flutter_tools');
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    Future<Null> createProject() async {
      CreateCommand command = new CreateCommand();
      CommandRunner runner = createTestCommandRunner(command);

      int code = await runner.run(<String>['create', '--no-pub', temp.path]);
      expect(code, 0);
    }

    testUsingContext('a file', () async {
      await createProject();

      File srcFile = new File(path.join(temp.path, 'lib', 'main.dart'));
      String original = srcFile.readAsStringSync();
      srcFile.writeAsStringSync(original.replaceFirst('main()', 'main(  )'));

      FormatCommand command = new FormatCommand();
      CommandRunner runner = createTestCommandRunner(command);
      int code = await runner.run(<String>['format', srcFile.path]);
      expect(code, 0);

      String formatted = srcFile.readAsStringSync();
      expect(formatted, original);
    });
  });
}

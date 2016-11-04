// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_tools/src/commands/create.dart';
import 'package:flutter_tools/src/commands/packages.dart';
import 'package:test/test.dart';

import 'src/common.dart';
import 'src/context.dart';

void main() {
  group('packages', () {
    Directory temp;

    setUp(() {
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

    Future<Null> runCommand(String verb) async {
      await createProject();

      PackagesCommand command = new PackagesCommand();
      CommandRunner runner = createTestCommandRunner(command);

      int code = await runner.run(<String>['packages', verb, temp.path]);
      expect(code, 0);
    }

    void expectExists(String relPath) {
      expect(FileSystemEntity.isFileSync('${temp.path}/$relPath'), true);
    }

    // Verify that we create a project that is well-formed.
    testUsingContext('get', () async {
      await runCommand('get');
      expectExists('lib/main.dart');
      expectExists('.packages');
    });

    testUsingContext('upgrade', () async {
      await runCommand('upgrade');
      expectExists('lib/main.dart');
      expectExists('.packages');
    });
  });
}

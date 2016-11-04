// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import '../runner/flutter_command.dart';
import 'analyze_continuously.dart';
import 'analyze_once.dart';

bool isDartFile(FileSystemEntity entry) => entry is File && entry.path.endsWith('.dart');

typedef bool FileFilter(FileSystemEntity entity);

class AnalyzeCommand extends FlutterCommand {
  AnalyzeCommand({bool verboseHelp: false}) {
    argParser.addFlag('flutter-repo', help: 'Include all the examples and tests from the Flutter repository.', defaultsTo: false);
    argParser.addFlag('current-directory', help: 'Include all the Dart files in the current directory, if any.', defaultsTo: true);
    argParser.addFlag('current-package', help: 'Include the lib/main.dart file from the current directory, if any.', defaultsTo: true);
    argParser.addFlag('dartdocs', help: 'List every public member that is lacking documentation (only examines files in the Flutter repository).', defaultsTo: false);
    argParser.addFlag('watch', help: 'Run analysis continuously, watching the filesystem for changes.', negatable: false);
    argParser.addOption('write', valueHelp: 'file', help: 'Also output the results to a file. This is useful with --watch if you want a file to always contain the latest results.');
    argParser.addOption('dart-sdk', valueHelp: 'path-to-sdk', help: 'The path to the Dart SDK.', hide: !verboseHelp);

    // Hidden option to enable a benchmarking mode.
    argParser.addFlag('benchmark', negatable: false, hide: !verboseHelp, help: 'Also output the analysis time');

    usesPubOption();

    // Not used by analyze --watch
    argParser.addFlag('congratulate', help: 'Show output even when there are no errors, warnings, hints, or lints.', defaultsTo: true);
    argParser.addFlag('preamble', help: 'Display the number of files that will be analyzed.', defaultsTo: true);
  }

  @override
  String get name => 'analyze';

  @override
  String get description => 'Analyze the project\'s Dart code.';

  @override
  bool get shouldRunPub {
    // If they're not analyzing the current project.
    if (!argResults['current-package'])
      return false;

    // Or we're not in a project directory.
    if (!new File('pubspec.yaml').existsSync())
      return false;

    return super.shouldRunPub;
  }

  @override
  Future<int> runCommand() {
    if (argResults['watch']) {
      return new AnalyzeContinuously(argResults, runner.getRepoAnalysisEntryPoints()).analyze();
    } else {
      return new AnalyzeOnce(argResults, runner.getRepoPackages()).analyze();
    }
  }
}

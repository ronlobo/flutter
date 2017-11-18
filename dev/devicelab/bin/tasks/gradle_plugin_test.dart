// Copyright (c) 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/framework/utils.dart';

void main() {
  task(() async {
    section('Setting up flutter project');
    final Directory tmp = await Directory.systemTemp.createTemp('gradle');
    final FlutterProject project = await FlutterProject.create(tmp, 'hello');

    try {
      section('gradlew assembleDebug');
      await project.runGradleTask('assembleDebug');

      section('gradlew assembleProfile');
      await project.runGradleTask('assembleProfile');

      section('gradlew assembleRelease');
      await project.runGradleTask('assembleRelease');

      section('gradlew assembleLocal (custom debug build)');
      await project.addCustomBuildType('local', initWith: 'debug');
      await project.runGradleTask('assembleLocal');

      section('gradlew assembleBeta (custom release build)');
      await project.addCustomBuildType('beta', initWith: 'release');
      await project.runGradleTask('assembleBeta');

      section('gradlew assembleFreeDebug (product flavor)');
      await project.addProductFlavor('free');
      await project.runGradleTask('assembleFreeDebug');

      await project.introduceError();

      section('gradlew on build script with error');
      {
        final ProcessResult result = await project.resultOfGradleTask('assembleRelease');
        if (result.exitCode == 0)
          return _failure('Gradle did not exit with error as expected', result);
        final String output = result.stdout + '\n' + result.stderr;
        if (output.contains('GradleException') || output.contains('Failed to notify') || output.contains('at org.gradle'))
          return _failure('Gradle output should not contain stacktrace', result);
        if (!output.contains('Build failed') || !output.contains('builTypes'))
          return _failure('Gradle output should contain a readable error message', result);
      }

      section('flutter build apk on build script with error');
      {
        final ProcessResult result = await project.resultOfFlutterCommand('build', <String>['apk']);
        if (result.exitCode == 0)
          return _failure('flutter build apk should fail when Gradle does', result);
        final String output = result.stdout + '\n' + result.stderr;
        if (!output.contains('Build failed') || !output.contains('builTypes'))
          return _failure('flutter build apk output should contain a readable Gradle error message', result);
        if (_hasMultipleOccurrences(output, 'builTypes'))
          return _failure('flutter build apk should not invoke Gradle repeatedly on error', result);
      }

      return new TaskResult.success(null);
    } catch(e) {
      return new TaskResult.failure(e.toString());
    } finally {
      project.parent.deleteSync(recursive: true);
    }
  });
}

TaskResult _failure(String message, ProcessResult result) {
  print('Unexpected process result:');
  print('Exit code: ${result.exitCode}');
  print('Std out  :\n${result.stdout}');
  print('Std err  :\n${result.stderr}');
  return new TaskResult.failure(message);
}

bool _hasMultipleOccurrences(String text, Pattern pattern) {
  return text.indexOf(pattern) != text.lastIndexOf(pattern);
}

class FlutterProject {
  FlutterProject(this.parent, this.name, this.javaPath);

  final Directory parent;
  final String name;
  final String javaPath;

  static Future<FlutterProject> create(Directory directory, String name) async {
    await inDirectory(directory, () async {
      await flutter('create', options: <String>[name]);
    });
    final String flutterDoctor = await evalFlutter('doctor');
    final RegExp javaPathExtractor = new RegExp(r'Android Studio at (.*)');
    final String javaPath = javaPathExtractor.firstMatch(flutterDoctor).group(1) + '/jre';
    return new FlutterProject(directory, name, javaPath);
  }

  String get rootPath => path.join(parent.path, name);
  String get androidPath => path.join(rootPath, 'android');

  Future<Null> addCustomBuildType(String name, {String initWith}) async {
    final File buildScript = new File(
      path.join(androidPath, 'app', 'build.gradle'),
    );
    buildScript.openWrite(mode: FileMode.APPEND).write('''

android {
    buildTypes {
        $name {
            initWith $initWith
        }
    }
}
    ''');
  }

  Future<Null> addProductFlavor(String name) async {
    final File buildScript = new File(
      path.join(androidPath, 'app', 'build.gradle'),
    );
    buildScript.openWrite(mode: FileMode.APPEND).write('''

android {
    productFlavors {
        $name {
            applicationIdSuffix ".$name"
            versionNameSuffix "-$name"
        }
    }
}
    ''');
  }

  Future<Null> introduceError() async {
    final File buildScript = new File(
      path.join(androidPath, 'app', 'build.gradle'),
    );
    await buildScript.writeAsString((await buildScript.readAsString()).replaceAll('buildTypes', 'builTypes'));
  }

  Future<Null> runGradleTask(String task) async {
    final ProcessResult result = await resultOfGradleTask(task);
    if (result.exitCode != 0) {
      print('stdout:');
      print(result.stdout);
      print('stderr:');
      print(result.stderr);
    }
    if (result.exitCode != 0)
      throw 'Gradle exited with error';
  }

  Future<ProcessResult> resultOfGradleTask(String task) {
    return Process.run(
      './gradlew',
      <String>['app:$task'],
      workingDirectory: androidPath,
      environment: <String, String>{ 'JAVA_HOME': javaPath }
    );
  }

  Future<ProcessResult> resultOfFlutterCommand(String command, List<String> options) {
    return Process.run(
      path.join(flutterDirectory.path, 'bin', 'flutter'),
      <String>[command]..addAll(options),
      workingDirectory: rootPath,
    );
  }
}

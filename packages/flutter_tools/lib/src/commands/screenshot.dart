// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:flutter_tools/src/device.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../base/utils.dart';
import '../globals.dart';
import '../runner/flutter_command.dart';

const String _kOut = 'out';
const String _kSkia = 'skia';
const String _kSkiaServe = 'skiaserve';

class ScreenshotCommand extends FlutterCommand {
  ScreenshotCommand() {
    argParser.addOption(
      _kOut,
      abbr: 'o',
      help: 'Location to write the screenshot.',
    );
    argParser.addOption(
      _kSkia,
      valueHelp: 'port',
      help: 'Retrieve the last frame rendered by a Flutter app as a Skia picture\n'
        'using the specified diagnostic server port.\n'
        'To find the diagnostic server port number, use "flutter run --verbose"\n'
        'and look for "Diagnostic server listening on" in the output.'
    );
    argParser.addOption(
      _kSkiaServe,
      valueHelp: 'url',
      help: 'Post the picture to a skiaserve debugger at this URL.',
    );
  }

  @override
  String get name => 'screenshot';

  @override
  String get description => 'Take a screenshot from a connected device.';

  @override
  final List<String> aliases = <String>['pic'];

  Device device;

  @override
  Future<int> verifyThenRunCommand() async {
    if (argResults[_kSkia] != null) {
      if (argResults[_kOut] != null && argResults[_kSkiaServe] != null) {
        printError('Cannot specify both --$_kOut and --$_kSkiaServe');
        return 1;
      }
    } else {
      if (argResults[_kSkiaServe] != null) {
        printError('Must specify --$_kSkia with --$_kSkiaServe');
        return 1;
      }
      device = await findTargetDevice();
      if (device == null) {
        printError('Must specify --$_kSkia or have a connected device');
        return 1;
      }
      if (!device.supportsScreenshot && argResults[_kSkia] == null) {
        printError('Screenshot not supported for ${device.name}.');
        return 1;
      }
    }
    return super.verifyThenRunCommand();
  }

  @override
  Future<int> runCommand() async {
    File outputFile;
    if (argResults.wasParsed(_kOut))
      outputFile = new File(argResults[_kOut]);

    if (argResults[_kSkia] != null) {
      return runSkia(outputFile);
    } else {
      return runScreenshot(outputFile);
    }
  }

  Future<int> runScreenshot(File outputFile) async {
    outputFile ??= getUniqueFile(Directory.current, 'flutter', 'png');
    try {
      if (await device.takeScreenshot(outputFile)) {
        await showOutputFileInfo(outputFile);
        return 0;
      }
    } catch (error) {
      printError('Error taking screenshot: $error');
    }
    return 1;
  }

  Future<int> runSkia(File outputFile) async {
    Uri skpUri = new Uri(scheme: 'http', host: '127.0.0.1',
        port: int.parse(argResults[_kSkia]),
        path: '/skp');

    void printErrorHelpText() {
      printError('');
      printError('Be sure the --$_kSkia= option specifies the diagnostic server port, not the observatory port.');
      printError('To find the diagnostic server port number, use "flutter run --verbose"');
      printError('and look for "Diagnostic server listening on" in the output.');
    }

    http.StreamedResponse skpResponse;
    try {
      skpResponse = await new http.Request('GET', skpUri).send();
    } on SocketException catch (e) {
      printError('Skia screenshot failed: $skpUri\n$e');
      printErrorHelpText();
      return 1;
    }
    if (skpResponse.statusCode != HttpStatus.OK) {
      String error = await skpResponse.stream.toStringStream().join();
      printError('Error: $error');
      printErrorHelpText();
      return 1;
    }

    if (argResults[_kSkiaServe] != null) {
      Uri skiaserveUri = Uri.parse(argResults[_kSkiaServe]);
      Uri postUri = new Uri.http(skiaserveUri.authority, '/new');
      http.MultipartRequest postRequest = new http.MultipartRequest('POST', postUri);
      postRequest.files.add(new http.MultipartFile(
          'file', skpResponse.stream, skpResponse.contentLength));

      http.StreamedResponse postResponse = await postRequest.send();
      if (postResponse.statusCode != HttpStatus.OK) {
        printError('Failed to post Skia picture to skiaserve.');
        printErrorHelpText();
        return 1;
      }
    } else {
      outputFile ??= getUniqueFile(Directory.current, 'flutter', 'skp');
      IOSink sink = outputFile.openWrite();
      await sink.addStream(skpResponse.stream);
      await sink.close();
      await showOutputFileInfo(outputFile);
      if (await outputFile.length() < 1000) {
        String content = await outputFile.readAsString();
        if (content.startsWith('{"jsonrpc":"2.0", "error"')) {
          printError('');
          printError('It appears the output file contains an error message, not valid skia output.');
          printErrorHelpText();
          return 1;
        }
      }
    }
    return 0;
  }

  Future<Null> showOutputFileInfo(File outputFile) async {
    int sizeKB = (await outputFile.length()) ~/ 1000;
    printStatus('Screenshot written to ${path.relative(outputFile.path)} (${sizeKB}kb).');
  }
}

// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import '../base/logger.dart';
import '../base/utils.dart';
import '../cache.dart';
import '../dart/sdk.dart';
import '../globals.dart';
import 'analyze_base.dart';

class AnalyzeContinuously extends AnalyzeBase {
  final List<Directory> repoAnalysisEntryPoints;

  AnalyzeContinuously(ArgResults argResults, this.repoAnalysisEntryPoints) : super(argResults);

  String analysisTarget;
  bool firstAnalysis = true;
  Set<String> analyzedPaths = new Set<String>();
  Map<String, List<AnalysisError>> analysisErrors = <String, List<AnalysisError>>{};
  Stopwatch analysisTimer;
  int lastErrorCount = 0;
  Status analysisStatus;

  @override
  Future<int> analyze() async {
    List<String> directories;

    if (argResults['flutter-repo']) {
      directories = repoAnalysisEntryPoints.map((Directory dir) => dir.path).toList();
      analysisTarget = 'Flutter repository';
      printTrace('Analyzing Flutter repository:');
      for (String projectPath in directories)
        printTrace('  ${path.relative(projectPath)}');
    } else {
      directories = <String>[Directory.current.path];
      analysisTarget = Directory.current.path;
    }

    AnalysisServer server = new AnalysisServer(dartSdkPath, directories);
    server.onAnalyzing.listen((bool isAnalyzing) => _handleAnalysisStatus(server, isAnalyzing));
    server.onErrors.listen(_handleAnalysisErrors);

    Cache.releaseLockEarly();

    await server.start();
    final int exitCode = await server.onExit;

    printStatus('Analysis server exited with code $exitCode.');
    return 0;
  }

  void _handleAnalysisStatus(AnalysisServer server, bool isAnalyzing) {
    if (isAnalyzing) {
      analysisStatus?.cancel();
      if (!firstAnalysis)
        printStatus('\n');
      analysisStatus = logger.startProgress('Analyzing $analysisTarget...');
      analyzedPaths.clear();
      analysisTimer = new Stopwatch()..start();
    } else {
      analysisStatus?.stop();
      analysisTimer.stop();

      logger.printStatus(terminal.clearScreen(), newline: false);

      // Remove errors for deleted files, sort, and print errors.
      final List<AnalysisError> errors = <AnalysisError>[];
      for (String path in analysisErrors.keys.toList()) {
        if (FileSystemEntity.isFileSync(path)) {
          errors.addAll(analysisErrors[path]);
        } else {
          analysisErrors.remove(path);
        }
      }

      errors.sort();

      for (AnalysisError error in errors) {
        printStatus(error.toString());
        if (error.code != null)
          printTrace('error code: ${error.code}');
      }

      dumpErrors(errors.map/*<String>*/((AnalysisError error) => error.toLegacyString()));

      // Print an analysis summary.
      String errorsMessage;

      int issueCount = errors.length;
      int issueDiff = issueCount - lastErrorCount;
      lastErrorCount = issueCount;

      if (firstAnalysis)
        errorsMessage = '$issueCount ${pluralize('issue', issueCount)} found';
      else if (issueDiff > 0)
        errorsMessage = '$issueCount ${pluralize('issue', issueCount)} found ($issueDiff new)';
      else if (issueDiff < 0)
        errorsMessage = '$issueCount ${pluralize('issue', issueCount)} found (${-issueDiff} fixed)';
      else if (issueCount != 0)
        errorsMessage = '$issueCount ${pluralize('issue', issueCount)} found';
      else
        errorsMessage = 'no issues found';

      String files = '${analyzedPaths.length} ${pluralize('file', analyzedPaths.length)}';
      String seconds = (analysisTimer.elapsedMilliseconds / 1000.0).toStringAsFixed(2);
      printStatus('$errorsMessage • analyzed $files, $seconds seconds');

      if (firstAnalysis && isBenchmarking) {
        writeBenchmark(analysisTimer, issueCount, -1); // TODO(ianh): track members missing dartdocs instead of saying -1
        server.dispose().then((_) => exit(issueCount > 0 ? 1 : 0));
      }

      firstAnalysis = false;
    }
  }

  bool _filterError(AnalysisError error) {
    // TODO(devoncarew): Also filter the regex items from `analyzeOnce()`.

    if (error.type == 'TODO')
      return true;

    return false;
  }

  void _handleAnalysisErrors(FileAnalysisErrors fileErrors) {
    fileErrors.errors.removeWhere(_filterError);

    analyzedPaths.add(fileErrors.file);
    analysisErrors[fileErrors.file] = fileErrors.errors;
  }
}

class AnalysisServer {
  AnalysisServer(this.sdk, this.directories);

  final String sdk;
  final List<String> directories;

  Process _process;
  StreamController<bool> _analyzingController = new StreamController<bool>.broadcast();
  StreamController<FileAnalysisErrors> _errorsController = new StreamController<FileAnalysisErrors>.broadcast();

  int _id = 0;

  Future<Null> start() async {
    String snapshot = path.join(sdk, 'bin/snapshots/analysis_server.dart.snapshot');
    List<String> args = <String>[snapshot, '--sdk', sdk];

    printTrace('dart ${args.join(' ')}');
    _process = await Process.start(path.join(dartSdkPath, 'bin', 'dart'), args);
    _process.exitCode.whenComplete(() => _process = null);

    Stream<String> errorStream = _process.stderr.transform(UTF8.decoder).transform(const LineSplitter());
    errorStream.listen((String error) => printError(error));

    Stream<String> inStream = _process.stdout.transform(UTF8.decoder).transform(const LineSplitter());
    inStream.listen(_handleServerResponse);

    // Available options (many of these are obsolete):
    //   enableAsync, enableDeferredLoading, enableEnums, enableNullAwareOperators,
    //   enableSuperMixins, generateDart2jsHints, generateHints, generateLints
    _sendCommand('analysis.updateOptions', <String, dynamic>{
      'options': <String, dynamic>{
        'enableSuperMixins': true
      }
    });

    _sendCommand('server.setSubscriptions', <String, dynamic>{
      'subscriptions': <String>['STATUS']
    });

    _sendCommand('analysis.setAnalysisRoots', <String, dynamic>{
      'included': directories,
      'excluded': <String>[]
    });
  }

  Stream<bool> get onAnalyzing => _analyzingController.stream;
  Stream<FileAnalysisErrors> get onErrors => _errorsController.stream;

  Future<int> get onExit => _process.exitCode;

  void _sendCommand(String method, Map<String, dynamic> params) {
    String message = JSON.encode(<String, dynamic> {
      'id': (++_id).toString(),
      'method': method,
      'params': params
    });
    _process.stdin.writeln(message);
    printTrace('==> $message');
  }

  void _handleServerResponse(String line) {
    printTrace('<== $line');

    dynamic response = JSON.decode(line);

    if (response is Map<dynamic, dynamic>) {
      if (response['event'] != null) {
        String event = response['event'];
        dynamic params = response['params'];

        if (params is Map<dynamic, dynamic>) {
          if (event == 'server.status')
            _handleStatus(response['params']);
          else if (event == 'analysis.errors')
            _handleAnalysisIssues(response['params']);
          else if (event == 'server.error')
            _handleServerError(response['params']);
        }
      } else if (response['error'] != null) {
        // Fields are 'code', 'message', and 'stackTrace'.
        Map<String, dynamic> error = response['error'];
        printError('Error response from the server: ${error['code']} ${error['message']}');
        if (error['stackTrace'] != null)
          printError(error['stackTrace']);
      }
    }
  }

  void _handleStatus(Map<String, dynamic> statusInfo) {
    // {"event":"server.status","params":{"analysis":{"isAnalyzing":true}}}
    if (statusInfo['analysis'] != null) {
      bool isAnalyzing = statusInfo['analysis']['isAnalyzing'];
      _analyzingController.add(isAnalyzing);
    }
  }

  void _handleServerError(Map<String, dynamic> error) {
    // Fields are 'isFatal', 'message', and 'stackTrace'.
    printError('Error from the analysis server: ${error['message']}');
    if (error['stackTrace'] != null)
      printError(error['stackTrace']);
  }

  void _handleAnalysisIssues(Map<String, dynamic> issueInfo) {
    // {"event":"analysis.errors","params":{"file":"/Users/.../lib/main.dart","errors":[]}}
    String file = issueInfo['file'];
    List<AnalysisError> errors = issueInfo['errors'].map((Map<String, dynamic> json) => new AnalysisError(json)).toList();
    _errorsController.add(new FileAnalysisErrors(file, errors));
  }

  Future<bool> dispose() async {
    await _analyzingController.close();
    await _errorsController.close();
    return _process?.kill();
  }
}

class AnalysisError implements Comparable<AnalysisError> {
  AnalysisError(this.json);

  static final Map<String, int> _severityMap = <String, int> {
    'ERROR': 3,
    'WARNING': 2,
    'INFO': 1
  };

  // "severity":"INFO","type":"TODO","location":{
  //   "file":"/Users/.../lib/test.dart","offset":362,"length":72,"startLine":15,"startColumn":4
  // },"message":"...","hasFix":false}
  Map<String, dynamic> json;

  String get severity => json['severity'];
  int get severityLevel => _severityMap[severity] ?? 0;
  String get type => json['type'];
  String get message => json['message'];
  String get code => json['code'];

  String get file => json['location']['file'];
  int get startLine => json['location']['startLine'];
  int get startColumn => json['location']['startColumn'];
  int get offset => json['location']['offset'];

  @override
  int compareTo(AnalysisError other) {
    // Sort in order of file path, error location, severity, and message.
    if (file != other.file)
      return file.compareTo(other.file);

    if (offset != other.offset)
      return offset - other.offset;

    int diff = other.severityLevel - severityLevel;
    if (diff != 0)
      return diff;

    return message.compareTo(other.message);
  }

  @override
  String toString() {
    String relativePath = path.relative(file);
    return '${severity.toLowerCase().padLeft(7)} • $message • $relativePath:$startLine:$startColumn';
  }

  String toLegacyString() {
    return '[${severity.toLowerCase()}] $message ($file:$startLine:$startColumn)';
  }
}

class FileAnalysisErrors {
  FileAnalysisErrors(this.file, this.errors);

  final String file;
  final List<AnalysisError> errors;
}

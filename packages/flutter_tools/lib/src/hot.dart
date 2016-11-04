// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:stack_trace/stack_trace.dart';

import 'application_package.dart';
import 'asset.dart';
import 'base/logger.dart';
import 'base/process.dart';
import 'base/utils.dart';
import 'build_info.dart';
import 'cache.dart';
import 'commands/build_apk.dart';
import 'commands/install.dart';
import 'dart/package_map.dart';
import 'devfs.dart';
import 'device.dart';
import 'globals.dart';
import 'resident_runner.dart';
import 'toolchain.dart';
import 'vmservice.dart';

const bool kHotReloadDefault = true;

String getDevFSLoaderScript() {
  return path.absolute(path.join(Cache.flutterRoot,
                                 'packages',
                                 'flutter',
                                 'bin',
                                 'loader',
                                 'loader_app.dart'));
}

class DartDependencySetBuilder {
  DartDependencySetBuilder(this.mainScriptPath,
                           this.projectRootPath);

  final String mainScriptPath;
  final String projectRootPath;

  Set<String> build() {
    final String skySnapshotPath =
        ToolConfiguration.instance.getHostToolPath(HostTool.SkySnapshot);

    final List<String> args = <String>[
      skySnapshotPath,
      '--packages=${path.absolute(PackageMap.globalPackagesPath)}',
      '--print-deps',
      mainScriptPath
    ];

    String output = runSyncAndThrowStdErrOnError(args);

    final List<String> lines = LineSplitter.split(output).toList();
    final Set<String> minimalDependencies = new Set<String>();
    for (String line in lines) {
      // We need to convert the uris so that they are relative to the project
      // root and tweak package: uris so that they reflect their devFS location.
      if (line.startsWith('package:')) {
        // Swap out package: for packages/ because we place all package sources
        // under packages/.
        line = line.replaceFirst('package:', 'packages/');
      } else {
        // Ensure paths are relative to the project root.
        line = path.relative(line, from: projectRootPath);
      }
      minimalDependencies.add(line);
    }
    return minimalDependencies;
  }
}


class FirstFrameTimer {
  FirstFrameTimer(this.vmService);

  void start() {
    stopwatch.reset();
    stopwatch.start();
    _subscription = vmService.onExtensionEvent.listen(_onExtensionEvent);
  }

  /// Returns a Future which completes after the first frame event is received.
  Future<Null> firstFrame() => _completer.future;

  void _onExtensionEvent(ServiceEvent event) {
    if (event.extensionKind == 'Flutter.FirstFrame')
      _stop();
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
    stopwatch.stop();
    _completer.complete(null);
  }

  Duration get elapsed {
    assert(!stopwatch.isRunning);
    return stopwatch.elapsed;
  }

  final VMService vmService;
  final Stopwatch stopwatch = new Stopwatch();
  final Completer<Null> _completer = new Completer<Null>();
  StreamSubscription<ServiceEvent> _subscription;
}

class HotRunner extends ResidentRunner {
  HotRunner(
    Device device, {
    String target,
    DebuggingOptions debuggingOptions,
    bool usesTerminalUI: true,
    this.benchmarkMode: false,
  }) : super(device,
             target: target,
             debuggingOptions: debuggingOptions,
             usesTerminalUI: usesTerminalUI) {
    _projectRootPath = Directory.current.path;
  }

  ApplicationPackage _package;
  String _mainPath;
  String _projectRootPath;
  Set<String> _dartDependencies;
  int _observatoryPort;
  final AssetBundle bundle = new AssetBundle();
  final bool benchmarkMode;
  final Map<String, int> benchmarkData = new Map<String, int>();

  @override
  Future<int> run({
    Completer<DebugConnectionInfo> connectionInfoCompleter,
    Completer<Null> appStartedCompleter,
    String route,
    bool shouldBuild: true
  }) {
    // Don't let uncaught errors kill the process.
    return Chain.capture(() {
      return _run(
        connectionInfoCompleter: connectionInfoCompleter,
        appStartedCompleter: appStartedCompleter,
        route: route,
        shouldBuild: shouldBuild
      );
    }, onError: (dynamic error, StackTrace stackTrace) {
      printError('Exception from flutter run: $error', stackTrace);
    });
  }

  bool _refreshDartDependencies() {
    if (_dartDependencies != null) {
      // Already computed.
      return true;
    }
    DartDependencySetBuilder dartDependencySetBuilder =
        new DartDependencySetBuilder(_mainPath, _projectRootPath);
    try {
      _dartDependencies = dartDependencySetBuilder.build();
    } catch (error) {
      printStatus('Error detected in application source code:', emphasis: true);
      printError(error);
      return false;
    }
    return true;
  }

  Future<int> _run({
    Completer<DebugConnectionInfo> connectionInfoCompleter,
    Completer<Null> appStartedCompleter,
    String route,
    bool shouldBuild: true
  }) async {
    _mainPath = findMainDartFile(target);
    if (!FileSystemEntity.isFileSync(_mainPath)) {
      String message = 'Tried to run $_mainPath, but that file does not exist.';
      if (target == null)
        message += '\nConsider using the -t option to specify the Dart file to start.';
      printError(message);
      return 1;
    }

    _package = getApplicationPackageForPlatform(device.platform);

    if (_package == null) {
      String message = 'No application found for ${device.platform}.';
      String hint = getMissingPackageHintForPlatform(device.platform);
      if (hint != null)
        message += '\n$hint';
      printError(message);
      return 1;
    }

    // Determine the Dart dependencies eagerly.
    if (!_refreshDartDependencies()) {
      // Some kind of source level error or missing file in the Dart code.
      return 1;
    }

    // TODO(devoncarew): We shouldn't have to do type checks here.
    if (shouldBuild && device is AndroidDevice) {
      printTrace('Running build command.');

      int result = await buildApk(
        device.platform,
        target: target,
        buildMode: debuggingOptions.buildMode
      );

      if (result != 0)
        return result;
    }

    // TODO(devoncarew): Move this into the device.startApp() impls.
    if (_package != null) {
      printTrace("Stopping app '${_package.name}' on ${device.name}.");
      // We don't wait for the stop command to complete.
      device.stopApp(_package);
    }

    // Allow any stop commands from above to start work.
    await new Future<Duration>.delayed(Duration.ZERO);

    // TODO(devoncarew): This fails for ios devices - we haven't built yet.
    if (device is AndroidDevice) {
      printTrace('Running install command.');
      if (!(installApp(device, _package, uninstall: false)))
        return 1;
    }

    Map<String, dynamic> platformArgs = new Map<String, dynamic>();

    await startEchoingDeviceLog();

    printTrace('Launching loader on ${device.name}...');

    // Start the loader.
    Future<LaunchResult> futureResult = device.startApp(
      _package,
      debuggingOptions.buildMode,
      mainPath: getDevFSLoaderScript(),
      debuggingOptions: debuggingOptions,
      platformArgs: platformArgs,
      route: route
    );

    LaunchResult result = await futureResult;

    if (!result.started) {
      printError('Error launching DevFS loader on ${device.name}.');
      await stopEchoingDeviceLog();
      return 2;
    }

    _observatoryPort = result.observatoryPort;
    try {
      await connectToServiceProtocol(_observatoryPort);
    } catch (error) {
      printError('Error connecting to the service protocol: $error');
      return 2;
    }


    try {
      Uri baseUri = await _initDevFS();
      if (connectionInfoCompleter != null) {
        connectionInfoCompleter.complete(
          new DebugConnectionInfo(_observatoryPort, baseUri: baseUri.toString())
        );
      }
    } catch (error) {
      printError('Error initializing DevFS: $error');
      return 3;
    }
    _loaderShowMessage('Connecting...', progress: 0);
    _loaderShowExplanation('You can use hot reload to update your app on the fly, without restarting it.');
    bool devfsResult = await _updateDevFS(
      progressReporter: (int progress, int max) {
        if (progress % 10 == 0)
          _loaderShowMessage('Syncing files to device...', progress: progress, max: max);
      }
    );
    if (!devfsResult) {
      _loaderShowMessage('Failed.');
      printError('Could not perform initial file synchronization.');
      return 3;
    }

    await vmService.vm.refreshViews();
    printTrace('Connected to ${vmService.vm.mainView}.');

    printStatus('Running ${getDisplayPath(_mainPath)} on ${device.name}...');
    _loaderShowMessage('Launching...');
    await _launchFromDevFS(_package, _mainPath);

    printTrace('Application running.');

    setupTerminal();

    registerSignalHandlers();

    printTrace('Finishing file synchronization');
    // Finish the file sync now.
    await _updateDevFS();

    appStartedCompleter?.complete();

    if (benchmarkMode) {
      // We are running in benchmark mode.
      printStatus('Running in benchmark mode.');
      // Measure time to perform a hot restart.
      printStatus('Benchmarking hot restart');
      await restart(fullRestart: true);
      await vmService.vm.refreshViews();
      // TODO(johnmccutchan): Modify script entry point.
      printStatus('Benchmarking hot reload');
      // Measure time to perform a hot reload.
      await restart(fullRestart: false);
      printStatus('Benchmark completed. Exiting application.');
      await _cleanupDevFS();
      await stopEchoingDeviceLog();
      await stopApp();
      File benchmarkOutput = new File('hot_benchmark.json');
      benchmarkOutput.writeAsStringSync(toPrettyJson(benchmarkData));
    }

    return waitForAppToFinish();
  }

  @override
  Future<Null> handleTerminalCommand(String code) async {
    final String lower = code.toLowerCase();
    if ((lower == 'r') || (code == AnsiTerminal.KEY_F5)) {
      OperationResult result = await restart(fullRestart: code == 'R');
      if (!result.isOk) {
        // TODO(johnmccutchan): Attempt to determine the number of errors that
        // occurred and tighten this message.
        printStatus('Try again after fixing the above error(s).', emphasis: true);
      }
    }
  }

  void _loaderShowMessage(String message, { int progress, int max }) {
    currentView.uiIsolate.flutterLoaderShowMessage(message);
    if (progress != null) {
      currentView.uiIsolate.flutterLoaderSetProgress(progress.toDouble());
      currentView.uiIsolate.flutterLoaderSetProgressMax(max?.toDouble() ?? 0.0);
    } else {
      currentView.uiIsolate.flutterLoaderSetProgress(0.0);
      currentView.uiIsolate.flutterLoaderSetProgressMax(-1.0);
    }
  }

  void _loaderShowExplanation(String explanation) {
    currentView.uiIsolate.flutterLoaderShowExplanation(explanation);
  }

  DevFS _devFS;

  Future<Uri> _initDevFS() {
    String fsName = path.basename(_projectRootPath);
    _devFS = new DevFS(vmService,
                       fsName,
                       new Directory(_projectRootPath));
    return _devFS.create();
  }

  Future<bool> _updateDevFS({ DevFSProgressReporter progressReporter }) async {
    if (!_refreshDartDependencies()) {
      // Did not update DevFS because of a Dart source error.
      return false;
    }
    Status devFSStatus = logger.startProgress('Syncing files to device...');
    final bool rebuildBundle = bundle.needsBuild();
    if (rebuildBundle) {
      printTrace('Updating assets');
      await bundle.build();
    }
    await _devFS.update(progressReporter: progressReporter,
                        bundle: bundle,
                        bundleDirty: rebuildBundle,
                        fileFilter: _dartDependencies);
    devFSStatus.stop();
    // Clear the set after the sync.
    _dartDependencies = null;
    printTrace('Synced ${getSizeAsMB(_devFS.bytes)}.');
    return true;
  }

  Future<Null> _evictDirtyAssets() async {
    if (_devFS.dirtyAssetEntries.length == 0)
      return;
    if (currentView.uiIsolate == null)
      throw 'Application isolate not found';
    for (DevFSEntry entry in _devFS.dirtyAssetEntries) {
      await currentView.uiIsolate.flutterEvictAsset(entry.assetPath);
    }
  }

  Future<Null> _cleanupDevFS() async {
    if (_devFS != null) {
      // Cleanup the devFS; don't wait indefinitely, and ignore any errors.
      await _devFS.destroy()
        .timeout(new Duration(milliseconds: 250))
        .catchError((dynamic error) {
          printTrace('$error');
        });
    }
    _devFS = null;
  }

  Future<Null> _launchInView(String entryPath,
                             String packagesPath,
                             String assetsDirectoryPath) async {
    FlutterView view = vmService.vm.mainView;
    return view.runFromSource(entryPath, packagesPath, assetsDirectoryPath);
  }

  Future<Null> _launchFromDevFS(ApplicationPackage package,
                                String mainScript) async {
    String entryPath = path.relative(mainScript, from: _projectRootPath);
    String deviceEntryPath =
        _devFS.baseUri.resolve(entryPath).toFilePath();
    String devicePackagesPath =
        _devFS.baseUri.resolve('.packages').toFilePath();
    String deviceAssetsDirectoryPath =
        _devFS.baseUri.resolve(getAssetBuildDirectory()).toFilePath();
    await _launchInView(deviceEntryPath,
                        devicePackagesPath,
                        deviceAssetsDirectoryPath);
  }

  Future<OperationResult> _restartFromSources() async {
    FirstFrameTimer firstFrameTimer = new FirstFrameTimer(vmService);
    firstFrameTimer.start();
    bool updatedDevFS = await _updateDevFS();
    if (!updatedDevFS)
      return new OperationResult(1, 'Dart Source Error');
    await _launchFromDevFS(_package, _mainPath);
    bool waitForFrame =
        await currentView.uiIsolate.flutterFrameworkPresent();
    Status restartStatus =
        logger.startProgress('Waiting for application to start...');
    if (waitForFrame) {
      // Wait for the first frame to be rendered.
      await firstFrameTimer.firstFrame();
    }
    restartStatus.stop();
    if (waitForFrame) {
      printTrace('Restart performed in '
                 '${getElapsedAsMilliseconds(firstFrameTimer.elapsed)}.');
      if (benchmarkMode) {
        benchmarkData['hotRestartMillisecondsToFrame'] =
            firstFrameTimer.elapsed.inMilliseconds;
      }
      flutterUsage.sendTiming('hot', 'restart', firstFrameTimer.elapsed);
    }
    flutterUsage.sendEvent('hot', 'restart');
    return OperationResult.ok;
  }

  /// Returns [true] if the reload was successful.
  bool _validateReloadReport(Map<String, dynamic> reloadReport) {
    if (!reloadReport['success']) {
      printError('Hot reload was rejected:');
      for (Map<String, dynamic> notice in reloadReport['details']['notices'])
        printError('${notice['message']}');
      return false;
    }
    return true;
  }

  @override
  Future<OperationResult> restart({ bool fullRestart: false, bool pauseAfterRestart: false }) async {
    if (fullRestart) {
      Status status = logger.startProgress('Performing full restart...');
      try {
        await _restartFromSources();
        status.stop();
        printStatus('Restart complete.');
        return OperationResult.ok;
      } catch (error) {
        status.stop();
        rethrow;
      }
    } else {
      Status status = logger.startProgress('Performing hot reload...');
      try {
        OperationResult result = await _reloadSources(pause: pauseAfterRestart);
        status.stop();
        if (result.isOk)
          printStatus("${result.message}.");
        return result;
      } catch (error) {
        status.stop();
        rethrow;
      }
    }
  }

  Future<OperationResult> _reloadSources({ bool pause: false }) async {
    if (currentView.uiIsolate == null)
      throw 'Application isolate not found';
    FirstFrameTimer firstFrameTimer = new FirstFrameTimer(vmService);
    firstFrameTimer.start();
    if (_devFS != null) {
      bool updatedDevFS = await _updateDevFS();
      if (!updatedDevFS)
        return new OperationResult(1, 'Dart Source Error');
    }
    String reloadMessage;
    try {
      Map<String, dynamic> reloadReport =
          await currentView.uiIsolate.reloadSources(pause: pause);
      if (!_validateReloadReport(reloadReport)) {
        // Reload failed.
        flutterUsage.sendEvent('hot', 'reload-reject');
        return new OperationResult(1, 'reload rejected');
      } else {
        flutterUsage.sendEvent('hot', 'reload');
        int loadedLibraryCount = reloadReport['details']['loadedLibraryCount'];
        int finalLibraryCount = reloadReport['details']['finalLibraryCount'];
        reloadMessage = 'Reloaded $loadedLibraryCount of $finalLibraryCount libraries';
      }
    } catch (error, st) {
      int errorCode = error['code'];
      String errorMessage = error['message'];
      if (errorCode == Isolate.kIsolateReloadBarred) {
        printError('Unable to hot reload app due to an unrecoverable error in '
                   'the source code. Please address the error and then use '
                   '"R" to restart the app.');
        flutterUsage.sendEvent('hot', 'reload-barred');
        return new OperationResult(errorCode, errorMessage);
      }

      printError('Hot reload failed:\ncode = $errorCode\nmessage = $errorMessage\n$st');
      return new OperationResult(errorCode, errorMessage);
    }
    // Reload the isolate.
    await currentView.uiIsolate.reload();
    // Check if the isolate is paused.
    final ServiceEvent pauseEvent = currentView.uiIsolate.pauseEvent;
    if ((pauseEvent != null) && (pauseEvent.isPauseEvent)) {
      // Isolate is paused. Stop here.
      printTrace('Skipping reassemble because isolate is paused.');
      return OperationResult.ok;
    }
    await _evictDirtyAssets();
    printTrace('Reassembling application');
    bool waitForFrame = true;
    try {
      waitForFrame = (await currentView.uiIsolate.flutterReassemble() != null);
    } catch (_) {
      printError('Reassembling application failed.');
      return new OperationResult(1, 'error reassembling application');
    }
    try {
      /* ensure that a frame is scheduled */
      await currentView.uiIsolate.uiWindowScheduleFrame();
    } catch (_) {
      /* ignore any errors */
    }
    if (waitForFrame) {
      // When the framework is present, we can wait for the first frame
      // event and measure reload time.
      await firstFrameTimer.firstFrame();
      printTrace('Hot reload performed in '
                 '${getElapsedAsMilliseconds(firstFrameTimer.elapsed)}.');
      if (benchmarkMode) {
        benchmarkData['hotReloadMillisecondsToFrame'] =
            firstFrameTimer.elapsed.inMilliseconds;
      }
      flutterUsage.sendTiming('hot', 'reload', firstFrameTimer.elapsed);
    }
    return new OperationResult(OperationResult.ok.code, reloadMessage);
  }

  @override
  void printHelp({ @required bool details }) {
    printStatus('🔥  To hot reload your app on the fly, press "r" or F5. To restart the app entirely, press "R".', emphasis: true);
    printStatus('The Observatory debugger and profiler is available at: http://127.0.0.1:$_observatoryPort/');
    if (details) {
      printStatus('To dump the widget hierarchy of the app (debugDumpApp), press "w".');
      printStatus('To dump the rendering tree of the app (debugDumpRenderTree), press "r".');
      printStatus('To repeat this help message, press "h" or F1. To quit, press "q", F10, or Ctrl-C.');
    } else {
      printStatus('For a more detailed help message, press "h" or F1. To quit, press "q", F10, or Ctrl-C.');
    }
  }

  @override
  Future<Null> cleanupAfterSignal() async {
    await stopEchoingDeviceLog();
    await stopApp();
  }

  @override
  Future<Null> preStop() => _cleanupDevFS();

  @override
  Future<Null> cleanupAtFinish() async {
    await _cleanupDevFS();
    await stopEchoingDeviceLog();
  }
}

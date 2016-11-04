// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:meta/meta.dart';

import '../application_package.dart';
import '../build_info.dart';
import '../dart/package_map.dart';
import '../dart/pub.dart';
import '../device.dart';
import '../flx.dart' as flx;
import '../globals.dart';
import '../usage.dart';
import 'flutter_command_runner.dart';

typedef bool Validator();

abstract class FlutterCommand extends Command {
  FlutterCommand() {
    commandValidator = commonCommandValidator;
  }

  @override
  FlutterCommandRunner get runner => super.runner;

  /// Whether this command uses the 'target' option.
  bool _usesTargetOption = false;

  bool _usesPubOption = false;

  bool get shouldRunPub => _usesPubOption && argResults['pub'];

  BuildMode _defaultBuildMode;

  void usesTargetOption() {
    argParser.addOption('target',
      abbr: 't',
      defaultsTo: flx.defaultMainPath,
      help: 'Target app path / main entry-point file.');
    _usesTargetOption = true;
  }

  String get targetFile {
    if (argResults.wasParsed('target'))
      return argResults['target'];
    else if (argResults.rest.isNotEmpty)
      return argResults.rest.first;
    else
      return flx.defaultMainPath;
  }

  void usesPubOption() {
    argParser.addFlag('pub',
      defaultsTo: true,
      help: 'Whether to run "flutter packages get" before executing this command.');
    _usesPubOption = true;
  }

  void addBuildModeFlags({ bool defaultToRelease: true }) {
    defaultBuildMode = defaultToRelease ? BuildMode.release : BuildMode.debug;

    argParser.addFlag('debug',
      negatable: false,
      help: 'Build a debug version of your app${defaultToRelease ? '' : ' (default mode)'}.');
    argParser.addFlag('profile',
      negatable: false,
      help: 'Build a version of your app specialized for performance profiling.');
    argParser.addFlag('release',
      negatable: false,
      help: 'Build a release version of your app${defaultToRelease ? ' (default mode)' : ''}.');
  }

  set defaultBuildMode(BuildMode buildMode) {
    _defaultBuildMode = buildMode;
  }

  BuildMode getBuildMode() {
    List<bool> modeFlags = <bool>[argResults['debug'], argResults['profile'], argResults['release']];
    if (modeFlags.where((bool flag) => flag).length > 1)
      throw new UsageException('Only one of --debug, --profile, or --release can be specified.', null);
    if (argResults['debug'])
      return BuildMode.debug;
    if (argResults['profile'])
      return BuildMode.profile;
    if (argResults['release'])
      return BuildMode.release;
    return _defaultBuildMode;
  }

  void setupApplicationPackages() {
    applicationPackages ??= new ApplicationPackageStore();
  }

  /// The path to send to Google Analytics. Return `null` here to disable
  /// tracking of the command.
  String get usagePath => name;

  /// Runs this command.
  ///
  /// Rather than overriding this method, subclasses should override
  /// [verifyThenRunCommand] to perform any verification
  /// and [runCommand] to execute the command
  /// so that this method can record and report the overall time to analytics.
  @override
  Future<int> run() {
    Stopwatch stopwatch = new Stopwatch()..start();
    UsageTimer analyticsTimer = usagePath == null ? null : flutterUsage.startTimer(name);

    if (flutterUsage.isFirstRun)
      flutterUsage.printUsage();

    return verifyThenRunCommand().then((int exitCode) {
      int ms = stopwatch.elapsedMilliseconds;
      printTrace("'flutter $name' took ${ms}ms; exiting with code $exitCode.");
      analyticsTimer?.finish();
      return exitCode;
    });
  }

  /// Perform validation then call [runCommand] to execute the command.
  /// Return a [Future] that completes with an exit code
  /// indicating whether execution was successful.
  ///
  /// Subclasses should override this method to perform verification
  /// then call this method to execute the command
  /// rather than calling [runCommand] directly.
  @mustCallSuper
  Future<int> verifyThenRunCommand() async {
    // Populate the cache. We call this before pub get below so that the sky_engine
    // package is available in the flutter cache for pub to find.
    await cache.updateAll();

    if (shouldRunPub) {
      int exitCode = await pubGet();
      if (exitCode != 0)
        return exitCode;
    }

    setupApplicationPackages();

    String commandPath = usagePath;
    if (commandPath != null)
      flutterUsage.sendCommand(usagePath);

    return await runCommand();
  }

  /// Subclasses must implement this to execute the command.
  Future<int> runCommand();

  /// Find and return the target [Device] based upon currently connected
  /// devices and criteria entered by the user on the command line.
  /// If a device cannot be found that meets specified criteria,
  /// then print an error message and return `null`.
  Future<Device> findTargetDevice({bool androidOnly: false}) async {
    if (!doctor.canLaunchAnything) {
      printError("Unable to locate a development device; please run 'flutter doctor' "
          "for information about installing additional components.");
      return null;
    }

    List<Device> devices = await deviceManager.getDevices();

    if (devices.isEmpty && deviceManager.hasSpecifiedDeviceId) {
      printStatus("No devices found with name or id "
          "matching '${deviceManager.specifiedDeviceId}'");
      return null;
    } else if (devices.isEmpty) {
      printNoConnectedDevices();
      return null;
    }

    devices = devices.where((Device device) => device.isSupported()).toList();

    if (androidOnly)
      devices = devices.where((Device device) => device.platform == TargetPlatform.android_arm).toList();

    if (devices.isEmpty) {
      printStatus('No supported devices connected.');
      return null;
    } else if (devices.length > 1) {
      if (deviceManager.hasSpecifiedDeviceId) {
        printStatus("Found ${devices.length} devices with name or id matching "
            "'${deviceManager.specifiedDeviceId}':");
      } else {
        printStatus("More than one device connected; please specify a device with "
            "the '-d <deviceId>' flag.");
        devices = await deviceManager.getAllConnectedDevices();
      }
      printStatus('');
      Device.printDevices(devices);
      return null;
    }
    return devices.single;
  }

  void printNoConnectedDevices() {
    printStatus('No connected devices.');
  }

  // This is a field so that you can modify the value for testing.
  Validator commandValidator;

  bool commonCommandValidator() {
    if (!PackageMap.isUsingCustomPackagesPath) {
      // Don't expect a pubspec.yaml file if the user passed in an explicit .packages file path.
      if (!FileSystemEntity.isFileSync('pubspec.yaml')) {
        printError('Error: No pubspec.yaml file found.\n'
          'This command should be run from the root of your Flutter project.\n'
          'Do not run this command from the root of your git clone of Flutter.');
        return false;
      }
    }

    if (_usesTargetOption) {
      String targetPath = targetFile;
      if (!FileSystemEntity.isFileSync(targetPath)) {
        printError('Target file "$targetPath" not found.');
        return false;
      }
    }

    // Validate the current package map only if we will not be running "pub get" later.
    if (!(_usesPubOption && argResults['pub'])) {
      String error = new PackageMap(PackageMap.globalPackagesPath).checkValid();
      if (error != null) {
        printError(error);
        return false;
      }
    }

    return true;
  }

  ApplicationPackageStore applicationPackages;
}

// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import '../artifacts.dart';
import '../base/file_system.dart';
import '../base/process.dart';
import '../base/utils.dart';
import '../build_info.dart';
import '../cache.dart';
import '../globals.dart';

final RegExp _settingExpr = new RegExp(r'(\w+)\s*=\s*(\S+)');
final RegExp _varExpr = new RegExp(r'\$\((.*)\)');

String flutterFrameworkDir(BuildMode mode) {
  return fs.path.normalize(fs.path.dirname(artifacts.getArtifactPath(Artifact.flutterFramework, TargetPlatform.ios, mode)));
}

void updateXcodeGeneratedProperties({
  @required String projectPath,
  @required BuildInfo buildInfo,
  @required String target,
  @required bool hasPlugins,
}) {
  final StringBuffer localsBuffer = new StringBuffer();

  localsBuffer.writeln('// This is a generated file; do not edit or check into version control.');

  final String flutterRoot = fs.path.normalize(Cache.flutterRoot);
  localsBuffer.writeln('FLUTTER_ROOT=$flutterRoot');

  // This holds because requiresProjectRoot is true for this command
  localsBuffer.writeln('FLUTTER_APPLICATION_PATH=${fs.path.normalize(projectPath)}');

  // Relative to FLUTTER_APPLICATION_PATH, which is [Directory.current].
  localsBuffer.writeln('FLUTTER_TARGET=$target');

  // The runtime mode for the current build.
  localsBuffer.writeln('FLUTTER_BUILD_MODE=${buildInfo.modeName}');

  // The build outputs directory, relative to FLUTTER_APPLICATION_PATH.
  localsBuffer.writeln('FLUTTER_BUILD_DIR=${getBuildDirectory()}');

  localsBuffer.writeln('SYMROOT=\${SOURCE_ROOT}/../${getIosBuildDirectory()}');

  localsBuffer.writeln('FLUTTER_FRAMEWORK_DIR=${flutterFrameworkDir(buildInfo.mode)}');

  if (artifacts is LocalEngineArtifacts) {
    final LocalEngineArtifacts localEngineArtifacts = artifacts;
    localsBuffer.writeln('LOCAL_ENGINE=${localEngineArtifacts.engineOutPath}');
  }

  // Add dependency to CocoaPods' generated project only if plugins are used.
  if (hasPlugins)
    localsBuffer.writeln('#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"');

  final File localsFile = fs.file(fs.path.join(projectPath, 'ios', 'Flutter', 'Generated.xcconfig'));
  localsFile.createSync(recursive: true);
  localsFile.writeAsStringSync(localsBuffer.toString());
}

Map<String, String> getXcodeBuildSettings(String xcodeProjPath, String target) {
  final String absProjPath = fs.path.absolute(xcodeProjPath);
  final String out = runCheckedSync(<String>[
    '/usr/bin/xcodebuild', '-project', absProjPath, '-target', target, '-showBuildSettings'
  ]);
  final Map<String, String> settings = <String, String>{};
  for (String line in out.split('\n').where(_settingExpr.hasMatch)) {
    final Match match = _settingExpr.firstMatch(line);
    settings[match[1]] = match[2];
  }
  return settings;
}

/// Substitutes variables in [str] with their values from the specified Xcode
/// project and target.
String substituteXcodeVariables(String str, Map<String, String> xcodeBuildSettings) {
  final Iterable<Match> matches = _varExpr.allMatches(str);
  if (matches.isEmpty)
    return str;

  return str.replaceAllMapped(_varExpr, (Match m) => xcodeBuildSettings[m[1]] ?? m[0]);
}

/// Information about an Xcode project.
///
/// Represents the output of `xcodebuild -list`.
class XcodeProjectInfo {
  XcodeProjectInfo(this.targets, this.buildConfigurations, this.schemes);

  factory XcodeProjectInfo.fromProjectSync(String projectPath) {
    final String out = runCheckedSync(<String>[
      '/usr/bin/xcodebuild', '-list',
    ], workingDirectory: projectPath);
    return new XcodeProjectInfo.fromXcodeBuildOutput(out);
  }

  factory XcodeProjectInfo.fromXcodeBuildOutput(String output) {
    final List<String> targets = <String>[];
    final List<String> buildConfigurations = <String>[];
    final List<String> schemes = <String>[];
    List<String> collector;
    for (String line in output.split('\n')) {
      if (line.isEmpty) {
        collector = null;
        continue;
      } else if (line.endsWith('Targets:')) {
        collector = targets;
        continue;
      } else if (line.endsWith('Build Configurations:')) {
        collector = buildConfigurations;
        continue;
      } else if (line.endsWith('Schemes:')) {
        collector = schemes;
        continue;
      }
      collector?.add(line.trim());
    }
    if (schemes.isEmpty)
      schemes.add('Runner');
    return new XcodeProjectInfo(targets, buildConfigurations, schemes);
  }

  final List<String> targets;
  final List<String> buildConfigurations;
  final List<String> schemes;

  bool get definesCustomTargets => !(targets.contains('Runner') && targets.length == 1);
  bool get definesCustomSchemes => !(schemes.contains('Runner') && schemes.length == 1);
  bool get definesCustomBuildConfigurations {
    return !(buildConfigurations.contains('Debug') &&
        buildConfigurations.contains('Release') &&
        buildConfigurations.length == 2);
  }

  /// The expected scheme for [buildInfo].
  static String expectedSchemeFor(BuildInfo buildInfo) {
    return toTitleCase(buildInfo.flavor ?? 'runner');
  }

  /// The expected build configuration for [buildInfo] and [scheme].
  static String expectedBuildConfigurationFor(BuildInfo buildInfo, String scheme) {
    final String baseConfiguration = _baseConfigurationFor(buildInfo);
    if (buildInfo.flavor == null)
      return baseConfiguration;
    else
      return baseConfiguration + '-$scheme';
  }

  /// Returns unique scheme matching [buildInfo], or null, if there is no unique
  /// best match.
  String schemeFor(BuildInfo buildInfo) {
    final String expectedScheme = expectedSchemeFor(buildInfo);
    if (schemes.contains(expectedScheme))
      return expectedScheme;
    return _uniqueMatch(schemes, (String candidate) {
      return candidate.toLowerCase() == expectedScheme.toLowerCase();
    });
  }

  /// Returns unique build configuration matching [buildInfo] and [scheme], or
  /// null, if there is no unique best match.
  String buildConfigurationFor(BuildInfo buildInfo, String scheme) {
    final String expectedConfiguration = expectedBuildConfigurationFor(buildInfo, scheme);
    if (buildConfigurations.contains(expectedConfiguration))
      return expectedConfiguration;
    final String baseConfiguration = _baseConfigurationFor(buildInfo);
    return _uniqueMatch(buildConfigurations, (String candidate) {
      candidate = candidate.toLowerCase();
      if (buildInfo.flavor == null)
        return candidate == expectedConfiguration.toLowerCase();
      else
        return candidate.contains(baseConfiguration.toLowerCase()) && candidate.contains(scheme.toLowerCase());
    });
  }

  static String _baseConfigurationFor(BuildInfo buildInfo) => buildInfo.isDebug ? 'Debug' : 'Release';

  static String _uniqueMatch(Iterable<String> strings, bool matches(String s)) {
    final List<String> options = strings.where(matches).toList();
    if (options.length == 1)
      return options.first;
    else
      return null;
  }

  @override
  String toString() {
    return 'XcodeProjectInfo($targets, $buildConfigurations, $schemes)';
  }
}

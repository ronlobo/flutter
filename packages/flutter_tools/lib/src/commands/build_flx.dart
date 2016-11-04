// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../build_info.dart';
import '../flx.dart';
import '../globals.dart';
import 'build.dart';

class BuildFlxCommand extends BuildSubCommand {
  BuildFlxCommand({bool verboseHelp: false}) {
    usesTargetOption();
    argParser.addFlag('precompiled', negatable: false);
    // This option is still referenced by the iOS build scripts. We should
    // remove it once we've updated those build scripts.
    argParser.addOption('asset-base', help: 'Ignored. Will be removed.', hide: !verboseHelp);
    argParser.addOption('manifest', defaultsTo: defaultManifestPath);
    argParser.addOption('private-key', defaultsTo: defaultPrivateKeyPath);
    argParser.addOption('output-file', abbr: 'o', defaultsTo: defaultFlxOutputPath);
    argParser.addOption('snapshot', defaultsTo: defaultSnapshotPath);
    argParser.addOption('depfile', defaultsTo: defaultDepfilePath);
    argParser.addOption('working-dir', defaultsTo: getAssetBuildDirectory());
    argParser.addFlag('include-roboto-fonts', defaultsTo: true);
    argParser.addFlag('report-licensed-packages', help: 'Whether to report the names of all the packages that are included in the application\'s LICENSE file.', defaultsTo: false);
    usesPubOption();
  }

  @override
  final String name = 'flx';

  @override
  final String description = 'Build a Flutter FLX file from your app.';

  @override
  final String usageFooter = 'FLX files are archives of your application code and resources; '
    'they are used by some Flutter Android and iOS runtimes.';

  @override
  Future<int> runCommand() async {
    await super.runCommand();
    String outputPath = argResults['output-file'];

    return await build(
      mainPath: targetFile,
      manifestPath: argResults['manifest'],
      outputPath: outputPath,
      snapshotPath: argResults['snapshot'],
      depfilePath: argResults['depfile'],
      privateKeyPath: argResults['private-key'],
      workingDirPath: argResults['working-dir'],
      precompiledSnapshot: argResults['precompiled'],
      includeRobotoFonts: argResults['include-roboto-fonts'],
      reportLicensedPackages: argResults['report-licensed-packages']
    ).then((int result) {
      if (result == 0)
        printStatus('Built $outputPath.');
      else
        printError('Error building $outputPath: $result.');
      return result;
    });
  }
}

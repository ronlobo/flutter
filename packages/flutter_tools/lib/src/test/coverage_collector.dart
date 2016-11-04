// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:path/path.dart' as path;

import '../dart/package_map.dart';
import '../globals.dart';

class CoverageCollector {
  static final CoverageCollector instance = new CoverageCollector();

  bool enabled = false;
  int observatoryPort;

  void collectCoverage({
    String host,
    int port,
    Process processToKill
  }) {
    if (enabled) {
      assert(_jobs != null);
      _jobs.add(_startJob(
        host: host,
        port: port,
        processToKill: processToKill
      ));
    } else {
      processToKill.kill();
    }
  }

  Future<Null> _startJob({
    String host,
    int port,
    Process processToKill
  }) async {
    int pid = processToKill.pid;
    printTrace('collecting coverage data from pid $pid on port $port');
    Map<String, dynamic> data = await collect(host, port, false, false);
    printTrace('done collecting coverage data from pid $pid');
    processToKill.kill();
    Map<String, dynamic> hitmap = createHitmap(data['coverage']);
    if (_globalHitmap == null)
      _globalHitmap = hitmap;
    else
      mergeHitmaps(hitmap, _globalHitmap);
    printTrace('done merging data from pid $pid into global coverage map');
  }

  Future<Null> finishPendingJobs() async {
    await Future.wait(_jobs.toList(), eagerError: true);
  }

  List<Future<Null>> _jobs = <Future<Null>>[];
  Map<String, dynamic> _globalHitmap;

  Future<String> finalizeCoverage({ Formatter formatter }) async {
    assert(enabled);
    await finishPendingJobs();
    printTrace('formating coverage data');
    if (_globalHitmap == null)
      return null;
    if (formatter == null) {
      Resolver resolver = new Resolver(packagesPath: PackageMap.globalPackagesPath);
      String packagePath = Directory.current.path;
      List<String> reportOn = <String>[path.join(packagePath, 'lib')];
      formatter = new LcovFormatter(resolver, reportOn: reportOn, basePath: packagePath);
    }
    return await formatter.format(_globalHitmap);
  }
}

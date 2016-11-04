// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../globals.dart';
import '../runner/flutter_command.dart';

class DoctorCommand extends FlutterCommand {
  @override
  final String name = 'doctor';

  @override
  final String description = 'Show information about the installed tooling.';

  @override
  Future<int> runCommand() async {
    await doctor.diagnose();
    return 0;
  }
}

// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// An object sent from the Flutter Driver to a Flutter application to instruct
/// the application to perform a task.
abstract class Command {
  /// Identifies the type of the command object and of the handler.
  String get kind;

  /// Serializes this command to parameter name/value pairs.
  Map<String, String> serialize();
}

/// An object sent from a Flutter application back to the Flutter Driver in
/// response to a command.
abstract class Result { // ignore: one_member_abstracts
  /// Serializes this message to a JSON map.
  Map<String, dynamic> toJson();
}

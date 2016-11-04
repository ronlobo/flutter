// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

bool get isRunningOnBot {
  // https://docs.travis-ci.com/user/environment-variables/#Default-Environment-Variables
  // CHROME_HEADLESS is one property set on Flutter's Chrome Infra bots.
  return
    Platform.environment['TRAVIS'] == 'true' ||
    Platform.environment['CONTINUOUS_INTEGRATION'] == 'true' ||
    Platform.environment['CHROME_HEADLESS'] == '1';
}

String hex(List<int> bytes) {
  StringBuffer result = new StringBuffer();
  for (int part in bytes)
    result.write('${part < 16 ? '0' : ''}${part.toRadixString(16)}');
  return result.toString();
}

String calculateSha(File file) {
  return hex(sha1.convert(file.readAsBytesSync()).bytes);
}

/// Convert `foo_bar` to `fooBar`.
String camelCase(String str) {
  int index = str.indexOf('_');
  while (index != -1 && index < str.length - 2) {
    str = str.substring(0, index) +
      str.substring(index + 1, index + 2).toUpperCase() +
      str.substring(index + 2);
    index = str.indexOf('_');
  }
  return str;
}

String toTitleCase(String str) {
  if (str.isEmpty)
    return str;
  return str.substring(0, 1).toUpperCase() + str.substring(1);
}

/// Return the plural of the given word (`cat(s)`).
String pluralize(String word, int count) => count == 1 ? word : word + 's';

/// Return the name of an enum item.
String getEnumName(dynamic enumItem) {
  String name = '$enumItem';
  int index = name.indexOf('.');
  return index == -1 ? name : name.substring(index + 1);
}

File getUniqueFile(Directory dir, String baseName, String ext) {
  int i = 1;

  while (true) {
    String name = '${baseName}_${i.toString().padLeft(2, '0')}.$ext';
    File file = new File(path.join(dir.path, name));
    if (!file.existsSync())
      return file;
    i++;
  }
}

String toPrettyJson(Object jsonable) {
  return new JsonEncoder.withIndent('  ').convert(jsonable) + '\n';
}

/// Return a String - with units - for the size in MB of the given number of bytes.
String getSizeAsMB(int bytesLength) {
  return '${(bytesLength / (1024 * 1024)).toStringAsFixed(1)}MB';
}

String getElapsedAsSeconds(Duration duration) {
  double seconds = duration.inMilliseconds / Duration.MILLISECONDS_PER_SECOND;
  return '${seconds.toStringAsFixed(2)} seconds';
}

String getElapsedAsMilliseconds(Duration duration) {
  return '${duration.inMilliseconds} ms';
}

/// Return a relative path if [fullPath] is contained by the cwd, else return an
/// absolute path.
String getDisplayPath(String fullPath) {
  String cwd = Directory.current.path + Platform.pathSeparator;
  return fullPath.startsWith(cwd) ?  fullPath.substring(cwd.length) : fullPath;
}

/// A class to maintain a list of items, fire events when items are added or
/// removed, and calculate a diff of changes when a new list of items is
/// available.
class ItemListNotifier<T> {
  ItemListNotifier() {
    _items = new Set<T>();
  }

  ItemListNotifier.from(List<T> items) {
    _items = new Set<T>.from(items);
  }

  Set<T> _items;

  StreamController<T> _addedController = new StreamController<T>.broadcast();
  StreamController<T> _removedController = new StreamController<T>.broadcast();

  Stream<T> get onAdded => _addedController.stream;
  Stream<T> get onRemoved => _removedController.stream;

  List<T> get items => _items.toList();

  void updateWithNewList(List<T> updatedList) {
    Set<T> updatedSet = new Set<T>.from(updatedList);

    Set<T> addedItems = updatedSet.difference(_items);
    Set<T> removedItems = _items.difference(updatedSet);

    _items = updatedSet;

    for (T item in addedItems)
      _addedController.add(item);
    for (T item in removedItems)
      _removedController.add(item);
  }

  /// Close the streams.
  void dispose() {
    _addedController.close();
    _removedController.close();
  }
}

class SettingsFile {
  SettingsFile.parse(String contents) {
    for (String line in contents.split('\n')) {
      line = line.trim();
      if (line.startsWith('#') || line.isEmpty)
        continue;
      int index = line.indexOf('=');
      if (index != -1)
        values[line.substring(0, index)] = line.substring(index + 1);
    }
  }

  factory SettingsFile.parseFromFile(File file) {
    return new SettingsFile.parse(file.readAsStringSync());
  }

  final Map<String, String> values = <String, String>{};

  void writeContents(File file) {
    file.writeAsStringSync(values.keys.map((String key) {
      return '$key=${values[key]}';
    }).join('\n'));
  }
}

/// A UUID generator. This will generate unique IDs in the format:
///
///     f47ac10b-58cc-4372-a567-0e02b2c3d479
///
/// The generated uuids are 128 bit numbers encoded in a specific string format.
///
/// For more information, see
/// http://en.wikipedia.org/wiki/Universally_unique_identifier.
class Uuid {
  Random _random = new Random();

  /// Generate a version 4 (random) uuid. This is a uuid scheme that only uses
  /// random numbers as the source of the generated uuid.
  String generateV4() {
    // Generate xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx / 8-4-4-4-12.
    int special = 8 + _random.nextInt(4);

    return
      '${_bitsDigits(16, 4)}${_bitsDigits(16, 4)}-'
          '${_bitsDigits(16, 4)}-'
          '4${_bitsDigits(12, 3)}-'
          '${_printDigits(special,  1)}${_bitsDigits(12, 3)}-'
          '${_bitsDigits(16, 4)}${_bitsDigits(16, 4)}${_bitsDigits(16, 4)}';
  }

  String _bitsDigits(int bitCount, int digitCount) =>
      _printDigits(_generateBits(bitCount), digitCount);

  int _generateBits(int bitCount) => _random.nextInt(1 << bitCount);

  String _printDigits(int value, int count) =>
      value.toRadixString(16).padLeft(count, '0');
}

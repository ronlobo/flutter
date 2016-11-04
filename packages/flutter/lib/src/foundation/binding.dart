// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:developer' as developer;
import 'dart:io' show exit;

import 'package:meta/meta.dart';

import 'assertions.dart';
import 'basic_types.dart';

/// Signature for service extensions.
///
/// The returned map must not contain the keys "type" or "method", as
/// they will be replaced before the value is sent to the client. The
/// "type" key will be set to the string `_extensionType` to indicate
/// that this is a return value from a service extension, and the
/// "method" key will be set to the full name of the method.
typedef Future<Map<String, dynamic>> ServiceExtensionCallback(Map<String, String> parameters);

/// Base class for mixins that provide singleton services (also known as
/// "bindings").
///
/// To use this class in a mixin, inherit from it and implement
/// [initInstances()]. The mixin is guaranteed to only be constructed
/// once in the lifetime of the app (more precisely, it will assert if
/// constructed twice in checked mode).
///
/// The top-most layer used to write the application will have a
/// concrete class that inherits from BindingBase and uses all the
/// various BindingBase mixins (such as [ServicesBinding]). For example, the
/// Widgets library in flutter introduces a binding called
/// [WidgetsFlutterBinding]. The relevant library defines how to create
/// the binding. It could be implied (for example,
/// [WidgetsFlutterBinding] is automatically started from [runApp]), or
/// the application might be required to explicitly call the
/// constructor.
abstract class BindingBase {
  /// Default abstract constructor for bindings.
  ///
  /// First calls [initInstances] to have bindings initialize their
  /// instance pointers and other state, then calls
  /// [initServiceExtensions] to have bindings initialize their
  /// observatory service extensions, if any.
  BindingBase() {
    developer.Timeline.startSync('Framework initialization');

    assert(!_debugInitialized);
    initInstances();
    assert(_debugInitialized);

    assert(!_debugServiceExtensionsRegistered);
    initServiceExtensions();
    assert(_debugServiceExtensionsRegistered);

    developer.postEvent('Flutter.FrameworkInitialization', <String, dynamic>{});

    developer.Timeline.finishSync();
  }

  static bool _debugInitialized = false;
  static bool _debugServiceExtensionsRegistered = false;

  /// The initialization method. Subclasses override this method to hook into
  /// the platform and otherwise configure their services. Subclasses must call
  /// "super.initInstances()".
  ///
  /// By convention, if the service is to be provided as a singleton, it should
  /// be exposed as `MixinClassName.instance`, a static getter that returns
  /// `MixinClassName._instance`, a static field that is set by
  /// `initInstances()`.
  void initInstances() {
    assert(!_debugInitialized);
    assert(() { _debugInitialized = true; return true; });
  }

  /// Called when the binding is initialized, to register service
  /// extensions.
  ///
  /// Bindings that want to expose service extensions should overload
  /// this method to register them using calls to
  /// [registerSignalServiceExtension],
  /// [registerBoolServiceExtension],
  /// [registerNumericServiceExtension], and
  /// [registerServiceExtension] (in increasing order of complexity).
  ///
  /// Implementations of this method must call their superclass
  /// implementation.
  ///
  /// Service extensions are only exposed when the observatory is
  /// included in the build, which should only happen in checked mode
  /// and in profile mode.
  ///
  /// See also:
  ///
  ///  * <https://github.com/dart-lang/sdk/blob/master/runtime/vm/service/service.md#rpcs-requests-and-responses>
  void initServiceExtensions() {
    assert(!_debugServiceExtensionsRegistered);
    registerSignalServiceExtension(
      name: 'reassemble',
      callback: reassembleApplication
    );
    registerSignalServiceExtension(
      name: 'exit',
      callback: _exitApplication
    );
    registerSignalServiceExtension(
      name: 'frameworkPresent',
      callback: () => null
    );
    assert(() { _debugServiceExtensionsRegistered = true; return true; });
  }

  /// Called when the ext.flutter.reassemble signal is sent by
  /// development tools.
  ///
  /// This is used by development tools when the application code has
  /// changed, to cause the application to pick up any changed code.
  /// Bindings are expected to use this method to reregister anything
  /// that uses closures, so that they do not keep pointing to old
  /// code, and to flush any caches of previously computed values, in
  /// case the new code would compute them differently.
  @mustCallSuper
  void reassembleApplication() {
    FlutterError.resetErrorCount();
  }


  /// Registers a service extension method with the given name (full
  /// name "ext.flutter.name"), which takes no arguments and returns
  /// no value.
  ///
  /// Calls the `callback` callback when the service extension is called.
  void registerSignalServiceExtension({
    @required String name,
    @required VoidCallback callback
  }) {
    assert(name != null);
    assert(callback != null);
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        callback();
        return <String, dynamic>{};
      }
    );
  }

  /// Registers a service extension method with the given name (full
  /// name "ext.flutter.name"), which takes a single argument
  /// "enabled" which can have the value "true" or the value "false"
  /// or can be omitted to read the current value. (Any value other
  /// than "true" is considered equivalent to "false". Other arguments
  /// are ignored.)
  ///
  /// Calls the `getter` callback to obtain the value when
  /// responding to the service extension method being called.
  ///
  /// Calls the `setter` callback with the new value when the
  /// service extension method is called with a new value.
  void registerBoolServiceExtension({
    String name,
    @required ValueGetter<bool> getter,
    @required ValueSetter<bool> setter
  }) {
    assert(name != null);
    assert(getter != null);
    assert(setter != null);
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        if (parameters.containsKey('enabled'))
          setter(parameters['enabled'] == 'true');
        return <String, dynamic>{ 'enabled': getter() };
      }
    );
  }

  /// Registers a service extension method with the given name (full
  /// name "ext.flutter.name"), which takes a single argument with the
  /// same name as the method which, if present, must have a value
  /// that can be parsed by [double.parse], and can be omitted to read
  /// the current value. (Other arguments are ignored.)
  ///
  /// Calls the `getter` callback to obtain the value when
  /// responding to the service extension method being called.
  ///
  /// Calls the `setter` callback with the new value when the
  /// service extension method is called with a new value.
  void registerNumericServiceExtension({
    @required String name,
    @required ValueGetter<double> getter,
    @required ValueSetter<double> setter
  }) {
    assert(name != null);
    assert(getter != null);
    assert(setter != null);
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        if (parameters.containsKey(name))
          setter(double.parse(parameters[name]));
        return <String, dynamic>{ name: getter() };
      }
    );
  }

  /// Registers a service extension method with the given name (full name
  /// "ext.flutter.name"), which optionally takes a single argument with the
  /// name "value". If the argument is omitted, the value is to be read,
  /// otherwise it is to be set. Returns the current value.
  ///
  /// Calls the `getter` callback to obtain the value when
  /// responding to the service extension method being called.
  ///
  /// Calls the `setter` callback with the new value when the
  /// service extension method is called with a new value.
  void registerStringServiceExtension({
    @required String name,
    @required ValueGetter<String> getter,
    @required ValueSetter<String> setter
  }) {
    assert(name != null);
    assert(getter != null);
    assert(setter != null);
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        if (parameters.containsKey('value'))
          setter(parameters['value']);
        return <String, dynamic>{ 'value': getter() };
      }
    );
  }

  /// Registers a service extension method with the given name (full
  /// name "ext.flutter.name"). The given callback is called when the
  /// extension method is called. The callback must return a [Future]
  /// that either eventually completes to a return value in the form
  /// of a name/value map where the values can all be converted to
  /// JSON using [JSON.encode], or fails. In case of failure, the
  /// failure is reported to the remote caller and is dumped to the
  /// logs.
  ///
  /// The returned map will be mutated.
  void registerServiceExtension({
    @required String name,
    @required ServiceExtensionCallback callback
  }) {
    assert(name != null);
    assert(callback != null);
    final String methodName = 'ext.flutter.$name';
    developer.registerExtension(methodName, (String method, Map<String, String> parameters) async {
      assert(method == methodName);
      dynamic caughtException;
      StackTrace caughtStack;
      Map<String, dynamic> result;
      try {
        result = await callback(parameters);
      } catch (exception, stack) {
        caughtException = exception;
        caughtStack = stack;
      }
      if (caughtException == null) {
        result['type'] = '_extensionType';
        result['method'] = method;
        return new developer.ServiceExtensionResponse.result(JSON.encode(result));
      } else {
        FlutterError.reportError(new FlutterErrorDetails(
          exception: caughtException,
          stack: caughtStack,
          context: 'during a service extension callback for "$method"'
        ));
        return new developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          JSON.encode(<String, dynamic>{
            'exception': caughtException.toString(),
            'stack': caughtStack.toString(),
            'method': method
          })
        );
      }
    });
  }

  @override
  String toString() => '<$runtimeType>';
}

/// Terminate the Flutter application.
void _exitApplication() {
  exit(0);
}

// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart' as test_package;

import 'all_elements.dart';
import 'binding.dart';
import 'controller.dart';
import 'finders.dart';
import 'test_async_utils.dart';

export 'package:test/test.dart' hide expect;

/// Signature for callback to [testWidgets] and [benchmarkWidgets].
typedef Future<Null> WidgetTesterCallback(WidgetTester widgetTester);

/// Runs the [callback] inside the Flutter test environment.
///
/// Use this function for testing custom [StatelessWidget]s and
/// [StatefulWidget]s.
///
/// The callback can be asynchronous (using `async`/`await` or
/// using explicit [Future]s).
///
/// This function uses the [test] function in the test package to
/// register the given callback as a test. The callback, when run,
/// will be given a new instance of [WidgetTester]. The [find] object
/// provides convenient widget [Finder]s for use with the
/// [WidgetTester].
///
/// Example:
///
///     testWidgets('MyWidget', (WidgetTester tester) async {
///       await tester.pumpWidget(new MyWidget());
///       await tester.tap(find.text('Save'));
///       expect(tester, hasWidget(find.text('Success')));
///     });
void testWidgets(String description, WidgetTesterCallback callback, {
  bool skip: false,
  test_package.Timeout timeout
}) {
  TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();
  WidgetTester tester = new WidgetTester._(binding);
  timeout ??= binding.defaultTestTimeout;
  test_package.group('-', () {
    test_package.test(description, () => binding.runTest(() => callback(tester), tester._endOfTestVerifications), skip: skip);
    test_package.tearDown(binding.postTest);
  }, timeout: timeout);
}

/// Runs the [callback] inside the Flutter benchmark environment.
///
/// Use this function for benchmarking custom [StatelessWidget]s and
/// [StatefulWidget]s when you want to be able to use features from
/// [TestWidgetsFlutterBinding]. The callback, when run, will be given
/// a new instance of [WidgetTester]. The [find] object provides
/// convenient widget [Finder]s for use with the [WidgetTester].
///
/// The callback can be asynchronous (using `async`/`await` or using
/// explicit [Future]s). If it is, then [benchmarkWidgets] will return
/// a [Future] that completes when the callback's does. Otherwise, it
/// will return a Future that is always complete.
///
/// If the callback is asynchronous, make sure you `await` the call
/// to [benchmarkWidgets], otherwise it won't run!
///
/// Benchmarks must not be run in checked mode. To avoid this, this
/// function will print a big message if it is run in checked mode.
///
/// Example:
///
///     main() async {
///       assert(false); // fail in checked mode
///       await benchmarkWidgets((WidgetTester tester) async {
///         await tester.pumpWidget(new MyWidget());
///         final Stopwatch timer = new Stopwatch()..start();
///         for (int index = 0; index < 10000; index += 1) {
///           await tester.tap(find.text('Tap me'));
///           await tester.pump();
///         }
///         timer.stop();
///         debugPrint('Time taken: ${timer.elapsedMilliseconds}ms');
///       });
///       exit(0);
///     }
Future<Null> benchmarkWidgets(WidgetTesterCallback callback) {
  assert(() {
    print('┏╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍┓');
    print('┇ ⚠ THIS BENCHMARK IS BEING RUN WITH ASSERTS ENABLED ⚠  ┇');
    print('┡╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍┦');
    print('│                                                       │');
    print('│  Numbers obtained from a benchmark while asserts are  │');
    print('│  enabled will not accurately reflect the performance  │');
    print('│  that will be experienced by end users using release  ╎');
    print('│  builds. Benchmarks should be run using this command  ┆');
    print('│  line:  flutter run --release benchmark.dart          ┊');
    print('│                                                        ');
    print('└─────────────────────────────────────────────────╌┄┈  🐢');
    return true;
  });
  TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();
  assert(binding is! AutomatedTestWidgetsFlutterBinding);
  WidgetTester tester = new WidgetTester._(binding);
  return binding.runTest(() => callback(tester), tester._endOfTestVerifications) ?? new Future<Null>.value();
}

/// Assert that `actual` matches `matcher`.
///
/// See [test_package.expect] for details. This is a variant of that function
/// that additionally verifies that there are no asynchronous APIs
/// that have not yet resolved.
void expect(dynamic actual, dynamic matcher, {
  String reason,
  bool verbose: false,
  dynamic formatter
}) {
  TestAsyncUtils.guardSync();
  test_package.expect(actual, matcher, reason: reason, verbose: verbose, formatter: formatter);
}

/// Assert that `actual` matches `matcher`.
///
/// See [test_package.expect] for details. This variant will _not_ check that
/// there are no outstanding asynchronous API requests. As such, it can be
/// called from, e.g., callbacks that are run during build or layout, or in the
/// completion handlers of futures that execute in response to user input.
///
/// Generally, it is better to use [expect], which does include checks to ensure
/// that asynchronous APIs are not being called.
void expectSync(dynamic actual, dynamic matcher, {
  String reason,
  bool verbose: false,
  dynamic formatter
}) {
  test_package.expect(actual, matcher, reason: reason, verbose: verbose, formatter: formatter);
}

/// Class that programmatically interacts with widgets and the test environment.
///
/// For convenience, instances of this class (such as the one provided by
/// `testWidget`) can be used as the `vsync` for `AnimationController` objects.
class WidgetTester extends WidgetController implements HitTestDispatcher, TickerProvider {
  WidgetTester._(TestWidgetsFlutterBinding binding) : super(binding) {
    if (binding is LiveTestWidgetsFlutterBinding)
      binding.deviceEventDispatcher = this;
  }

  /// The binding instance used by the testing framework.
  @override
  TestWidgetsFlutterBinding get binding => super.binding;

  /// Renders the UI from the given [widget].
  ///
  /// Calls [runApp] with the given widget, then triggers a frame and flushes
  /// microtasks, by calling [pump] with the same `duration` (if any). The
  /// supplied [EnginePhase] is the final phase reached during the pump pass; if
  /// not supplied, the whole pass is executed.
  Future<Null> pumpWidget(Widget widget, [
    Duration duration,
    EnginePhase phase = EnginePhase.sendSemanticsTree
  ]) {
    return TestAsyncUtils.guard(() {
      binding.attachRootWidget(widget);
      binding.scheduleFrame();
      return binding.pump(duration, phase);
    });
  }

  /// Triggers a frame after `duration` amount of time.
  ///
  /// This makes the framework act as if the application had janked (missed
  /// frames) for `duration` amount of time, and then received a v-sync signal
  /// to paint the application.
  ///
  /// This is a convenience function that just calls
  /// [TestWidgetsFlutterBinding.pump].
  @override
  Future<Null> pump([
    Duration duration,
    EnginePhase phase = EnginePhase.sendSemanticsTree
  ]) {
    return TestAsyncUtils.guard(() => binding.pump(duration, phase));
  }

  /// Repeatedly calls [pump] with the given `duration` until there are no
  /// longer any transient callbacks scheduled. If no transient callbacks are
  /// scheduled when the function is called, it returns without calling [pump].
  ///
  /// This essentially waits for all animations to have completed.
  ///
  /// This function will never return (and the test will hang and eventually
  /// time out and fail) if there is an infinite animation in progress (for
  /// example, if there is an indeterminate progress indicator spinning).
  ///
  /// If the function returns, it returns the number of pumps that it performed.
  ///
  /// In general, it is better practice to figure out exactly why each frame is
  /// needed, and then to [pump] exactly as many frames as necessary. This will
  /// help catch regressions where, for instance, an animation is being started
  /// one frame later than it should.
  ///
  /// Alternatively, one can check that the return value from this function
  /// matches the expected number of pumps.
  Future<int> pumpUntilNoTransientCallbacks([
    @required Duration duration,
    EnginePhase phase = EnginePhase.sendSemanticsTree
  ]) {
    assert(duration != null);
    assert(duration > Duration.ZERO);
    int count = 0;
    return TestAsyncUtils.guard(() async {
      while (binding.transientCallbackCount > 0) {
        await binding.pump(duration, phase);
        count += 1;
      }
    }).then/*<int>*/((Null _) => count);
  }

  @override
  HitTestResult hitTestOnBinding(Point location) {
    location = binding.localToGlobal(location);
    return super.hitTestOnBinding(location);
  }

  @override
  Future<Null> sendEventToBinding(PointerEvent event, HitTestResult result) {
    return TestAsyncUtils.guard(() async {
      binding.dispatchEvent(event, result, source: TestBindingEventSource.test);
      return null;
    });
  }

  /// Handler for device events caught by the binding in live test mode.
  @override
  void dispatchEvent(PointerEvent event, HitTestResult result) {
    if (event is PointerDownEvent) {
      final RenderObject innerTarget = result.path.firstWhere(
        (HitTestEntry candidate) => candidate.target is RenderObject,
        orElse: () => null
      )?.target;
      if (innerTarget == null)
        return null;
      final Element innerTargetElement = collectAllElementsFrom(binding.renderViewElement, skipOffstage: true)
        .lastWhere((Element element) => element.renderObject == innerTarget);
      final List<Element> candidates = <Element>[];
      innerTargetElement.visitAncestorElements((Element element) {
        candidates.add(element);
        return true;
      });
      assert(candidates.isNotEmpty);
      String descendantText;
      int numberOfWithTexts = 0;
      int numberOfTypes = 0;
      int totalNumber = 0;
      debugPrint('Some possible finders for the widgets at ${binding.globalToLocal(event.position)}:');
      for (Element element in candidates) {
        if (totalNumber > 10)
          break;
        totalNumber += 1;

        if (element.widget is Text) {
          assert(descendantText == null);
          final Text widget = element.widget;
          final Iterable<Element> matches = find.text(widget.data).evaluate();
          descendantText = widget.data;
          if (matches.length == 1) {
            debugPrint('  find.text(\'${widget.data}\')');
            continue;
          }
        }

        if (element.widget.key is ValueKey<dynamic>) {
          final ValueKey<dynamic> key = element.widget.key;
          String keyLabel;
          if ((key is ValueKey<int> ||
               key is ValueKey<double> ||
               key is ValueKey<bool>)) {
            keyLabel = 'const ${element.widget.key.runtimeType}(${key.value})';
          } else if (key is ValueKey<String>) {
            keyLabel = 'const ${element.widget.key.runtimeType}(\'${key.value}\')';
          }
          if (keyLabel != null) {
            final Iterable<Element> matches = find.byKey(key).evaluate();
            if (matches.length == 1) {
              debugPrint('  find.byKey($keyLabel)');
              continue;
            }
          }
        }

        if (!_isPrivate(element.widget.runtimeType)) {
          if (numberOfTypes < 5) {
            final Iterable<Element> matches = find.byType(element.widget.runtimeType).evaluate();
            if (matches.length == 1) {
              debugPrint('  find.byType(${element.widget.runtimeType})');
              numberOfTypes += 1;
              continue;
            }
          }

          if (descendantText != null && numberOfWithTexts < 5) {
            final Iterable<Element> matches = find.widgetWithText(element.widget.runtimeType, descendantText).evaluate();
            if (matches.length == 1) {
              debugPrint('  find.widgetWithText(${element.widget.runtimeType}, \'$descendantText\')');
              numberOfWithTexts += 1;
              continue;
            }
          }
        }

        if (!_isPrivate(element.runtimeType)) {
          final Iterable<Element> matches = find.byElementType(element.runtimeType).evaluate();
          if (matches.length == 1) {
            debugPrint('  find.byElementType(${element.runtimeType})');
            continue;
          }
        }

        totalNumber -= 1; // if we got here, we didn't actually find something to say about it
      }
      if (totalNumber == 0)
        debugPrint('  <could not come up with any unique finders>');
    }
  }

  bool _isPrivate(Type type) {
    // used above so that we don't suggest matchers for private types
    return '_'.matchAsPrefix(type.toString()) != null;
  }

  /// Returns the exception most recently caught by the Flutter framework.
  ///
  /// See [TestWidgetsFlutterBinding.takeException] for details.
  dynamic takeException() {
    return binding.takeException();
  }

  /// Acts as if the application went idle.
  ///
  /// Runs all remaining microtasks, including those scheduled as a result of
  /// running them, until there are no more microtasks scheduled.
  ///
  /// Does not run timers. May result in an infinite loop or run out of memory
  /// if microtasks continue to recursively schedule new microtasks.
  Future<Null> idle() {
    return TestAsyncUtils.guard(() => binding.idle());
  }

  Set<Ticker> _tickers;

  @override
  Ticker createTicker(TickerCallback onTick) {
    _tickers ??= new Set<_TestTicker>();
    final _TestTicker result = new _TestTicker(onTick, _removeTicker);
    _tickers.add(result);
    return result;
  }

  void _removeTicker(_TestTicker ticker) {
    assert(_tickers != null);
    assert(_tickers.contains(ticker));
    _tickers.remove(ticker);
  }

  /// Throws an exception if any tickers created by the [WidgetTester] are still
  /// active when the method is called.
  ///
  /// An argument can be specified to provide a string that will be used in the
  /// error message. It should be an adverbial phrase describing the current
  /// situation, such as "at the end of the test".
  void verifyTickersWereDisposed([ String when = 'when none should have been' ]) {
    assert(when != null);
    if (_tickers != null) {
      for (Ticker ticker in _tickers) {
        if (ticker.isActive) {
          throw new FlutterError(
            'A Ticker was active $when.\n'
            'All Tickers must be disposed. Tickers used by AnimationControllers '
            'should be disposed by calling dispose() on the AnimationController itself. '
            'Otherwise, the ticker will leak.\n'
            'The offending ticker was: ${ticker.toString(debugIncludeStack: true)}'
          );
        }
      }
    }
  }

  void _endOfTestVerifications() {
    verifyTickersWereDisposed('at the end of the test');
  }
}

typedef void _TickerDisposeCallback(_TestTicker ticker);

class _TestTicker extends Ticker {
  _TestTicker(TickerCallback onTick, this._onDispose) : super(onTick);

  _TickerDisposeCallback _onDispose;

  @override
  void dispose() {
    if (_onDispose != null)
      _onDispose(this);
    super.dispose();
  }
}

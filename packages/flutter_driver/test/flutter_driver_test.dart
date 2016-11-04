// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter_driver/src/driver.dart';
import 'package:flutter_driver/src/error.dart';
import 'package:flutter_driver/src/health.dart';
import 'package:flutter_driver/src/timeline.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as rpc;
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:vm_service_client/vm_service_client.dart';

void main() {
  group('FlutterDriver.connect', () {
    List<LogRecord> log;
    StreamSubscription<LogRecord> logSub;
    MockVMServiceClient mockClient;
    MockVM mockVM;
    MockIsolate mockIsolate;

    void expectLogContains(String message) {
      expect(log.map((LogRecord r) => '$r'), anyElement(contains(message)));
    }

    setUp(() {
      log = <LogRecord>[];
      logSub = flutterDriverLog.listen(log.add);
      mockClient = new MockVMServiceClient();
      mockVM = new MockVM();
      mockIsolate = new MockIsolate();
      when(mockClient.getVM()).thenReturn(mockVM);
      when(mockVM.isolates).thenReturn(<VMRunnableIsolate>[mockIsolate]);
      when(mockIsolate.loadRunnable()).thenReturn(mockIsolate);
      when(mockIsolate.invokeExtension(any, any))
          .thenReturn(new Future<Map<String, dynamic>>.value(<String, String>{'status': 'ok'}));
      vmServiceConnectFunction = (String url) {
        return new Future<VMServiceClientConnection>.value(
          new VMServiceClientConnection(mockClient, null)
        );
      };
    });

    tearDown(() async {
      await logSub.cancel();
      restoreVmServiceConnectFunction();
    });

    test('connects to isolate paused at start', () async {
      when(mockIsolate.pauseEvent).thenReturn(new MockVMPauseStartEvent());
      when(mockIsolate.resume()).thenReturn(new Future<Null>.value());
      when(mockIsolate.onExtensionAdded).thenReturn(new Stream<String>.fromIterable(<String>['ext.flutter.driver']));

      FlutterDriver driver = await FlutterDriver.connect();
      expect(driver, isNotNull);
      expectLogContains('Isolate is paused at start');
    });

    test('connects to isolate paused mid-flight', () async {
      when(mockIsolate.pauseEvent).thenReturn(new MockVMPauseBreakpointEvent());
      when(mockIsolate.resume()).thenReturn(new Future<Null>.value());

      FlutterDriver driver = await FlutterDriver.connect();
      expect(driver, isNotNull);
      expectLogContains('Isolate is paused mid-flight');
    });

    // This test simulates a situation when we believe that the isolate is
    // currently paused, but something else (e.g. a debugger) resumes it before
    // we do. There's no need to fail as we should be able to drive the app
    // just fine.
    test('connects despite losing the race to resume isolate', () async {
      when(mockIsolate.pauseEvent).thenReturn(new MockVMPauseBreakpointEvent());
      when(mockIsolate.resume()).thenAnswer((_) {
        // This needs to be wrapped in a closure to not be considered uncaught
        // by package:test
        return new Future<Null>.error(new rpc.RpcException(101, ''));
      });

      FlutterDriver driver = await FlutterDriver.connect();
      expect(driver, isNotNull);
      expectLogContains('Attempted to resume an already resumed isolate');
    });

    test('connects to unpaused isolate', () async {
      when(mockIsolate.pauseEvent).thenReturn(new MockVMResumeEvent());
      FlutterDriver driver = await FlutterDriver.connect();
      expect(driver, isNotNull);
      expectLogContains('Isolate is not paused. Assuming application is ready.');
    });
  });

  group('FlutterDriver', () {
    MockVMServiceClient mockClient;
    MockPeer mockPeer;
    MockIsolate mockIsolate;
    FlutterDriver driver;

    setUp(() {
      mockClient = new MockVMServiceClient();
      mockPeer = new MockPeer();
      mockIsolate = new MockIsolate();
      driver = new FlutterDriver.connectedTo(mockClient, mockPeer, mockIsolate);
    });

    test('checks the health of the driver extension', () async {
      when(mockIsolate.invokeExtension(any, any)).thenReturn(new Future<Map<String, dynamic>>.value(<String, dynamic>{
        'status': 'ok',
      }));
      Health result = await driver.checkHealth();
      expect(result.status, HealthStatus.ok);
    });

    test('closes connection', () async {
      when(mockClient.close()).thenReturn(new Future<Null>.value());
      await driver.close();
    });

    group('ByValueKey', () {
      test('restricts value types', () async {
        expect(() => find.byValueKey(null),
            throwsA(new isInstanceOf<DriverError>()));
      });

      test('finds by ValueKey', () async {
        when(mockIsolate.invokeExtension(any, any)).thenAnswer((Invocation i) {
          expect(i.positionalArguments[1], <String, String>{
            'command': 'tap',
            'finderType': 'ByValueKey',
            'keyValueString': 'foo',
            'keyValueType': 'String'
          });
          return new Future<Null>.value();
        });
        await driver.tap(find.byValueKey('foo'));
      });
    });

    group('tap', () {
      test('requires a target reference', () async {
        expect(driver.tap(null), throwsA(new isInstanceOf<DriverError>()));
      });

      test('sends the tap command', () async {
        when(mockIsolate.invokeExtension(any, any)).thenAnswer((Invocation i) {
          expect(i.positionalArguments[1], <String, dynamic>{
            'command': 'tap',
            'finderType': 'ByText',
            'text': 'foo',
          });
          return new Future<Map<String, dynamic>>.value();
        });
        await driver.tap(find.text('foo'));
      });
    });

    group('getText', () {
      test('requires a target reference', () async {
        expect(driver.getText(null), throwsA(new isInstanceOf<DriverError>()));
      });

      test('sends the getText command', () async {
        when(mockIsolate.invokeExtension(any, any)).thenAnswer((Invocation i) {
          expect(i.positionalArguments[1], <String, dynamic>{
            'command': 'get_text',
            'finderType': 'ByValueKey',
            'keyValueString': '123',
            'keyValueType': 'int'
          });
          return new Future<Map<String, dynamic>>.value(<String, String>{
            'text': 'hello'
          });
        });
        String result = await driver.getText(find.byValueKey(123));
        expect(result, 'hello');
      });
    });

    group('waitFor', () {
      test('requires a target reference', () async {
        expect(driver.waitFor(null), throwsA(new isInstanceOf<DriverError>()));
      });

      test('sends the waitFor command', () async {
        when(mockIsolate.invokeExtension(any, any)).thenAnswer((Invocation i) {
          expect(i.positionalArguments[1], <String, dynamic>{
            'command': 'waitFor',
            'finderType': 'ByTooltipMessage',
            'text': 'foo',
            'timeout': '1000',
          });
          return new Future<Map<String, dynamic>>.value(<String, dynamic>{});
        });
        await driver.waitFor(find.byTooltip('foo'), timeout: new Duration(seconds: 1));
      });
    });

    group('traceAction', () {
      test('traces action', () async {
        bool actionCalled = false;
        bool startTracingCalled = false;
        bool stopTracingCalled = false;

        when(mockPeer.sendRequest('_setVMTimelineFlags', argThat(equals(<String, dynamic>{'recordedStreams': '[all]'}))))
          .thenAnswer((_) async {
            startTracingCalled = true;
            return null;
          });

        when(mockPeer.sendRequest('_setVMTimelineFlags', argThat(equals(<String, dynamic>{'recordedStreams': '[]'}))))
          .thenAnswer((_) async {
            stopTracingCalled = true;
            return null;
          });

        when(mockPeer.sendRequest('_getVMTimeline')).thenAnswer((_) async {
          return <String, dynamic> {
            'traceEvents': <dynamic>[
              <String, String>{
                'name': 'test event'
              }
            ],
          };
        });

        Timeline timeline = await driver.traceAction(() {
          actionCalled = true;
        });

        expect(actionCalled, isTrue);
        expect(startTracingCalled, isTrue);
        expect(stopTracingCalled, isTrue);
        expect(timeline.events.single.name, 'test event');
      });
    });

    group('traceAction with timeline streams', () {
      test('specify non-default timeline streams', () async {
        bool actionCalled = false;
        bool startTracingCalled = false;
        bool stopTracingCalled = false;

        when(mockPeer.sendRequest('_setVMTimelineFlags', argThat(equals(<String, dynamic>{'recordedStreams': '[Dart, GC, Compiler]'}))))
          .thenAnswer((_) async {
            startTracingCalled = true;
            return null;
          });

        when(mockPeer.sendRequest('_setVMTimelineFlags', argThat(equals(<String, dynamic>{'recordedStreams': '[]'}))))
          .thenAnswer((_) async {
            stopTracingCalled = true;
            return null;
          });

        when(mockPeer.sendRequest('_getVMTimeline')).thenAnswer((_) async {
          return <String, dynamic> {
            'traceEvents': <dynamic>[
              <String, String>{
                'name': 'test event'
              }
            ],
          };
        });

        Timeline timeline = await driver.traceAction(() {
          actionCalled = true;
        },
        streams: const <TimelineStream>[
          TimelineStream.dart,
          TimelineStream.gc,
          TimelineStream.compiler
        ]);

        expect(actionCalled, isTrue);
        expect(startTracingCalled, isTrue);
        expect(stopTracingCalled, isTrue);
        expect(timeline.events.single.name, 'test event');
      });
    });
  });
}

@proxy
class MockVMServiceClient extends Mock implements VMServiceClient { }

@proxy
class MockVM extends Mock implements VM { }

@proxy
class MockIsolate extends Mock implements VMRunnableIsolate { }

@proxy
class MockVMPauseStartEvent extends Mock implements VMPauseStartEvent { }

@proxy
class MockVMPauseBreakpointEvent extends Mock implements VMPauseBreakpointEvent { }

@proxy
class MockVMResumeEvent extends Mock implements VMResumeEvent { }

@proxy
class MockPeer extends Mock implements rpc.Peer { }

// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_tester.dart';

class _TimePickerLauncher extends StatelessWidget {
  const _TimePickerLauncher({ Key key, this.onChanged, this.locale }) : super(key: key);

  final ValueChanged<TimeOfDay> onChanged;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      locale: locale,
      home: new Material(
        child: new Center(
          child: new Builder(
            builder: (BuildContext context) {
              return new RaisedButton(
                child: const Text('X'),
                onPressed: () async {
                  onChanged(await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 7, minute: 0),
                  ));
                }
              );
            }
          )
        )
      )
    );
  }
}

Future<Offset> startPicker(WidgetTester tester, ValueChanged<TimeOfDay> onChanged) async {
  await tester.pumpWidget(new _TimePickerLauncher(onChanged: onChanged, locale: const Locale('en', 'US')));
  await tester.tap(find.text('X'));
  await tester.pumpAndSettle(const Duration(seconds: 1));
  return tester.getCenter(find.byKey(const Key('time-picker-dial')));
}

Future<Null> finishPicker(WidgetTester tester) async {
  final MaterialLocalizations materialLocalizations = MaterialLocalizations.of(tester.element(find.byType(RaisedButton)));
  await tester.tap(find.text(materialLocalizations.okButtonLabel));
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

void main() {
  testWidgets('tap-select an hour', (WidgetTester tester) async {
    TimeOfDay result;

    Offset center = await startPicker(tester, (TimeOfDay time) { result = time; });
    await tester.tapAt(new Offset(center.dx, center.dy - 50.0)); // 12:00 AM
    await finishPicker(tester);
    expect(result, equals(const TimeOfDay(hour: 0, minute: 0)));

    center = await startPicker(tester, (TimeOfDay time) { result = time; });
    await tester.tapAt(new Offset(center.dx + 50.0, center.dy));
    await finishPicker(tester);
    expect(result, equals(const TimeOfDay(hour: 3, minute: 0)));

    center = await startPicker(tester, (TimeOfDay time) { result = time; });
    await tester.tapAt(new Offset(center.dx, center.dy + 50.0));
    await finishPicker(tester);
    expect(result, equals(const TimeOfDay(hour: 6, minute: 0)));

    center = await startPicker(tester, (TimeOfDay time) { result = time; });
    await tester.tapAt(new Offset(center.dx, center.dy + 50.0));
    await tester.tapAt(new Offset(center.dx - 50, center.dy));
    await finishPicker(tester);
    expect(result, equals(const TimeOfDay(hour: 9, minute: 0)));
  });

  testWidgets('drag-select an hour', (WidgetTester tester) async {
    TimeOfDay result;

    final Offset center = await startPicker(tester, (TimeOfDay time) { result = time; });
    final Offset hour0 = new Offset(center.dx, center.dy - 50.0); // 12:00 AM
    final Offset hour3 = new Offset(center.dx + 50.0, center.dy);
    final Offset hour6 = new Offset(center.dx, center.dy + 50.0);
    final Offset hour9 = new Offset(center.dx - 50.0, center.dy);

    TestGesture gesture;

    gesture = await tester.startGesture(hour3);
    await gesture.moveBy(hour0 - hour3);
    await gesture.up();
    await finishPicker(tester);
    expect(result.hour, 0);

    expect(await startPicker(tester, (TimeOfDay time) { result = time; }), equals(center));
    gesture = await tester.startGesture(hour0);
    await gesture.moveBy(hour3 - hour0);
    await gesture.up();
    await finishPicker(tester);
    expect(result.hour, 3);

    expect(await startPicker(tester, (TimeOfDay time) { result = time; }), equals(center));
    gesture = await tester.startGesture(hour3);
    await gesture.moveBy(hour6 - hour3);
    await gesture.up();
    await finishPicker(tester);
    expect(result.hour, equals(6));

    expect(await startPicker(tester, (TimeOfDay time) { result = time; }), equals(center));
    gesture = await tester.startGesture(hour6);
    await gesture.moveBy(hour9 - hour6);
    await gesture.up();
    await finishPicker(tester);
    expect(result.hour, equals(9));
  });

  group('haptic feedback', () {
    const Duration kFastFeedbackInterval = const Duration(milliseconds: 10);
    const Duration kSlowFeedbackInterval = const Duration(milliseconds: 200);
    FeedbackTester feedback;

    setUp(() {
      feedback = new FeedbackTester();
    });

    tearDown(() {
      feedback?.dispose();
    });

    testWidgets('tap-select vibrates once', (WidgetTester tester) async {
      final Offset center = await startPicker(tester, (TimeOfDay time) { });
      await tester.tapAt(new Offset(center.dx, center.dy - 50.0));
      await finishPicker(tester);
      expect(feedback.hapticCount, 1);
    });

    testWidgets('quick successive tap-selects vibrate once', (WidgetTester tester) async {
      final Offset center = await startPicker(tester, (TimeOfDay time) { });
      await tester.tapAt(new Offset(center.dx, center.dy - 50.0));
      await tester.pump(kFastFeedbackInterval);
      await tester.tapAt(new Offset(center.dx, center.dy + 50.0));
      await finishPicker(tester);
      expect(feedback.hapticCount, 1);
    });

    testWidgets('slow successive tap-selects vibrate once per tap', (WidgetTester tester) async {
      final Offset center = await startPicker(tester, (TimeOfDay time) { });
      await tester.tapAt(new Offset(center.dx, center.dy - 50.0));
      await tester.pump(kSlowFeedbackInterval);
      await tester.tapAt(new Offset(center.dx, center.dy + 50.0));
      await tester.pump(kSlowFeedbackInterval);
      await tester.tapAt(new Offset(center.dx, center.dy - 50.0));
      await finishPicker(tester);
      expect(feedback.hapticCount, 3);
    });

    testWidgets('drag-select vibrates once', (WidgetTester tester) async {
      final Offset center = await startPicker(tester, (TimeOfDay time) { });
      final Offset hour0 = new Offset(center.dx, center.dy - 50.0);
      final Offset hour3 = new Offset(center.dx + 50.0, center.dy);

      final TestGesture gesture = await tester.startGesture(hour3);
      await gesture.moveBy(hour0 - hour3);
      await gesture.up();
      await finishPicker(tester);
      expect(feedback.hapticCount, 1);
    });

    testWidgets('quick drag-select vibrates once', (WidgetTester tester) async {
      final Offset center = await startPicker(tester, (TimeOfDay time) { });
      final Offset hour0 = new Offset(center.dx, center.dy - 50.0);
      final Offset hour3 = new Offset(center.dx + 50.0, center.dy);

      final TestGesture gesture = await tester.startGesture(hour3);
      await gesture.moveBy(hour0 - hour3);
      await tester.pump(kFastFeedbackInterval);
      await gesture.moveBy(hour3 - hour0);
      await tester.pump(kFastFeedbackInterval);
      await gesture.moveBy(hour0 - hour3);
      await gesture.up();
      await finishPicker(tester);
      expect(feedback.hapticCount, 1);
    });

    testWidgets('slow drag-select vibrates once', (WidgetTester tester) async {
      final Offset center = await startPicker(tester, (TimeOfDay time) { });
      final Offset hour0 = new Offset(center.dx, center.dy - 50.0);
      final Offset hour3 = new Offset(center.dx + 50.0, center.dy);

      final TestGesture gesture = await tester.startGesture(hour3);
      await gesture.moveBy(hour0 - hour3);
      await tester.pump(kSlowFeedbackInterval);
      await gesture.moveBy(hour3 - hour0);
      await tester.pump(kSlowFeedbackInterval);
      await gesture.moveBy(hour0 - hour3);
      await gesture.up();
      await finishPicker(tester);
      expect(feedback.hapticCount, 3);
    });
  });

  const List<String> labels12To11 = const <String>['12', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11'];
  const List<String> labels12To11TwoDigit = const <String>['12', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11'];
  const List<String> labels00To23 = const <String>['00', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23'];

  Future<Null> mediaQueryBoilerplate(WidgetTester tester, bool alwaysUse24HourFormat) async {
    await tester.pumpWidget(
      new Localizations(
        locale: const Locale('en', 'US'),
        delegates: <LocalizationsDelegate<dynamic>>[
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: new MediaQuery(
          data: new MediaQueryData(alwaysUse24HourFormat: alwaysUse24HourFormat),
          child: new Directionality(
            textDirection: TextDirection.ltr,
            child: new Navigator(
              onGenerateRoute: (RouteSettings settings) {
                return new MaterialPageRoute<dynamic>(builder: (BuildContext context) {
                  showTimePicker(context: context, initialTime: const TimeOfDay(hour: 7, minute: 0));
                  return new Container();
                });
              },
            ),
          ),
        ),
      ),
    );
    // Pump once, because the dialog shows up asynchronously.
    await tester.pump();
  }

  testWidgets('respects MediaQueryData.alwaysUse24HourFormat == false', (WidgetTester tester) async {
    await mediaQueryBoilerplate(tester, false);

    final CustomPaint dialPaint = tester.widget(find.descendant(
      of: find.byWidgetPredicate((Widget w) => '${w.runtimeType}' == '_Dial'),
      matching: find.byType(CustomPaint),
    ));
    final dynamic dialPainter = dialPaint.painter;
    final List<TextPainter> primaryOuterLabels = dialPainter.primaryOuterLabels;
    expect(primaryOuterLabels.map((TextPainter tp) => tp.text.text), labels12To11);
    expect(dialPainter.primaryInnerLabels, null);

    final List<TextPainter> secondaryOuterLabels = dialPainter.secondaryOuterLabels;
    expect(secondaryOuterLabels.map((TextPainter tp) => tp.text.text), labels12To11);
    expect(dialPainter.secondaryInnerLabels, null);
  });

  testWidgets('respects MediaQueryData.alwaysUse24HourFormat == true', (WidgetTester tester) async {
    await mediaQueryBoilerplate(tester, true);

    final CustomPaint dialPaint = tester.widget(find.descendant(
      of: find.byWidgetPredicate((Widget w) => '${w.runtimeType}' == '_Dial'),
      matching: find.byType(CustomPaint),
    ));
    final dynamic dialPainter = dialPaint.painter;
    final List<TextPainter> primaryOuterLabels = dialPainter.primaryOuterLabels;
    expect(primaryOuterLabels.map((TextPainter tp) => tp.text.text), labels00To23);
    final List<TextPainter> primaryInnerLabels = dialPainter.primaryInnerLabels;
    expect(primaryInnerLabels.map((TextPainter tp) => tp.text.text), labels12To11TwoDigit);

    final List<TextPainter> secondaryOuterLabels = dialPainter.secondaryOuterLabels;
    expect(secondaryOuterLabels.map((TextPainter tp) => tp.text.text), labels00To23);
    final List<TextPainter> secondaryInnerLabels = dialPainter.secondaryInnerLabels;
    expect(secondaryInnerLabels.map((TextPainter tp) => tp.text.text), labels12To11TwoDigit);
  });
}

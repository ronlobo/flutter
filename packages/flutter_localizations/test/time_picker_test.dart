// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _TimePickerLauncher extends StatelessWidget {
  const _TimePickerLauncher({ Key key, this.onChanged, this.locale }) : super(key: key);

  final ValueChanged<TimeOfDay> onChanged;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      locale: locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: new Material(
        child: new Center(
          child: new Builder(
            builder: (BuildContext context) {
              return new RaisedButton(
                child: const Text('X'),
                onPressed: () async {
                  onChanged(await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 7, minute: 0)
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

Future<Offset> startPicker(WidgetTester tester, ValueChanged<TimeOfDay> onChanged,
    { Locale locale: const Locale('en', 'US') }) async {
  await tester.pumpWidget(new _TimePickerLauncher(onChanged: onChanged, locale: locale,));
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
  testWidgets('can localize the header in all known formats', (WidgetTester tester) async {
    // TODO(yjbanov): also test `HH.mm` (in_ID), `a h:mm` (ko_KR) and `HH:mm น.` (th_TH) when we have .arb files for them
    final Map<Locale, List<String>> locales = <Locale, List<String>>{
      const Locale('en', 'US'): const <String>['hour', 'string :', 'minute', 'period'], //'h:mm a'
      const Locale('en', 'GB'): const <String>['hour', 'string :', 'minute'], //'HH:mm'
      const Locale('es', 'ES'): const <String>['hour', 'string :', 'minute'], //'H:mm'
      const Locale('fr', 'CA'): const <String>['hour', 'string h', 'minute'], //'HH \'h\' mm'
      const Locale('zh', 'ZH'): const <String>['period', 'hour', 'string :', 'minute'], //'ah:mm'
    };

    for (Locale locale in locales.keys) {
      final Offset center = await startPicker(tester, (TimeOfDay time) { }, locale: locale);
      final List<String> actual = <String>[];
      tester.element(find.byType(CustomMultiChildLayout)).visitChildren((Element child) {
        final LayoutId layout = child.widget;
        final String fragmentType = '${layout.child.runtimeType}';
        final dynamic widget = layout.child;
        if (fragmentType == '_MinuteControl') {
          actual.add('minute');
        } else if (fragmentType == '_DayPeriodControl') {
          actual.add('period');
        } else if (fragmentType == '_HourControl') {
          actual.add('hour');
        } else if (fragmentType == '_StringFragment') {
          actual.add('string ${widget.value}');
        } else {
          fail('Unsupported fragment type: $fragmentType');
        }
      });
      expect(actual, locales[locale]);
      await tester.tapAt(new Offset(center.dx, center.dy - 50.0));
      await finishPicker(tester);
    }
  });

  testWidgets('uses single-ring 12-hour dial for h hour format', (WidgetTester tester) async {
    // Tap along the segment stretching from the center to the edge at
    // 12:00 AM position. Because there's only one ring, no matter where you
    // tap the time will be the same. See the 24-hour dial test that behaves
    // differently.
    for (int i = 1; i < 10; i++) {
      TimeOfDay result;
      final Offset center = await startPicker(tester, (TimeOfDay time) { result = time; });
      final Size size = tester.getSize(find.byKey(const Key('time-picker-dial')));
      final double dy = (size.height / 2.0 / 10) * i;
      await tester.tapAt(new Offset(center.dx, center.dy - dy));
      await finishPicker(tester);
      expect(result, equals(const TimeOfDay(hour: 0, minute: 0)));
    }
  });

  testWidgets('uses two-ring 24-hour dial for H and HH hour formats', (WidgetTester tester) async {
    const List<Locale> locales = const <Locale>[
      const Locale('en', 'GB'), // HH
      const Locale('es', 'ES'), // H
    ];
    for (Locale locale in locales) {
      // Tap along the segment stretching from the center to the edge at
      // 12:00 AM position. There are two rings. At ~70% mark, the ring
      // switches between inner ring and outer ring.
      for (int i = 1; i < 10; i++) {
        TimeOfDay result;
        final Offset center = await startPicker(tester, (TimeOfDay time) { result = time; }, locale: locale);
        final Size size = tester.getSize(find.byKey(const Key('time-picker-dial')));
        final double dy = (size.height / 2.0 / 10) * i;
        await tester.tapAt(new Offset(center.dx, center.dy - dy));
        await finishPicker(tester);
        expect(result, equals(new TimeOfDay(hour: i < 7 ? 12 : 0, minute: 0)));
      }
    }
  });

  const List<String> labels12To11 = const <String>['12', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11'];
  const List<String> labels12To11TwoDigit = const <String>['12', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11'];
  const List<String> labels00To23 = const <String>['00', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23'];

  Future<Null> mediaQueryBoilerplate(WidgetTester tester, bool alwaysUse24HourFormat) async {
    await tester.pumpWidget(
      new Localizations(
        locale: const Locale('en', 'US'),
        delegates: <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
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

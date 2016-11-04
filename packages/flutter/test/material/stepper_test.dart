// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Stepper tap callback test', (WidgetTester tester) async {
    int index = 0;

    await tester.pumpWidget(
      new Material(
        child: new Stepper(
          onStepTapped: (int i) {
            index = i;
          },
          steps: <Step>[
            new Step(
              title: new Text('Step 1'),
              content: new SizedBox(
                width: 100.0,
                height: 100.0
              )
            ),
            new Step(
              title: new Text('Step 2'),
              content: new SizedBox(
                width: 100.0,
                height: 100.0
              )
            )
          ]
        )
      )
    );

    await tester.tap(find.text('Step 2'));
    expect(index, 1);
  });

  testWidgets('Stepper expansion test', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Center(
        child: new Material(
          child: new Stepper(
            steps: <Step>[
              new Step(
                title: new Text('Step 1'),
                content: new SizedBox(
                  width: 100.0,
                  height: 100.0
                )
              ),
              new Step(
                title: new Text('Step 2'),
                content: new SizedBox(
                  width: 200.0,
                  height: 200.0
                )
              )
            ]
          )
        )
      )
    );

    RenderBox box = tester.renderObject(find.byType(Stepper));
    expect(box.size.height, 332.0);

    await tester.pumpWidget(
      new Center(
        child: new Material(
          child: new Stepper(
            currentStep: 1,
            steps: <Step>[
              new Step(
                title: new Text('Step 1'),
                content: new SizedBox(
                  width: 100.0,
                  height: 100.0
                )
              ),
              new Step(
                title: new Text('Step 2'),
                content: new SizedBox(
                  width: 200.0,
                  height: 200.0
                )
              )
            ]
          )
        )
      )
    );

    await tester.pump(const Duration(milliseconds: 100));
    box = tester.renderObject(find.byType(Stepper));
    expect(box.size.height, greaterThan(332.0));
    await tester.pump(const Duration(milliseconds: 100));
    box = tester.renderObject(find.byType(Stepper));
    expect(box.size.height, 432.0);
  });

  testWidgets('Stepper horizontal size test', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Center(
        child: new Material(
          child: new Stepper(
            type: StepperType.horizontal,
            steps: <Step>[
              new Step(
                title: new Text('Step 1'),
                content: new SizedBox(
                  width: 100.0,
                  height: 100.0
                )
              )
            ]
          )
        )
      )
    );

    RenderBox box = tester.renderObject(find.byType(Stepper));
    expect(box.size.height, 600.0);
  });

  testWidgets('Stepper visibility test', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Material(
        child: new Stepper(
          type: StepperType.horizontal,
          steps: <Step>[
            new Step(
              title: new Text('Step 1'),
              content: new Text('A')
            ),
            new Step(
              title: new Text('Step 2'),
              content: new Text('B')
            )
          ]
        )
      )
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsNothing);

    await tester.pumpWidget(
      new Material(
        child: new Stepper(
          currentStep: 1,
          type: StepperType.horizontal,
          steps: <Step>[
            new Step(
              title: new Text('Step 1'),
              content: new Text('A')
            ),
            new Step(
              title: new Text('Step 2'),
              content: new Text('B')
            )
          ]
        )
      )
    );

    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('Stepper button test', (WidgetTester tester) async {
    bool continuePressed = false;
    bool cancelPressed = false;

    await tester.pumpWidget(
      new Material(
        child: new Stepper(
          type: StepperType.horizontal,
          onStepContinue: () {
            continuePressed = true;
          },
          onStepCancel: () {
            cancelPressed = true;
          },
          steps: <Step>[
            new Step(
              title: new Text('Step 1'),
              content: new SizedBox(
                width: 100.0,
                height: 100.0
              )
            ),
            new Step(
              title: new Text('Step 2'),
              content: new SizedBox(
                width: 200.0,
                height: 200.0
              )
            )
          ]
        )
      )
    );

    await tester.tap(find.text('CONTINUE'));
    await tester.tap(find.text('CANCEL'));

    expect(continuePressed, isTrue);
    expect(cancelPressed, isTrue);
  });

  testWidgets('Stepper disabled step test', (WidgetTester tester) async {
    int index = 0;

    await tester.pumpWidget(
      new Material(
        child: new Stepper(
          onStepTapped: (int i) {
            index = i;
          },
          steps: <Step>[
            new Step(
              title: new Text('Step 1'),
              content: new SizedBox(
                width: 100.0,
                height: 100.0
              )
            ),
            new Step(
              title: new Text('Step 2'),
              state: StepState.disabled,
              content: new SizedBox(
                width: 100.0,
                height: 100.0
              )
            )
          ]
        )
      )
    );

    await tester.tap(find.text('Step 2'));
    expect(index, 0);
  });

  testWidgets('Stepper scroll test', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Material(
        child: new Stepper(
          steps: <Step>[
            new Step(
              title: new Text('Step 1'),
              content: new SizedBox(
                width: 100.0,
                height: 300.0
              )
            ),
            new Step(
              title: new Text('Step 2'),
              content: new SizedBox(
                width: 100.0,
                height: 300.0
              )
            ),
            new Step(
              title: new Text('Step 3'),
              content: new SizedBox(
                width: 100.0,
                height: 100.0
              )
            ),
          ]
        )
      )
    );

    ScrollableState scrollableState = tester.firstState(find.byType(Scrollable));
    expect(scrollableState.scrollOffset, 0.0);

    await tester.tap(find.text('Step 3'));
    await tester.pumpWidget(
      new Material(
        child: new Stepper(
          currentStep: 2,
          steps: <Step>[
            new Step(
              title: new Text('Step 1'),
              content: new SizedBox(
                width: 100.0,
                height: 300.0
              )
            ),
            new Step(
              title: new Text('Step 2'),
              content: new SizedBox(
                width: 100.0,
                height: 300.0
              )
            ),
            new Step(
              title: new Text('Step 3'),
              content: new SizedBox(
                width: 100.0,
                height: 100.0
              )
            ),
          ]
        )
      )
    );

    await tester.pump(new Duration(milliseconds: 100));
    expect(scrollableState.scrollOffset, greaterThan(0.0));
  });

  testWidgets('Stepper index test', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Center(
        child: new Material(
          child: new Stepper(
            steps: <Step>[
              new Step(
                title: new Text('A'),
                state: StepState.complete,
                content: new SizedBox(
                  width: 100.0,
                  height: 100.0
                )
              ),
              new Step(
                title: new Text('B'),
                content: new SizedBox(
                  width: 100.0,
                  height: 100.0
                )
              )
            ]
          )
        )
      )
    );

    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('Stepper error test', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Center(
        child: new Material(
          child: new Stepper(
            steps: <Step>[
              new Step(
                title: new Text('A'),
                state: StepState.error,
                content: new SizedBox(
                  width: 100.0,
                  height: 100.0
                )
              )
            ]
          )
        )
      )
    );

    expect(find.text('!'), findsOneWidget);
  });
}

// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart' hide TypeMatcher;

int count = 0;

void main() {
  testWidgets('Middle still in center with asymmetrical actions', (WidgetTester tester) async {
    await tester.pumpWidget(
      new WidgetsApp(
        color: const Color(0xFFFFFFFF),
        onGenerateRoute: (RouteSettings settings) {
          return new CupertinoPageRoute<Null>(
            settings: settings,
            builder: (BuildContext context) {
              return const CupertinoNavigationBar(
                leading: const CupertinoButton(child: const Text('Something'), onPressed: null,),
                middle: const Text('Title'),
              );
            },
          );
        },
      ),
    );

    // Expect the middle of the title to be exactly in the middle of the screen.
    expect(tester.getCenter(find.text('Title')).dx, 400.0);
  });

  testWidgets('Opaque background does not add blur effects', (WidgetTester tester) async {
    await tester.pumpWidget(
      new WidgetsApp(
        color: const Color(0xFFFFFFFF),
        onGenerateRoute: (RouteSettings settings) {
          return new CupertinoPageRoute<Null>(
            settings: settings,
            builder: (BuildContext context) {
              return const CupertinoNavigationBar(
                middle: const Text('Title'),
                backgroundColor: const Color(0xFFE5E5E5),
              );
            },
          );
        },
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('Non-opaque background adds blur effects', (WidgetTester tester) async {
    await tester.pumpWidget(
      new WidgetsApp(
        color: const Color(0xFFFFFFFF),
        onGenerateRoute: (RouteSettings settings) {
          return new CupertinoPageRoute<Null>(
            settings: settings,
            builder: (BuildContext context) {
              return const CupertinoNavigationBar(
                middle: const Text('Title'),
              );
            },
          );
        },
      ),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('Verify styles of each slot', (WidgetTester tester) async {
    count = 0x000000;
    await tester.pumpWidget(
      new WidgetsApp(
        color: const Color(0xFFFFFFFF),
        onGenerateRoute: (RouteSettings settings) {
          return new CupertinoPageRoute<Null>(
            settings: settings,
            builder: (BuildContext context) {
              return const CupertinoNavigationBar(
                leading: const _ExpectStyles(color: const Color(0xFF001122), index: 0x000001),
                middle: const _ExpectStyles(color: const Color(0xFF000000), letterSpacing: -0.72, index: 0x000100),
                trailing: const _ExpectStyles(color: const Color(0xFF001122), index: 0x010000),
                actionsForegroundColor: const Color(0xFF001122),
              );
            },
          );
        },
      ),
    );
    expect(count, 0x010101);
  });

  testWidgets('No slivers with no large titles', (WidgetTester tester) async {
    await tester.pumpWidget(
      new WidgetsApp(
        color: const Color(0xFFFFFFFF),
        onGenerateRoute: (RouteSettings settings) {
          return new CupertinoPageRoute<Null>(
            settings: settings,
            builder: (BuildContext context) {
              return const CupertinoPageScaffold(
                navigationBar: const CupertinoNavigationBar(
                  middle: const Text('Title'),
                ),
                child: const Center(),
              );
            },
          );
        },
      ),
    );

    expect(find.byType(SliverPersistentHeader), findsNothing);
  });

  testWidgets('Large title nav bar scrolls', (WidgetTester tester) async {
    final ScrollController scrollController = new ScrollController();
    await tester.pumpWidget(
      new WidgetsApp(
        color: const Color(0xFFFFFFFF),
        onGenerateRoute: (RouteSettings settings) {
          return new CupertinoPageRoute<Null>(
            settings: settings,
            builder: (BuildContext context) {
              return new CupertinoPageScaffold(
                child: new CustomScrollView(
                  controller: scrollController,
                  slivers: <Widget>[
                    const CupertinoSliverNavigationBar(
                      largeTitle: const Text('Title'),
                    ),
                    new SliverToBoxAdapter(
                      child: new Container(
                        height: 1200.0,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );

    expect(scrollController.offset, 0.0);
    expect(tester.getTopLeft(find.byType(NavigationToolbar)).dy, 0.0);
    expect(tester.getSize(find.byType(NavigationToolbar)).height, 44.0);

    expect(find.text('Title'), findsNWidgets(2)); // Though only one is visible.

    List<Element> titles = tester.elementList(find.text('Title'))
        .toList()
        ..sort((Element a, Element b) {
          final RenderParagraph aParagraph = a.renderObject;
          final RenderParagraph bParagraph = b.renderObject;
          return aParagraph.text.style.fontSize.compareTo(bParagraph.text.style.fontSize);
        });

    Iterable<double> opacities = titles.map((Element element) {
      final RenderOpacity renderOpacity = element.ancestorRenderObjectOfType(const TypeMatcher<RenderOpacity>());
      return renderOpacity.opacity;
    });

    expect(opacities, <double> [
        0.0, // Initially the smaller font title is invisible.
        1.0, // The larger font title is visible.
    ]);

    expect(tester.getTopLeft(find.widgetWithText(OverflowBox, 'Title')).dy, 44.0);
    expect(tester.getSize(find.widgetWithText(OverflowBox, 'Title')).height, 56.0);

    scrollController.jumpTo(600.0);
    await tester.pump(); // Once to trigger the opacity animation.
    await tester.pump(const Duration(milliseconds: 300));

    titles = tester.elementList(find.text('Title'))
        .toList()
        ..sort((Element a, Element b) {
          final RenderParagraph aParagraph = a.renderObject;
          final RenderParagraph bParagraph = b.renderObject;
          return aParagraph.text.style.fontSize.compareTo(bParagraph.text.style.fontSize);
        });

    opacities = titles.map((Element element) {
      final RenderOpacity renderOpacity = element.ancestorRenderObjectOfType(const TypeMatcher<RenderOpacity>());
      return renderOpacity.opacity;
    });

    expect(opacities, <double> [
        1.0, // Smaller font title now visiblee
        0.0, // Larger font title invisible.
    ]);

    // The persistent toolbar doesn't move or change size.
    expect(tester.getTopLeft(find.byType(NavigationToolbar)).dy, 0.0);
    expect(tester.getSize(find.byType(NavigationToolbar)).height, 44.0);

    expect(tester.getTopLeft(find.widgetWithText(OverflowBox, 'Title')).dy, 44.0);
    // The OverflowBox is squished with the text in it.
    expect(tester.getSize(find.widgetWithText(OverflowBox, 'Title')).height, 0.0);
  });

  testWidgets('Small title can be overriden', (WidgetTester tester) async {
    final ScrollController scrollController = new ScrollController();
    await tester.pumpWidget(
      new WidgetsApp(
        color: const Color(0xFFFFFFFF),
        onGenerateRoute: (RouteSettings settings) {
          return new CupertinoPageRoute<Null>(
            settings: settings,
            builder: (BuildContext context) {
              return new CupertinoPageScaffold(
                child: new CustomScrollView(
                  controller: scrollController,
                  slivers: <Widget>[
                    const CupertinoSliverNavigationBar(
                      middle: const Text('Different title'),
                      largeTitle: const Text('Title'),
                    ),
                    new SliverToBoxAdapter(
                      child: new Container(
                        height: 1200.0,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );

    expect(scrollController.offset, 0.0);
    expect(tester.getTopLeft(find.byType(NavigationToolbar)).dy, 0.0);
    expect(tester.getSize(find.byType(NavigationToolbar)).height, 44.0);

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Different title'), findsOneWidget);

    RenderOpacity largeTitleOpacity =
        tester.element(find.text('Title')).ancestorRenderObjectOfType(const TypeMatcher<RenderOpacity>());
    // Large title initially visible.
    expect(
      largeTitleOpacity.opacity,
      1.0
    );
    // Middle widget not even wrapped with RenderOpacity, i.e. is always visible.
    expect(
      tester.element(find.text('Different title')).ancestorRenderObjectOfType(const TypeMatcher<RenderOpacity>()),
      isNull,
    );

    expect(tester.getBottomLeft(find.text('Title')).dy, 44.0 + 56.0 - 8.0); // Static part + extension - padding.

    scrollController.jumpTo(600.0);
    await tester.pump(); // Once to trigger the opacity animation.
    await tester.pump(const Duration(milliseconds: 300));

    largeTitleOpacity =
        tester.element(find.text('Title')).ancestorRenderObjectOfType(const TypeMatcher<RenderOpacity>());
    // Large title no longer visible.
    expect(
      largeTitleOpacity.opacity,
      0.0
    );

    // The persistent toolbar doesn't move or change size.
    expect(tester.getTopLeft(find.byType(NavigationToolbar)).dy, 0.0);
    expect(tester.getSize(find.byType(NavigationToolbar)).height, 44.0);

    expect(tester.getBottomLeft(find.text('Title')).dy, 44.0 - 8.0); // Extension gone, (static part - padding) left.
  });

  testWidgets('Auto back/close button', (WidgetTester tester) async {
    await tester.pumpWidget(
      new WidgetsApp(
        color: const Color(0xFFFFFFFF),
        onGenerateRoute: (RouteSettings settings) {
          return new CupertinoPageRoute<Null>(
            settings: settings,
            builder: (BuildContext context) {
              return const CupertinoNavigationBar(
                middle: const Text('Home page'),
              );
            },
          );
        },
      ),
    );

    expect(find.byType(CupertinoButton), findsNothing);

    tester.state<NavigatorState>(find.byType(Navigator)).push(new CupertinoPageRoute<Null>(
      builder: (BuildContext context) {
        return const CupertinoNavigationBar(
          middle: const Text('Page 2'),
        );
      },
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(CupertinoButton), findsOneWidget);
    expect(find.byType(Icon), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).push(new CupertinoPageRoute<Null>(
      fullscreenDialog: true,
      builder: (BuildContext context) {
        return const CupertinoNavigationBar(
          middle: const Text('Dialog page'),
        );
      },
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(CupertinoButton), findsNWidgets(2));
    expect(find.text('Close'), findsOneWidget);

    // Test popping goes back correctly.
    await tester.tap(find.text('Close'));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Page 2'), findsOneWidget);

    await tester.tap(find.byType(Icon));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Home page'), findsOneWidget);
  });
}

class _ExpectStyles extends StatelessWidget {
  const _ExpectStyles({ this.color, this.letterSpacing, this.index });

  final Color color;
  final double letterSpacing;
  final int index;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = DefaultTextStyle.of(context).style;
    expect(style.color, color);
    expect(style.fontSize, 17.0);
    expect(style.letterSpacing, letterSpacing ?? -0.24);
    count += index;
    return new Container();
  }
}
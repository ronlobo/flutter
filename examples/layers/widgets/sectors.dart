// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../rendering/src/sector_layout.dart';

RenderBox initCircle() {
  return new RenderBoxToRenderSectorAdapter(
    innerRadius: 25.0,
    child: new RenderSectorRing(padding: 0.0)
  );
}

class SectorApp extends StatefulWidget {
  @override
  SectorAppState createState() => new SectorAppState();
}

class SectorAppState extends State<SectorApp> {

  final RenderBoxToRenderSectorAdapter sectors = initCircle();
  final math.Random rand = new math.Random(1);

  List<double> wantedSectorSizes = <double>[];
  List<double> actualSectorSizes = <double>[];
  double get currentTheta => wantedSectorSizes.fold(0.0, (double total, double value) => total + value);

  void addSector() {
    final double currentTheta = this.currentTheta;
    if (currentTheta < kTwoPi) {
      double deltaTheta;
      if (currentTheta >= kTwoPi - (math.PI * 0.2 + 0.05))
        deltaTheta = kTwoPi - currentTheta;
      else
        deltaTheta = math.PI * rand.nextDouble() / 5.0 + 0.05;
      wantedSectorSizes.add(deltaTheta);
      updateEnabledState();
    }
  }

  void removeSector() {
    if (wantedSectorSizes.isNotEmpty) {
      wantedSectorSizes.removeLast();
      updateEnabledState();
    }
  }

  void doUpdates() {
    int index = 0;
    while (index < actualSectorSizes.length && index < wantedSectorSizes.length && actualSectorSizes[index] == wantedSectorSizes[index])
      index += 1;
    RenderSectorRing ring = sectors.child;
    while (index < actualSectorSizes.length) {
      ring.remove(ring.lastChild);
      actualSectorSizes.removeLast();
    }
    while (index < wantedSectorSizes.length) {
      Color color = new Color(((0xFF << 24) + rand.nextInt(0xFFFFFF)) | 0x808080);
      ring.add(new RenderSolidColor(color, desiredDeltaTheta: wantedSectorSizes[index]));
      actualSectorSizes.add(wantedSectorSizes[index]);
      index += 1;
    }
  }

  static RenderBox initSector(Color color) {
    RenderSectorRing ring = new RenderSectorRing(padding: 1.0);
    ring.add(new RenderSolidColor(const Color(0xFF909090), desiredDeltaTheta: kTwoPi * 0.15));
    ring.add(new RenderSolidColor(const Color(0xFF909090), desiredDeltaTheta: kTwoPi * 0.15));
    ring.add(new RenderSolidColor(color, desiredDeltaTheta: kTwoPi * 0.2));
    return new RenderBoxToRenderSectorAdapter(
      innerRadius: 5.0,
      child: ring
    );
  }
  RenderBoxToRenderSectorAdapter sectorAddIcon = initSector(const Color(0xFF00DD00));
  RenderBoxToRenderSectorAdapter sectorRemoveIcon = initSector(const Color(0xFFDD0000));

  bool _enabledAdd = true;
  bool _enabledRemove = false;
  void updateEnabledState() {
    setState(() {
      _enabledAdd = currentTheta < kTwoPi;
      _enabledRemove = wantedSectorSizes.isNotEmpty;
    });
  }

  Widget buildBody() {
    return new Column(
      children: <Widget>[
        new Container(
          padding: new EdgeInsets.symmetric(horizontal: 8.0, vertical: 25.0),
          child: new Row(
            children: <Widget>[
              new RaisedButton(
                onPressed: _enabledAdd ? addSector : null,
                child: new IntrinsicWidth(
                  child: new Row(
                    children: <Widget>[
                      new Container(
                        padding: new EdgeInsets.all(4.0),
                        margin: new EdgeInsets.only(right: 10.0),
                        child: new WidgetToRenderBoxAdapter(renderBox: sectorAddIcon)
                      ),
                      new Text('ADD SECTOR'),
                    ]
                  )
                )
              ),
              new RaisedButton(
                onPressed: _enabledRemove ? removeSector : null,
                child: new IntrinsicWidth(
                  child: new Row(
                    children: <Widget>[
                      new Container(
                        padding: new EdgeInsets.all(4.0),
                        margin: new EdgeInsets.only(right: 10.0),
                        child: new WidgetToRenderBoxAdapter(renderBox: sectorRemoveIcon)
                      ),
                      new Text('REMOVE SECTOR'),
                    ]
                  )
                )
              ),
            ],
            mainAxisAlignment: MainAxisAlignment.spaceAround
          )
        ),
        new Flexible(
          child: new Container(
            margin: new EdgeInsets.all(8.0),
            decoration: new BoxDecoration(
              border: new Border.all()
            ),
            padding: new EdgeInsets.all(8.0),
            child: new WidgetToRenderBoxAdapter(
              renderBox: sectors,
              onBuild: doUpdates
            )
          )
        ),
      ],
      mainAxisAlignment: MainAxisAlignment.spaceBetween
    );
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      theme: new ThemeData.light(),
      title: 'Sector Layout',
      home: new Scaffold(
        appBar: new AppBar(
          title: new Text('Sector Layout in a Widget Tree')
        ),
        body: buildBody()
      )
    );
  }
}

void main() {
  runApp(new SectorApp());
}

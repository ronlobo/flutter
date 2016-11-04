// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;

void main() {
  runApp(
    new ComplexLayoutApp()
  );
}

class ComplexLayoutApp extends StatefulWidget {
  @override
  ComplexLayoutAppState createState() => new ComplexLayoutAppState();

  static ComplexLayoutAppState of(BuildContext context) => context.ancestorStateOfType(const TypeMatcher<ComplexLayoutAppState>());
}

class ComplexLayoutAppState extends State<ComplexLayoutApp> {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      theme: lightTheme ? new ThemeData.light() : new ThemeData.dark(),
      title: 'Advanced Layout',
      home: new ComplexLayout()
    );
  }

  bool _lightTheme = true;
  bool get lightTheme => _lightTheme;
  set lightTheme(bool value) {
    setState(() {
      _lightTheme = value;
    });
  }

  void toggleAnimationSpeed() {
    setState(() {
      timeDilation = (timeDilation != 1.0) ? 1.0 : 5.0;
    });
  }
}

class ComplexLayout extends StatefulWidget {
  ComplexLayout({ Key key }) : super(key: key);

  @override
  ComplexLayoutState createState() => new ComplexLayoutState();

  static ComplexLayoutState of(BuildContext context) => context.ancestorStateOfType(const TypeMatcher<ComplexLayoutState>());

}

class FancyItemDelegate extends LazyBlockDelegate {
  @override
  Widget buildItem(BuildContext context, int index) {
    if (index % 2 == 0)
      return new FancyImageItem(index, key: new Key('Item $index'));
    else
      return new FancyGalleryItem(index, key: new Key('Item $index'));
  }

  @override
  bool shouldRebuild(FancyItemDelegate oldDelegate) => false;

  @override
  double estimateTotalExtent(int firstIndex, int lastIndex, double minOffset, double firstStartOffset, double lastEndOffset) {
    return double.INFINITY;
  }
}

class ComplexLayoutState extends State<ComplexLayout> {
  @override
  Widget build(BuildContext context) {

    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Advanced Layout'),
        actions: <Widget>[
          new IconButton(
            icon: new Icon(Icons.create),
            tooltip: 'Search',
            onPressed: () {
              print('Pressed search');
            }
          ),
          new TopBarMenu()
        ]
      ),
      body: new Column(
        children: <Widget>[
          new Flexible(
            child: new LazyBlock(
              key: new Key('main-scroll'),
              delegate: new FancyItemDelegate()
            )
          ),
          new BottomBar()
        ]
      ),
      drawer: new GalleryDrawer()
    );
  }
}

class TopBarMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new PopupMenuButton<String>(
      onSelected: (String value) { print('Selected: $value'); },
      itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
        new PopupMenuItem<String>(
          value: 'Friends',
          child: new MenuItemWithIcon(Icons.people, 'Friends', '5 new')
        ),
        new PopupMenuItem<String>(
          value: 'Events',
          child: new MenuItemWithIcon(Icons.event, 'Events', '12 upcoming')
        ),
        new PopupMenuItem<String>(
          value: 'Events',
          child: new MenuItemWithIcon(Icons.group, 'Groups', '14')
        ),
        new PopupMenuItem<String>(
          value: 'Events',
          child: new MenuItemWithIcon(Icons.image, 'Pictures', '12')
        ),
        new PopupMenuItem<String>(
          value: 'Events',
          child: new MenuItemWithIcon(Icons.near_me, 'Nearby', '33')
        ),
        new PopupMenuItem<String>(
          value: 'Friends',
          child: new MenuItemWithIcon(Icons.people, 'Friends', '5')
        ),
        new PopupMenuItem<String>(
          value: 'Events',
          child: new MenuItemWithIcon(Icons.event, 'Events', '12')
        ),
        new PopupMenuItem<String>(
          value: 'Events',
          child: new MenuItemWithIcon(Icons.group, 'Groups', '14')
        ),
        new PopupMenuItem<String>(
          value: 'Events',
          child: new MenuItemWithIcon(Icons.image, 'Pictures', '12')
        ),
        new PopupMenuItem<String>(
          value: 'Events',
          child: new MenuItemWithIcon(Icons.near_me, 'Nearby', '33')
        )
      ]
    );
  }
}

class MenuItemWithIcon extends StatelessWidget {
  MenuItemWithIcon(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return new Row(
      children: <Widget>[
        new Icon(icon),
        new Padding(
          padding: new EdgeInsets.only(left: 8.0, right: 8.0),
          child: new Text(title)
        ),
        new Text(subtitle, style: Theme.of(context).textTheme.caption)
      ]
    );
  }
}

class FancyImageItem extends StatelessWidget {
  FancyImageItem(this.index, {Key key}) : super(key: key);

  final int index;

  @override
  Widget build(BuildContext context) {
    return new BlockBody(
      children: <Widget>[
        new UserHeader('Ali Connors $index'),
        new ItemDescription(),
        new ItemImageBox(),
        new InfoBar(),
        new Padding(
          padding: new EdgeInsets.symmetric(horizontal: 8.0),
          child: new Divider()
        ),
        new IconBar(),
        new FatDivider()
      ]
    );
  }
}

class FancyGalleryItem extends StatelessWidget {
  FancyGalleryItem(this.index, {Key key}) : super(key: key);

  final int index;
  @override
  Widget build(BuildContext context) {
    return new BlockBody(
      children: <Widget>[
        new UserHeader('Ali Connors'),
        new ItemGalleryBox(index),
        new InfoBar(),
        new Padding(
          padding: new EdgeInsets.symmetric(horizontal: 8.0),
          child: new Divider()
        ),
        new IconBar(),
        new FatDivider()
      ]
    );
  }
}

class InfoBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Padding(
      padding: new EdgeInsets.all(8.0),
      child: new Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          new MiniIconWithText(Icons.thumb_up, '42'),
          new Text('3 Comments', style: Theme.of(context).textTheme.caption)
        ]
      )
    );
  }
}

class IconBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Padding(
      padding: new EdgeInsets.only(left: 16.0, right: 16.0),
      child: new Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          new IconWithText(Icons.thumb_up, 'Like'),
          new IconWithText(Icons.comment, 'Comment'),
          new IconWithText(Icons.share, 'Share'),
        ]
      )
    );
  }
}

class IconWithText extends StatelessWidget {
  IconWithText(this.icon, this.title);

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return new Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        new IconButton(
          icon: new Icon(icon),
          onPressed: () { print('Pressed $title button'); }
        ),
        new Text(title)
      ]
    );
  }
}

class MiniIconWithText extends StatelessWidget {
  MiniIconWithText(this.icon, this.title);

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return new Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        new Padding(
          padding: new EdgeInsets.only(right: 8.0),
          child: new Container(
            width: 16.0,
            height: 16.0,
            decoration: new BoxDecoration(
              backgroundColor: Theme.of(context).primaryColor,
              shape: BoxShape.circle
            ),
            child: new Icon(icon, color: Colors.white, size: 12.0)
          )
        ),
        new Text(title, style: Theme.of(context).textTheme.caption)
      ]
    );
  }
}

class FatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Container(
      height: 8.0,
      decoration: new BoxDecoration(
        backgroundColor: Theme.of(context).dividerColor
      )
    );
  }
}

class UserHeader extends StatelessWidget {
  UserHeader(this.userName);

  final String userName;

  @override
  Widget build(BuildContext context) {
    return new Padding(
      padding: new EdgeInsets.all(8.0),
      child: new Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          new Padding(
            padding: new EdgeInsets.only(right: 8.0),
            child: new Image(
              image: new AssetImage('packages/flutter_gallery_assets/ali_connors_sml.png'),
              width: 32.0,
              height: 32.0
            )
          ),
          new Flexible(
            child: new Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                new RichText(text: new TextSpan(
                  style: Theme.of(context).textTheme.body1,
                  children: <TextSpan>[
                    new TextSpan(text: userName, style: new TextStyle(fontWeight: FontWeight.bold)),
                    new TextSpan(text: ' shared a new '),
                    new TextSpan(text: 'photo', style: new TextStyle(fontWeight: FontWeight.bold))
                  ]
                )),
                new Row(
                  children: <Widget>[
                    new Text('Yesterday at 11:55 • ', style: Theme.of(context).textTheme.caption),
                    new Icon(Icons.people, size: 16.0, color: Theme.of(context).textTheme.caption.color)
                  ]
                )
              ]
            )
          ),
          new TopBarMenu()
        ]
      )
    );
  }
}

class ItemDescription extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Padding(
      padding: new EdgeInsets.all(8.0),
      child: new Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.')
    );
  }
}

class ItemImageBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Padding(
      padding: new EdgeInsets.all(8.0),
      child: new Card(
        child: new Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            new Stack(
              children: <Widget>[
                new SizedBox(
                  height: 230.0,
                  child: new Image(
                    image: new AssetImage('packages/flutter_gallery_assets/top_10_australian_beaches.png')
                  )
                ),
                new Theme(
                  data: new ThemeData.dark(),
                  child: new Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      new IconButton(
                        icon: new Icon(Icons.edit),
                        onPressed: () { print('Pressed edit button'); }
                      ),
                      new IconButton(
                        icon: new Icon(Icons.zoom_in),
                        onPressed: () { print('Pressed zoom button'); }
                      ),
                    ]
                  )
                ),
                new Positioned(
                  bottom: 4.0,
                  left: 4.0,
                  child: new Container(
                    decoration: new BoxDecoration(
                      backgroundColor: Colors.black54,
                      borderRadius: new BorderRadius.circular(2.0)
                    ),
                    padding: new EdgeInsets.all(4.0),
                    child: new RichText(
                      text: new TextSpan(
                        style: new TextStyle(color: Colors.white),
                        children: <TextSpan>[
                          new TextSpan(
                            text: 'Photo by '
                          ),
                          new TextSpan(
                            style: new TextStyle(fontWeight: FontWeight.bold),
                            text: 'Magic Mike'
                          )
                        ]
                      )
                    )
                  )
                )
              ]
            )
            ,
            new Padding(
              padding: new EdgeInsets.all(8.0),
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  new Text('Where can you find that amazing sunset?', style: Theme.of(context).textTheme.body2),
                  new Text('The sun sets over stinson beach', style: Theme.of(context).textTheme.body1),
                  new Text('flutter.io/amazingsunsets', style: Theme.of(context).textTheme.caption)
                ]
              )
            )
          ]
        )
      )
    );
  }
}

class ItemGalleryBox extends StatelessWidget {
  ItemGalleryBox(this.index);

  final int index;

  @override
  Widget build(BuildContext context) {
    List<String> tabNames = <String>[
      'A', 'B', 'C', 'D'
    ];

    return new SizedBox(
      height: 200.0,
      child: new TabBarSelection<String>(
        values: tabNames,
        child: new Column(
          children: <Widget>[
            new Flexible(
              child: new TabBarView<String>(
                children: tabNames.map((String tabName) {
                  return new Container(
                    key: new Key('Tab $index - $tabName'),
                    child: new Padding(
                      padding: new EdgeInsets.all(8.0),
                      child: new Card(
                        child: new Column(
                          children: <Widget>[
                            new Flexible(
                              child: new Container(
                                decoration: new BoxDecoration(
                                  backgroundColor: Theme.of(context).primaryColor
                                ),
                                child: new Center(
                                  child: new Text(tabName, style: Theme.of(context).textTheme.headline.copyWith(color: Colors.white))
                                )
                              )
                            ),
                            new Row(
                              children: <Widget>[
                                new IconButton(
                                  icon: new Icon(Icons.share),
                                  onPressed: () { print('Pressed share'); }
                                ),
                                new IconButton(
                                  icon: new Icon(Icons.event),
                                  onPressed: () { print('Pressed event'); }
                                ),
                                new Flexible(
                                  child: new Padding(
                                    padding: new EdgeInsets.only(left: 8.0),
                                    child: new Text('This is item $tabName')
                                  )
                                )
                              ]
                            )
                          ]
                        )
                      )
                    )
                  );
                }).toList()
              )
            ),
            new Container(
              child: new TabPageSelector<String>()
            )
          ]
        )
      )
    );
  }
}

class BottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Container(
      decoration: new BoxDecoration(
        border: new Border(
          top: new BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1.0
          )
        )
      ),
      child: new Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          new BottomBarButton(Icons.new_releases, 'News'),
          new BottomBarButton(Icons.people, 'Requests'),
          new BottomBarButton(Icons.chat, 'Messenger'),
          new BottomBarButton(Icons.bookmark, 'Bookmark'),
          new BottomBarButton(Icons.alarm, 'Alarm')
        ]
      )
    );
  }
}

class BottomBarButton extends StatelessWidget {
  BottomBarButton(this.icon, this.title);

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return new Padding(
      padding: new EdgeInsets.all(8.0),
      child: new Column(
        children: <Widget>[
          new IconButton(
            icon: new Icon(icon),
            onPressed: () { print('Pressed: $title'); }
          ),
          new Text(title, style: Theme.of(context).textTheme.caption)
        ]
      )
    );
  }
}

class GalleryDrawer extends StatelessWidget {
  GalleryDrawer({ Key key }) : super(key: key);

  void _changeTheme(BuildContext context, bool value) {
    ComplexLayoutApp.of(context).lightTheme = value;
  }

  @override
  Widget build(BuildContext context) {
    return new Drawer(
      child: new Block(
        children: <Widget>[
          new FancyDrawerHeader(),
          new DrawerItem(
            icon: new Icon(Icons.brightness_5),
            onPressed: () { _changeTheme(context, true); },
            selected: ComplexLayoutApp.of(context).lightTheme,
            child: new Row(
              children: <Widget>[
                new Flexible(child: new Text('Light')),
                new Radio<bool>(
                  value: true,
                  groupValue: ComplexLayoutApp.of(context).lightTheme,
                  onChanged: (bool value) { _changeTheme(context, value); }
                )
              ]
            )
          ),
          new DrawerItem(
            icon: new Icon(Icons.brightness_7),
            onPressed: () { _changeTheme(context, false); },
            selected: !ComplexLayoutApp.of(context).lightTheme,
            child: new Row(
              children: <Widget>[
                new Flexible(child: new Text('Dark')),
                new Radio<bool>(
                  value: false,
                  groupValue: ComplexLayoutApp.of(context).lightTheme,
                  onChanged: (bool value) { _changeTheme(context, value); }
                )
              ]
            )
          ),
          new Divider(),
          new DrawerItem(
            icon: new Icon(Icons.hourglass_empty),
            selected: timeDilation != 1.0,
            onPressed: () { ComplexLayoutApp.of(context).toggleAnimationSpeed(); },
            child: new Row(
              children: <Widget>[
                new Flexible(child: new Text('Animate Slowly')),
                new Checkbox(
                  value: timeDilation != 1.0,
                  onChanged: (bool value) { ComplexLayoutApp.of(context).toggleAnimationSpeed(); }
                )
              ]
            )
          )
        ]
      )
    );
  }
}

class FancyDrawerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Container(
      decoration: new BoxDecoration(
        backgroundColor: Colors.purple[500]
      ),
      height: 200.0
    );
  }
}

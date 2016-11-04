// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

import 'button.dart';
import 'button_bar.dart';
import 'card.dart';
import 'data_table.dart';
import 'data_table_source.dart';
import 'drop_down.dart';
import 'icon.dart';
import 'icon_button.dart';
import 'icon_theme.dart';
import 'icon_theme_data.dart';
import 'icons.dart';
import 'progress_indicator.dart';
import 'theme.dart';

/// A wrapper for [DataTable] that obtains data lazily from a [DataTableSource]
/// and displays it one page at a time. The widget is presented as a [Card].
class PaginatedDataTable extends StatefulWidget {
  /// Creates a widget describing a paginated [DataTable] on a [Card].
  ///
  /// The [header] should give the card's header, typically a [Text] widget. It
  /// must not be null.
  ///
  /// The [columns] argument must be a list of as many [DataColumn] objects as
  /// the table is to have columns, ignoring the leading checkbox column if any.
  /// The [columns] argument must have a length greater than zero and cannot be
  /// null.
  ///
  /// If the table is sorted, the column that provides the current primary key
  /// should be specified by index in [sortColumnIndex], 0 meaning the first
  /// column in [columns], 1 being the next one, and so forth.
  ///
  /// The actual sort order can be specified using [sortAscending]; if the sort
  /// order is ascending, this should be true (the default), otherwise it should
  /// be false.
  ///
  /// The [source] must not be null. The [source] should be a long-lived
  /// [DataTableSource]. The same source should be provided each time a
  /// particular [PaginatedDataTable] widget is created; avoid creating a new
  /// [DataTableSource] with each new instance of the [PaginatedDataTable]
  /// widget unless the data table really is to now show entirely different
  /// data from a new source.
  ///
  /// The [rowsPerPage] and [availableRowsPerPage] must not be null (they
  /// both have defaults, though, so don't have to be specified).
  PaginatedDataTable({
    Key key,
    @required this.header,
    this.actions,
    this.columns,
    this.sortColumnIndex,
    this.sortAscending: true,
    this.onSelectAll,
    this.initialFirstRowIndex: 0,
    this.onPageChanged,
    this.rowsPerPage: defaultRowsPerPage,
    this.availableRowsPerPage: const <int>[defaultRowsPerPage, defaultRowsPerPage * 2, defaultRowsPerPage * 5, defaultRowsPerPage * 10],
    this.onRowsPerPageChanged,
    @required this.source
  }) : super(key: key) {
    assert(header != null);
    assert(columns != null);
    assert(columns.length > 0);
    assert(sortColumnIndex == null || (sortColumnIndex >= 0 && sortColumnIndex < columns.length));
    assert(sortAscending != null);
    assert(rowsPerPage != null);
    assert(rowsPerPage > 0);
    assert(availableRowsPerPage != null);
    assert(availableRowsPerPage.contains(rowsPerPage));
    assert(source != null);
  }

  /// The table card's header.
  ///
  /// This is typically a [Text] widget, but can also be a [ButtonBar] with
  /// [FlatButton]s. Suitable defaults are automatically provided for the font,
  /// button color, button padding, and so forth.
  ///
  /// If items in the table are selectable, then, when the selection is not
  /// empty, the header is replaced by a count of the selected items.
  final Widget header;

  /// Icon buttons to show at the top right of the table.
  ///
  /// Typically, the exact actions included in this list will vary based on
  /// whether any rows are selected or not.
  ///
  /// These should be size 24.0 with default padding (8.0).
  final List<Widget> actions;

  /// The configuration and labels for the columns in the table.
  final List<DataColumn> columns;

  /// The current primary sort key's column.
  ///
  /// See [DataTable.sortColumnIndex].
  final int sortColumnIndex;

  /// Whether the column mentioned in [sortColumnIndex], if any, is sorted
  /// in ascending order.
  ///
  /// See [DataTable.sortAscending].
  final bool sortAscending;

  /// Invoked when the user selects or unselects every row, using the
  /// checkbox in the heading row.
  ///
  /// See [DataTable.onSelectAll].
  final ValueSetter<bool> onSelectAll;

  /// The index of the first row to display when the widget is first created.
  final int initialFirstRowIndex;

  /// Invoked when the user switches to another page.
  ///
  /// The value is the index of the first row on the currently displayed page.
  final ValueChanged<int> onPageChanged;

  /// The number of rows to show on each page.
  ///
  /// See also:
  ///
  /// * [onRowsPerPageChanged]
  /// * [defaultRowsPerPage]
  final int rowsPerPage;

  /// The default value for [rowsPerPage].
  ///
  /// Useful when initializing the field that will hold the current
  /// [rowsPerPage], when implemented [onRowsPerPageChanged].
  static const int defaultRowsPerPage = 10;

  /// The options to offer for the rowsPerPage.
  ///
  /// The current [rowsPerPage] must be a value in this list.
  ///
  /// The values in this list should be sorted in ascending order.
  final List<int> availableRowsPerPage;

  /// Invoked when the user selects a different number of rows per page.
  ///
  /// If this is null, then the value given by [rowsPerPage] will be used
  /// and no affordance will be provided to change the value.
  final ValueChanged<int> onRowsPerPageChanged;

  /// The data source which provides data to show in each row. Must be non-null.
  ///
  /// This object should generally have a lifetime longer than the
  /// [PaginatedDataTable] widget itself; it should be reused each time the
  /// [PaginatedDataTable] constructor is called.
  final DataTableSource source;

  @override
  PaginatedDataTableState createState() => new PaginatedDataTableState();
}

/// Holds the state of a [PaginatedDataTable].
///
/// The table can be programmatically paged using the [pageTo] method.
class PaginatedDataTableState extends State<PaginatedDataTable> {
  int _firstRowIndex;
  int _rowCount;
  bool _rowCountApproximate;
  int _selectedRowCount;
  final Map<int, DataRow> _rows = <int, DataRow>{};

  @override
  void initState() {
    super.initState();
    _firstRowIndex = PageStorage.of(context)?.readState(context) ?? config.initialFirstRowIndex ?? 0;
    config.source.addListener(_handleDataSourceChanged);
    _handleDataSourceChanged();
  }

  @override
  void didUpdateConfig(PaginatedDataTable oldConfig) {
    super.didUpdateConfig(oldConfig);
    if (oldConfig.source != config.source) {
      oldConfig.source.removeListener(_handleDataSourceChanged);
      config.source.addListener(_handleDataSourceChanged);
      _handleDataSourceChanged();
    }
  }

  @override
  void dispose() {
    config.source.removeListener(_handleDataSourceChanged);
    super.dispose();
  }

  void _handleDataSourceChanged() {
    setState(() {
      _rowCount = config.source.rowCount;
      _rowCountApproximate = config.source.isRowCountApproximate;
      _selectedRowCount = config.source.selectedRowCount;
      _rows.clear();
    });
  }

  /// Ensures that the given row is visible.
  void pageTo(int rowIndex) {
    final int oldFirstRowIndex = _firstRowIndex;
    setState(() {
      final int rowsPerPage = config.rowsPerPage;
      _firstRowIndex = (rowIndex ~/ rowsPerPage) * rowsPerPage;
    });
    if ((config.onPageChanged != null) &&
        (oldFirstRowIndex != _firstRowIndex))
      config.onPageChanged(_firstRowIndex);
  }

  DataRow _getBlankRowFor(int index) {
    return new DataRow.byIndex(
      index: index,
      cells: config.columns.map/*<DataCell>*/((DataColumn column) => DataCell.empty).toList()
    );
  }

  DataRow _getProgressIndicatorRowFor(int index) {
    bool haveProgressIndicator = false;
    final List<DataCell> cells = config.columns.map/*<DataCell>*/((DataColumn column) {
      if (!column.numeric) {
        haveProgressIndicator = true;
        return new DataCell(new CircularProgressIndicator());
      }
      return DataCell.empty;
    }).toList();
    if (!haveProgressIndicator) {
      haveProgressIndicator = true;
      cells[0] = new DataCell(new CircularProgressIndicator());
    }
    return new DataRow.byIndex(
      index: index,
      cells: cells
    );
  }

  List<DataRow> _getRows(int firstRowIndex, int rowsPerPage) {
    final List<DataRow> result = <DataRow>[];
    final int nextPageFirstRowIndex = firstRowIndex + rowsPerPage;
    bool haveProgressIndicator = false;
    for (int index = firstRowIndex; index < nextPageFirstRowIndex; index += 1) {
      DataRow row;
      if (index < _rowCount || _rowCountApproximate) {
        row = _rows.putIfAbsent(index, () => config.source.getRow(index));
        if (row == null && !haveProgressIndicator) {
          row ??= _getProgressIndicatorRowFor(index);
          haveProgressIndicator = true;
        }
      }
      row ??= _getBlankRowFor(index);
      result.add(row);
    }
    return result;
  }

  final GlobalKey _tableKey = new GlobalKey();

  @override
  Widget build(BuildContext context) {
    // TODO(ianh): This whole build function doesn't handle RTL yet.
    ThemeData themeData = Theme.of(context);
    // HEADER
    final List<Widget> headerWidgets = <Widget>[];
    double leftPadding = 24.0;
    if (_selectedRowCount == 0) {
      headerWidgets.add(new Flexible(child: config.header));
      if (config.header is ButtonBar) {
        // We adjust the padding when a button bar is present, because the
        // ButtonBar introduces 2 pixels of outside padding, plus 2 pixels
        // around each button on each side, and the button itself will have 8
        // pixels internally on each side, yet we want the left edge of the
        // inside of the button to line up with the 24.0 left inset.
        // TODO(ianh): Better magic. See https://github.com/flutter/flutter/issues/4460
        leftPadding = 12.0;
      }
    } else if (_selectedRowCount == 1) {
      // TODO(ianh): Real l10n.
      headerWidgets.add(new Flexible(child: new Text('1 item selected')));
    } else {
      headerWidgets.add(new Flexible(child: new Text('$_selectedRowCount items selected')));
    }
    if (config.actions != null) {
      headerWidgets.addAll(
        config.actions.map/*<Widget>*/((Widget widget) {
          return new Padding(
            // 8.0 is the default padding of an icon button
            padding: new EdgeInsets.only(left: 24.0 - 8.0 * 2.0),
            child: widget
          );
        }).toList()
      );
    }

    // FOOTER
    final TextStyle footerTextStyle = themeData.textTheme.caption;
    final List<Widget> footerWidgets = <Widget>[];
    if (config.onRowsPerPageChanged != null) {
      List<Widget> availableRowsPerPage = config.availableRowsPerPage
        .where((int value) => value <= _rowCount)
        .map/*<DropdownMenuItem<int>>*/((int value) {
          return new DropdownMenuItem<int>(
            value: value,
            child: new Text('$value')
          );
        })
        .toList();
      footerWidgets.addAll(<Widget>[
        new Text('Rows per page:'),
        new DropdownButtonHideUnderline(
          child: new DropdownButton<int>(
            items: availableRowsPerPage,
            value: config.rowsPerPage,
            onChanged: config.onRowsPerPageChanged,
            style: footerTextStyle,
            iconSize: 24.0
          )
        ),
      ]);
    }
    footerWidgets.addAll(<Widget>[
      new Container(width: 32.0),
      new Text(
        '${_firstRowIndex + 1}\u2013${_firstRowIndex + config.rowsPerPage} ${ _rowCountApproximate ? "of about" : "of" } $_rowCount'
      ),
      new Container(width: 32.0),
      new IconButton(
        icon: new Icon(Icons.chevron_left),
        padding: EdgeInsets.zero,
        onPressed: _firstRowIndex <= 0 ? null : () {
          pageTo(math.max(_firstRowIndex - config.rowsPerPage, 0));
        }
      ),
      new Container(width: 24.0),
      new IconButton(
        icon: new Icon(Icons.chevron_right),
        padding: EdgeInsets.zero,
        onPressed: (!_rowCountApproximate && (_firstRowIndex + config.rowsPerPage >= _rowCount)) ? null : () {
          pageTo(_firstRowIndex + config.rowsPerPage);
        }
      ),
      new Container(width: 14.0),
    ]);

    // CARD
    return new Card(
      child: new BlockBody(
        children: <Widget>[
          new DefaultTextStyle(
            // These typographic styles aren't quite the regular ones. We pick the closest ones from the regular
            // list and then tweak them appropriately.
            // See https://material.google.com/components/data-tables.html#data-tables-tables-within-cards
            style: _selectedRowCount > 0 ? themeData.textTheme.subhead.copyWith(color: themeData.accentColor)
                                         : themeData.textTheme.title.copyWith(fontWeight: FontWeight.w400),
            child: new IconTheme.merge(
              context: context,
              data: new IconThemeData(
                opacity: 0.54
              ),
              child: new ButtonTheme.bar(
                child: new Container(
                  height: 64.0,
                  padding: new EdgeInsets.fromLTRB(leftPadding, 0.0, 14.0, 0.0),
                  // TODO(ianh): This decoration will prevent ink splashes from being visible.
                  // Instead, we should have a widget that prints the decoration on the material.
                  // See https://github.com/flutter/flutter/issues/3782
                  decoration: _selectedRowCount > 0 ? new BoxDecoration(
                    backgroundColor: themeData.secondaryHeaderColor
                  ) : null,
                  child: new Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: headerWidgets
                  )
                )
              )
            )
          ),
          new ScrollableViewport(
            scrollDirection: Axis.horizontal,
            child: new DataTable(
              key: _tableKey,
              columns: config.columns,
              sortColumnIndex: config.sortColumnIndex,
              sortAscending: config.sortAscending,
              onSelectAll: config.onSelectAll,
              rows: _getRows(_firstRowIndex, config.rowsPerPage)
            )
          ),
          new DefaultTextStyle(
            style: footerTextStyle,
            child: new IconTheme.merge(
              context: context,
              data: new IconThemeData(
                opacity: 0.54
              ),
              child: new Container(
                height: 56.0,
                child: new Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: footerWidgets
                )
              )
            )
          )
        ]
      )
    );
  }
}

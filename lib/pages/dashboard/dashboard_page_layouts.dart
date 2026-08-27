import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dot_cast/dot_cast.dart';
import 'package:file_selector/file_selector.dart';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/hotkey_manager.dart';
import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/util/tab_data.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';

mixin DashboardPageLayouts on DashboardPageViewModel {
  @override
  Future<void> saveLayout() async {
    Map<String, dynamic> jsonData = toJson();

    bool successful = await preferences.setString(
      PrefKeys.layout,
      jsonEncode(jsonData),
    );
    await saveWindowPosition();

    if (successful) {
      logger.info('Layout saved successfully');
      showInfoNotification(
        title: 'Saved',
        message: 'Layout saved successfully',
        width: 300,
      );
    } else {
      logger.error('Could not save layout');
      showInfoNotification(
        title: 'Error While Saving Layout',
        message: 'Failed to save layout, please try again',
        width: 300,
      );
    }
  }

  @override
  Future<void> exportLayout() async {
    const XTypeGroup jsonTypeGroup = XTypeGroup(
      label: 'JSON (JavaScript Object Notation)',
      extensions: ['.json'],
      mimeTypes: ['application/json'],
      uniformTypeIdentifiers: ['public.json'],
    );

    const XTypeGroup anyTypeGroup = XTypeGroup(label: 'All Files');

    logger.info('Exporting layout');
    final FileSaveLocation? saveLocation = await getSaveLocation(
      suggestedName: 'elastic-layout.json',
      acceptedTypeGroups: [jsonTypeGroup, anyTypeGroup],
    );

    hotKeyManager.resetKeysPressed();

    if (saveLocation == null) {
      logger.info('Ignoring layout export, no location was selected');
      return;
    }

    Map<String, dynamic> jsonData = toJson();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    String jsonString = encoder.convert(jsonData);

    final Uint8List fileData = utf8.encode(jsonString);

    final XFile jsonFile = XFile.fromData(
      fileData,
      mimeType: 'application/json',
      name: 'elastic-layout.json',
    );

    logger.info('Saving layout data to ${saveLocation.path}');
    await jsonFile.saveTo(saveLocation.path);
    showInfoNotification(
      title: 'Exported Layout',
      message: 'Successfully exported layout to\n${saveLocation.path}',
      width: 500,
    );
  }

  @override
  Future<void> importLayout() async {
    if (preferences.getBool(PrefKeys.layoutLocked) ?? Defaults.layoutLocked) {
      return;
    }
    const XTypeGroup jsonTypeGroup = XTypeGroup(
      label: 'JSON (JavaScript Object Notation)',
      extensions: ['.json'],
      mimeTypes: ['application/json'],
      uniformTypeIdentifiers: ['public.json'],
    );

    const XTypeGroup anyTypeGroup = XTypeGroup(label: 'All Files');

    logger.info('Importing layout');
    final XFile? file = await openFile(
      acceptedTypeGroups: [jsonTypeGroup, anyTypeGroup],
    );

    hotKeyManager.resetKeysPressed();

    if (file == null) {
      logger.info('Canceling layout import, no file was selected');
      return;
    }

    String jsonString;

    try {
      jsonString = await file.readAsString();
    } on FileSystemException catch (e) {
      showJsonLoadingError(e.message);
      return;
    }

    Map<String, dynamic> jsonData;
    try {
      jsonData = jsonDecode(jsonString);
    } catch (e) {
      showJsonLoadingError(e.toString());
      return;
    }

    await preferences.setString(PrefKeys.layout, jsonEncode(jsonData));

    loadLayoutFromJsonData(jsonString);
    notifyListeners();
  }

  @override
  void loadLayout() {
    String? jsonString = preferences.getString(PrefKeys.layout);

    if (jsonString == null) {
      createDefaultTabs();
      return;
    }

    loadLayoutFromJsonData(jsonString);
    notifyListeners();
  }

  @override
  bool validateJsonData(Map<String, dynamic>? jsonData) {
    if (jsonData == null) {
      showJsonLoadingError('Invalid JSON format, aborting.');
      return false;
    }

    if (!jsonData.containsKey('tabs')) {
      showJsonLoadingError('JSON does not contain necessary data, aborting.');
      return false;
    }

    for (Map<String, dynamic> data in jsonData['tabs']) {
      if (tryCast(data['name']) == null) {
        showJsonLoadingError('Tab name not specified');
        return false;
      }

      if (tryCast<Map>(data['grid_layout']) == null) {
        showJsonLoadingError(
          'Grid layout not specified for tab \'${data['name']}\'',
        );
        return false;
      }
    }

    return true;
  }

  @override
  void clearLayout() {
    for (TabData tab in tabData) {
      tab.tabGrid.onDestroy();
    }
    tabData.clear();
  }

  @override
  bool loadLayoutFromJsonData(String jsonString) {
    logger.info('Loading layout from json');
    Map<String, dynamic>? jsonData = tryCast(jsonDecode(jsonString));

    if (!validateJsonData(jsonData)) {
      createDefaultTabs();
      return false;
    }

    if (jsonData!.containsKey('grid_size')) {
      gridSize = tryCast(jsonData['grid_size']) ?? gridSize;
      preferences.setInt(PrefKeys.gridSize, gridSize);
    }

    clearLayout();

    for (Map<String, dynamic> data in jsonData['tabs']) {
      tabData.add(
        TabData(
          name: data['name'],
          tabGrid: TabGridModel.fromJson(
            ntConnection: ntConnection,
            preferences: preferences,
            jsonData: data['grid_layout'],
            onAddWidgetPressed: displayAddWidgetDialog,
            onJsonLoadingWarning: showJsonLoadingWarning,
          ),
        ),
      );
    }

    createDefaultTabs();

    if (currentTabIndex >= tabData.length) {
      switchToTab(tabData.length - 1);
    }

    return true;
  }

  @override
  void lockLayout() async {
    for (TabGridModel grid in tabData.map((e) => e.tabGrid)) {
      grid.lockLayout();
    }
    await preferences.setBool(PrefKeys.layoutLocked, true);
  }

  @override
  void unlockLayout() async {
    for (TabGridModel grid in tabData.map((e) => e.tabGrid)) {
      grid.unlockLayout();
    }
    await preferences.setBool(PrefKeys.layoutLocked, false);
  }
}

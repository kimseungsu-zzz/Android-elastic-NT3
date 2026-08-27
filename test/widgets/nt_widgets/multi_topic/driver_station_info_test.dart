import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt3_client.dart';
import 'package:elastic_dashboard/services/nt3_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/driver_station_info.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> dsInfoJson = {
    'topic': 'Test/DSInfo',
    'period': 0.100,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  NTConnection createNTConnection({
    String eventName = '',
    bool redAlliance = false,
    int matchNumber = 0,
    int matchType = 0,
    int replayNumber = 0,
    bool enabled = false,
    bool teleop = false,
    bool auto = false,
    bool testMode = false,
    bool estop = false,
    bool fmsAttached = false,
    bool dsAttached = false,
  }) {
    int controlWord = 0;
    if (enabled) controlWord |= 0x01;
    if (auto) controlWord |= 0x02;
    if (testMode) controlWord |= 0x04;
    if (estop) controlWord |= 0x08;
    if (fmsAttached) controlWord |= 0x10;
    if (dsAttached) controlWord |= 0x20;

    return createMockOnlineNT3(
      virtualTopics: [
        NT3Topic(
          name: 'Test/DSInfo/MatchState/EventName',
          type: NT3Type.string(),
          properties: {},
        ),
        NT3Topic(
          name: 'Test/DSInfo/FMSControlData',
          type: NT3Type.double(),
          properties: {},
        ),
        NT3Topic(
          name: 'Test/DSInfo/MatchState/IsRedAlliance',
          type: NT3Type.boolean(),
          properties: {},
        ),
        NT3Topic(
          name: 'Test/DSInfo/MatchState/MatchNumber',
          type: NT3Type.double(),
          properties: {},
        ),
        NT3Topic(
          name: 'Test/DSInfo/MatchState/MatchType',
          type: NT3Type.double(),
          properties: {},
        ),
        NT3Topic(
          name: 'Test/DSInfo/MatchState/ReplayNumber',
          type: NT3Type.double(),
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/DSInfo/MatchState/EventName': eventName,
        'Test/DSInfo/FMSControlData': controlWord.toDouble(),
        'Test/DSInfo/MatchState/IsRedAlliance': redAlliance,
        'Test/DSInfo/MatchState/MatchNumber': matchNumber,
        'Test/DSInfo/MatchState/MatchType': matchType,
        'Test/DSInfo/MatchState/ReplayNumber': replayNumber,
      },
    );
  }

  Future<void> pushDSInfoWidget(
    WidgetTester widgetTester,
    NTConnection ntConnection,
  ) async {
    NTWidgetModel dsInfoModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'DSInfo',
      dsInfoJson,
    );

    return widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: dsInfoModel,
            child: const DriverStationInfo(),
          ),
        ),
      ),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createNTConnection(
      eventName: 'CMPTX',
      redAlliance: false,
      matchNumber: 15,
      matchType: 3,
      replayNumber: 1,
      enabled: true,
      teleop: true,
      fmsAttached: true,
      dsAttached: true,
    );
  });

  test('DSInfo from json', () {
    NTWidgetModel dsInfoModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'DSInfo',
      dsInfoJson,
    );

    expect(dsInfoModel.type, 'DSInfo');
    expect(dsInfoModel.runtimeType, DriverStationInfoModel);
  });

  test('DSInfo to json', () {
    DriverStationInfoModel dsInfoModel = DriverStationInfoModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/DSInfo',
      period: 0.100,
    );

    expect(dsInfoModel.toJson(), dsInfoJson);
  });

  testWidgets('DSInfo CMPTX E15, Teleop Enabled', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await pushDSInfoWidget(widgetTester, ntConnection);

    await widgetTester.pumpAndSettle();

    expect(find.text('CMPTX Elimination match 15 (replay 1)'), findsOneWidget);
    expect(find.text('DriverStation Connected'), findsOneWidget);
    expect(find.text('FMS Connected'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(2));

    expect(find.text('Robot State: Teleoperated'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.blue.shade900,
      ),
      findsOneWidget,
    );
  });

  testWidgets('DSInfo NYSU Q72, Auto Enabled', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await pushDSInfoWidget(
      widgetTester,
      createNTConnection(
        eventName: 'NYSU',
        redAlliance: false,
        matchNumber: 72,
        matchType: 2,
        replayNumber: 1,
        enabled: true,
        auto: true,
        fmsAttached: true,
        dsAttached: true,
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('NYSU Qualification match 72 (replay 1)'), findsOneWidget);
    expect(find.text('DriverStation Connected'), findsOneWidget);
    expect(find.text('FMS Connected'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(2));

    expect(find.text('Robot State: Autonomous'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.blue.shade900,
      ),
      findsOneWidget,
    );
  });

  testWidgets('DSInfo NYLI2 P7, Estopped', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await pushDSInfoWidget(
      widgetTester,
      createNTConnection(
        eventName: 'NYLI2',
        redAlliance: true,
        matchNumber: 7,
        matchType: 1,
        replayNumber: 1,
        estop: true,
        fmsAttached: true,
        dsAttached: true,
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('NYLI2 Practice match 7 (replay 1)'), findsOneWidget);
    expect(find.text('DriverStation Connected'), findsOneWidget);
    expect(find.text('FMS Connected'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(2));

    expect(find.text('EMERGENCY STOPPED'), findsOneWidget);
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(2));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.red.shade900,
      ),
      findsOneWidget,
    );
  });

  testWidgets('DSInfo Unknown Match, test enabled', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await pushDSInfoWidget(
      widgetTester,
      createNTConnection(
        eventName: '',
        redAlliance: true,
        matchNumber: 0,
        matchType: 0,
        replayNumber: 0,
        enabled: true,
        testMode: true,
        fmsAttached: false,
        dsAttached: true,
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Unknown match 0'), findsOneWidget);
    expect(find.text('DriverStation Connected'), findsOneWidget);
    expect(find.text('FMS Disconnected'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(1));
    expect(find.byIcon(Icons.clear), findsNWidgets(1));

    expect(find.text('Robot State: Test'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.red.shade900,
      ),
      findsOneWidget,
    );
  });

  testWidgets('DSInfo Unknown Match, everything disconnected', (
    widgetTester,
  ) async {
    FlutterError.onError = ignoreOverflowErrors;

    await pushDSInfoWidget(
      widgetTester,
      createNTConnection(
        eventName: '',
        redAlliance: true,
        matchNumber: 0,
        matchType: 0,
        replayNumber: 0,
        teleop: false,
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Unknown match 0'), findsOneWidget);
    expect(find.text('DriverStation Disconnected'), findsOneWidget);
    expect(find.text('FMS Disconnected'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(0));
    expect(find.byIcon(Icons.clear), findsNWidgets(2));

    expect(find.text('Robot State: Disabled'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.red.shade900,
      ),
      findsOneWidget,
    );
  });
}

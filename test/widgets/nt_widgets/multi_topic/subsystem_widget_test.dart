import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt3_client.dart';
import 'package:elastic_dashboard/services/nt3_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/subsystem_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> subsystemJson = {
    'topic': 'Test/Subsystem',
    'period': 0.100,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT3(
      virtualTopics: [
        NT3Topic(
          name: 'Test/Subsystem/.default',
          type: NT3Type.string(),
          properties: {},
        ),
        NT3Topic(
          name: 'Test/Subsystem/.command',
          type: NT3Type.string(),
          properties: {},
        ),
      ],
      virtualValues: {'Test/Subsystem/.command': 'TestCommand'},
    );
  });

  test('Subsystem model from json', () {
    NTWidgetModel subsystemModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Subsystem',
      subsystemJson,
    );

    expect(subsystemModel.type, 'Subsystem');
    expect(subsystemModel.runtimeType, SubsystemModel);
  });

  test('Subsystem model to json', () {
    SubsystemModel subsystemModel = SubsystemModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Subsystem',
      period: 0.100,
    );

    expect(subsystemModel.toJson(), subsystemJson);
  });

  testWidgets('Subsystem widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel subsystemModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Subsystem',
      subsystemJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: subsystemModel,
            child: const SubsystemWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Default Command: none'), findsOneWidget);
    expect(find.text('Current Command: TestCommand'), findsOneWidget);
  });
}

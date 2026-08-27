import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt3_client.dart';
import 'package:elastic_dashboard/services/nt3_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/split_button_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/boolean_box.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/graph.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/large_text_display.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/match_time.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/multi_color_view.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/number_bar.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/number_slider.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/radial_gauge.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/single_color_view.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/text_display.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/toggle_button.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/voltage_view.dart';

sealed class NTWidgetModel extends ChangeNotifier {
  String get type;

  final NTConnection ntConnection;
  final SharedPreferences preferences;

  late double _period;

  late String _topic;

  // ignore: unnecessary_getters_setters
  String get topic => _topic;

  set topic(String value) => _topic = value;

  // ignore: unnecessary_getters_setters
  double get period => _period;

  set period(double value) => _period = value;

  NTWidgetModel({
    required this.ntConnection,
    required this.preferences,
    required String topic,
    double? period,
  }) : _topic = topic {
    this.period =
        period ??
        preferences.getDouble(PrefKeys.defaultPeriod) ??
        Defaults.defaultPeriod;
  }

  NTWidgetModel.fromJson({
    required this.ntConnection,
    required this.preferences,
    required Map<String, dynamic> jsonData,
  }) {
    _topic = tryCast(jsonData['topic']) ?? '';

    _period =
        tryCast(jsonData['period']) ??
        preferences.getDouble(PrefKeys.defaultPeriod) ??
        Defaults.defaultPeriod;
  }

  @mustCallSuper
  Map<String, dynamic> toJson() => {'topic': topic, 'period': period};

  void init();

  void unSubscribe();

  void softDispose({bool deleting = false});

  void resetSubscription();

  List<String> getAvailableDisplayTypes();

  List<Widget> getEditProperties(BuildContext context) => const [];

  void refresh() => notifyListeners();
}

class SingleTopicNTWidgetModel extends NTWidgetModel {
  String _typeOverride = 'NTWidget';
  @override
  String get type => _typeOverride;

  NT3Type? dataType;

  NT3Subscription? subscription;
  NT3Topic? ntTopic;

  SingleTopicNTWidgetModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    this.dataType,
    super.period,
  }) : super() {
    init();
  }

  SingleTopicNTWidgetModel.createDefault({
    required super.ntConnection,
    required super.preferences,
    required String type,
    required super.topic,
    this.dataType,
    super.period,
  }) : _typeOverride = type,
       super() {
    init();
  }

  SingleTopicNTWidgetModel.createDefaultFromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
    required String type,
  }) : _typeOverride = type,
       super.fromJson(jsonData: jsonData) {
    dataType = NT3Type.parseNullable(tryCast(jsonData['data_type']));

    init();
  }

  SingleTopicNTWidgetModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    dataType = NT3Type.parseNullable(tryCast(jsonData['data_type']));

    init();
  }

  @override
  @mustCallSuper
  Map<String, dynamic> toJson() {
    if (dataType == null && ntConnection.isNT3Connected) {
      createTopicIfNull();
      dataType = ntTopic?.type ?? dataType;
    }

    return {
      ...super.toJson(),
      'data_type': ?dataType?.serialize(),
    };
  }

  @override
  List<String> getAvailableDisplayTypes() {
    createTopicIfNull();
    dataType = ntTopic?.type ?? dataType;

    NT3DataType? ntDataType = dataType?.dataType;

    if (ntDataType == null || dataType == null) {
      return [type];
    }

    List<String> availableTypes = [];

    // Add all type-specific widgets first

    if (ntDataType == NT3DataType.boolean) {
      availableTypes.addAll([
        BooleanBox.widgetType,
        ToggleSwitch.widgetType,
        ToggleButton.widgetType,
      ]);
    }

    if (ntDataType.isNumber) {
      availableTypes.addAll([
        NumberBar.widgetType,
        NumberSlider.widgetType,
        VoltageView.widgetType,
        RadialGaugeWidget.widgetType,
        GraphWidget.widgetType,
        MatchTimeWidget.widgetType,
      ]);
    }

    // Special color widgets for string and string arrays
    if (ntDataType == NT3DataType.string) {
      if (dataType!.isArray) {
        availableTypes.add(MultiColorView.widgetType);
      } else {
        availableTypes.add(SingleColorView.widgetType);
      }
    }

    // Add the rest of the default widgets for anything that is viewable
    if (dataType!.isViewable) {
      availableTypes.addAll([
        TextDisplay.widgetType,
        LargeTextDisplay.widgetType,
      ]);
    }

    availableTypes.add(type);

    return availableTypes.toSet().toList();
  }

  @override
  @mustCallSuper
  void init() async {
    subscription = ntConnection.subscribeWithOptions(
      topic,
      NT3SubscriptionOptions(periodicRateSeconds: period),
    );
  }

  void createTopicIfNull() {
    ntTopic ??= ntConnection.getTopicFromName(topic);
  }

  @override
  void unSubscribe() {
    if (subscription != null) {
      ntConnection.unSubscribe(subscription!);
    }
    refresh();
  }

  @override
  void softDispose({bool deleting = false}) {}

  @override
  void resetSubscription() {
    if (subscription == null) {
      subscription = ntConnection.subscribeWithOptions(
        topic,
        NT3SubscriptionOptions(periodicRateSeconds: period),
      );

      ntTopic = null;

      refresh();
      return;
    }

    bool resetDataType = subscription!.topic != topic;

    ntConnection.unSubscribe(subscription!);
    subscription = ntConnection.subscribeWithOptions(
      topic,
      NT3SubscriptionOptions(periodicRateSeconds: period),
    );

    ntTopic = null;

    createTopicIfNull();
    if (resetDataType) {
      if (ntTopic == null && ntConnection.isNT3Connected) {
        dataType = null;
      } else {
        dataType = ntTopic?.type ?? dataType;
      }
    }

    refresh();
  }
}

class MultiTopicNTWidgetModel extends NTWidgetModel {
  @override
  String get type => 'NTWidget';

  List<NT3Subscription> get subscriptions => [];

  MultiTopicNTWidgetModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
  }) : super() {
    init();
  }

  MultiTopicNTWidgetModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson() {
    init();
  }

  @override
  @mustCallSuper
  void init() {
    initializeSubscriptions();
  }

  void initializeSubscriptions() {}

  @override
  void unSubscribe() {
    for (NT3Subscription subscription in subscriptions) {
      ntConnection.unSubscribe(subscription);
    }
  }

  @override
  void resetSubscription() {
    for (NT3Subscription subscription in subscriptions) {
      ntConnection.unSubscribe(subscription);
    }

    initializeSubscriptions();
    refresh();
  }

  @override
  List<String> getAvailableDisplayTypes() {
    if (type == ComboBoxChooser.widgetType ||
        type == SplitButtonChooser.widgetType) {
      return [ComboBoxChooser.widgetType, SplitButtonChooser.widgetType];
    }

    return [type];
  }

  @override
  void softDispose({bool deleting = false}) {}
}

abstract class NTWidget extends StatelessWidget {
  const NTWidget({super.key});
}

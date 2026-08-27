import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:patterns_canvas/patterns_canvas.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt3_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class DriverStationInfoModel extends MultiTopicNTWidgetModel {
  @override
  String type = DriverStationInfo.widgetType;

  String get eventNameTopic => '$topic/MatchState/EventName';
  String get controlWordTopic => '$topic/FMSControlData';
  String get allianceTopic => '$topic/MatchState/IsRedAlliance';
  String get matchNumberTopic => '$topic/MatchState/MatchNumber';
  String get matchTypeTopic => '$topic/MatchState/MatchType';
  String get replayNumberTopic => '$topic/MatchState/ReplayNumber';
  String get stationNumberTopic => '$topic/MatchState/StationNumber';

  late NT3Subscription eventNameSubscription;
  late NT3Subscription controlWordSubscription;
  late NT3Subscription allianceSubscription;
  late NT3Subscription matchNumberSubscription;
  late NT3Subscription matchTypeSubscription;
  late NT3Subscription replayNumberSubscription;

  @override
  List<NT3Subscription> get subscriptions => [
    eventNameSubscription,
    controlWordSubscription,
    allianceSubscription,
    matchNumberSubscription,
    matchTypeSubscription,
    replayNumberSubscription,
  ];

  DriverStationInfoModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
  });

  DriverStationInfoModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    eventNameSubscription = ntConnection.subscribe(
      eventNameTopic,
      super.period,
    );
    controlWordSubscription = ntConnection.subscribe(
      controlWordTopic,
      super.period,
    );
    allianceSubscription = ntConnection.subscribe(allianceTopic, super.period);
    matchNumberSubscription = ntConnection.subscribe(
      matchNumberTopic,
      super.period,
    );
    matchTypeSubscription = ntConnection.subscribe(
      matchTypeTopic,
      super.period,
    );
    replayNumberSubscription = ntConnection.subscribe(
      replayNumberTopic,
      super.period,
    );
  }
}

class DriverStationInfo extends NTWidget {
  static const String widgetType = 'DSInfo';

  const DriverStationInfo({super.key}) : super();

  String _getMatchTypeString(int matchType) {
    switch (matchType) {
      case 1:
        return 'Practice';
      case 2:
        return 'Qualification';
      case 3:
        return 'Elimination';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    DriverStationInfoModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, child) {
        String eventName = tryCast(model.eventNameSubscription.value) ?? '';
        int controlWord =
            tryCast<num>(model.controlWordSubscription.value)?.toInt() ?? 0;
        bool redAlliance = tryCast(model.allianceSubscription.value) ?? true;
        int matchNumber = tryCast(model.matchNumberSubscription.value) ?? 0;
        int matchType = tryCast(model.matchTypeSubscription.value) ?? 0;
        int replayNumber = tryCast(model.replayNumberSubscription.value) ?? 0;

        String eventNameDisplay = '$eventName${(eventName != '') ? ' ' : ''}';
        String matchTypeString = _getMatchTypeString(matchType);
        String replayNumberDisplay = (replayNumber != 0)
            ? ' (replay $replayNumber)'
            : '';

        bool fmsConnected = controlWord & 0x10 != 0;
        bool dsAttached = controlWord & 0x20 != 0;

        bool emergencyStopped = controlWord & 0x08 != 0;

        String robotControlState = 'Disabled';
        if (controlWord & 0x01 != 0) {
          robotControlState = controlWord & 0x02 != 0
              ? 'Autonomous'
              : controlWord & 0x04 != 0
              ? 'Test'
              : 'Teleoperated';
        }

        String matchDisplayString =
            '$eventNameDisplay$matchTypeString match $matchNumber$replayNumberDisplay';
        Widget matchDisplayWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 5.0),
              decoration: BoxDecoration(
                color: (redAlliance)
                    ? Colors.red.shade900
                    : Colors.blue.shade900,
                borderRadius: BorderRadius.circular(5.0),
              ),
              child: Text(
                matchDisplayString,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        );

        String fmsDisplayString = (fmsConnected)
            ? 'FMS Connected'
            : 'FMS Disconnected';
        String dsDisplayString = (dsAttached)
            ? 'DriverStation Connected'
            : 'DriverStation Disconnected';

        Icon fmsDisplayIcon = (fmsConnected)
            ? const Icon(Icons.check, color: Colors.green, size: 18)
            : const Icon(Icons.clear, color: Colors.red, size: 18);
        Icon dsDisplayIcon = (dsAttached)
            ? const Icon(Icons.check, color: Colors.green, size: 18)
            : const Icon(Icons.clear, color: Colors.red, size: 18);

        String robotStateDisplayString = 'Robot State: $robotControlState';

        late Widget robotStateWidget;
        if (emergencyStopped) {
          robotStateWidget = Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                flex: 25,
                child: CustomPaint(
                  size: const Size(80, 15),
                  painter: _BlackAndYellowStripes(),
                ),
              ),
              const Spacer(),
              const Text(
                'EMERGENCY STOPPED',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Expanded(
                flex: 25,
                child: CustomPaint(
                  size: const Size(80, 15),
                  painter: _BlackAndYellowStripes(),
                ),
              ),
            ],
          );
        } else {
          robotStateWidget = Text(robotStateDisplayString);
        }

        return Column(
          children: [
            matchDisplayWidget,
            const Spacer(flex: 2),
            // DS and FMS connected
            Row(
              children: [
                const Spacer(),
                Row(
                  children: [
                    fmsDisplayIcon,
                    const SizedBox(width: 5),
                    Text(fmsDisplayString),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    dsDisplayIcon,
                    const SizedBox(width: 5),
                    Text(dsDisplayString),
                  ],
                ),
                const Spacer(),
              ],
            ),
            const Spacer(),
            // Robot State
            robotStateWidget,
          ],
        );
      },
    );
  }
}

class _BlackAndYellowStripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);

    const DiagonalStripesThick(
      bgColor: Colors.black,
      fgColor: Colors.yellow,
      featuresCount: 10,
    ).paintOnRect(canvas, size, rect);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

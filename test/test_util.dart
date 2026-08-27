import 'dart:io';

import 'package:flutter/material.dart';

import 'package:http/http.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:elastic_dashboard/services/nt3_client.dart';
import 'package:elastic_dashboard/services/nt3_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/update_checker.dart';
import 'test_util.mocks.dart';

@GenerateNiceMocks([
  MockSpec<NTConnection>(),
  MockSpec<NT3Client>(),
  MockSpec<NT3Subscription>(),
])
MockNTConnection createMockOfflineNT3() {
  HttpOverrides.global = null;

  final mockNT3Connection = MockNTConnection();
  final mockSubscription = MockNT3Subscription();

  when(mockNT3Connection.announcedTopics()).thenReturn({});

  when(mockSubscription.periodicStream()).thenAnswer((_) => Stream.value(null));

  when(mockSubscription.listen(any)).thenAnswer((invocation) {});

  when(mockNT3Connection.ntConnected).thenReturn(ValueNotifier(false));
  when(mockNT3Connection.isNT3Connected).thenReturn(false);

  when(mockNT3Connection.serverTime).thenReturn(0);

  when(
    mockNT3Connection.connectionStatus(),
  ).thenAnswer((_) => Stream.value(false));

  when(mockNT3Connection.dsConnected).thenReturn(ValueNotifier(false));
  when(mockNT3Connection.isDSConnected).thenReturn(false);
  when(mockNT3Connection.dsHeight).thenReturn(ValueNotifier(null));
  when(mockNT3Connection.dsIpAddress).thenReturn(ValueNotifier(null));

  when(mockNT3Connection.latencyStream()).thenAnswer((_) => Stream.value(0));

  when(mockNT3Connection.getLastAnnouncedValue(any)).thenReturn(null);

  when(
    mockNT3Connection.subscribeWithOptions(any, any),
  ).thenReturn(mockSubscription);

  when(mockNT3Connection.subscribe(any, any)).thenReturn(mockSubscription);

  when(mockNT3Connection.subscribe(any)).thenReturn(mockSubscription);

  when(mockNT3Connection.subscribeAll(any, any)).thenReturn(mockSubscription);

  when(mockNT3Connection.getTopicFromName(any)).thenReturn(null);

  return mockNT3Connection;
}

MockNTConnection createMockOnlineNT3({
  List<NT3Topic>? virtualTopics,
  Map<String, dynamic>? virtualValues,
  int serverTime = 0,
}) {
  HttpOverrides.global = null;

  final mockNT3Connection = MockNTConnection();
  final mockSubscription = MockNT3Subscription();

  virtualTopics ??= [
    NT3Topic(
      name: '/SmartDashboard/Test Value 1',
      type: NT3Type.double(),
      properties: {},
    ),
    NT3Topic(
      name: '/SmartDashboard/Test Value 2',
      type: NT3Type.double(),
      properties: {},
    ),
  ];

  virtualValues ??= {};

  Map<int, NT3Topic> virtualTopicsMap = {};

  for (int i = 0; i < virtualTopics.length; i++) {
    virtualTopicsMap.addAll({i + 1: virtualTopics[i]});
  }

  List<NT3Topic> publishedTopics = [];

  when(mockNT3Connection.announcedTopics()).thenReturn(virtualTopicsMap);

  when(mockNT3Connection.addTopicAnnounceListener(any)).thenAnswer((
    invocation,
  ) {
    for (NT3Topic topic in virtualTopics!) {
      invocation.positionalArguments[0].call(topic);
    }
  });

  when(mockSubscription.periodicStream()).thenAnswer((_) => Stream.value(null));

  when(mockSubscription.listen(any)).thenAnswer((_) {});

  when(mockNT3Connection.ntConnected).thenReturn(ValueNotifier(true));
  when(mockNT3Connection.isNT3Connected).thenReturn(true);

  when(mockNT3Connection.serverTime).thenReturn(serverTime);

  when(
    mockNT3Connection.connectionStatus(),
  ).thenAnswer((_) => Stream.value(true));

  when(mockNT3Connection.dsConnected).thenReturn(ValueNotifier(true));
  when(mockNT3Connection.isDSConnected).thenReturn(true);
  when(mockNT3Connection.dsHeight).thenReturn(ValueNotifier(null));
  when(mockNT3Connection.dsIpAddress).thenReturn(ValueNotifier(null));

  when(mockNT3Connection.latencyStream()).thenAnswer((_) => Stream.value(0));

  when(mockNT3Connection.getLastAnnouncedValue(any)).thenReturn(null);

  when(
    mockNT3Connection.subscribeWithOptions(any, any),
  ).thenReturn(mockSubscription);

  when(mockNT3Connection.subscribe(any, any)).thenReturn(mockSubscription);

  when(mockNT3Connection.subscribe(any)).thenReturn(mockSubscription);

  when(mockNT3Connection.subscribeAll(any, any)).thenReturn(mockSubscription);

  when(mockNT3Connection.getTopicFromName(any)).thenReturn(null);

  when(
    mockNT3Connection.publishNewTopic(
      any,
      any,
      properties: anyNamed('properties'),
    ),
  ).thenAnswer((invocation) {
    NT3Topic newTopic = NT3Topic(
      name: invocation.positionalArguments[0],
      type: invocation.positionalArguments[1],
      properties: invocation.positionalArguments.length >= 3
          ? invocation.positionalArguments[2]
          : {},
    );

    virtualTopicsMap[virtualTopicsMap.length] = newTopic;
    publishedTopics.add(newTopic);
    return newTopic;
  });

  when(mockNT3Connection.publishTopic(any)).thenAnswer((invocation) {
    publishedTopics.add(invocation.positionalArguments[0]);
  });

  when(mockNT3Connection.unpublishTopic(any)).thenAnswer((invocation) {
    publishedTopics.remove(invocation.positionalArguments[0]);
  });

  when(mockNT3Connection.isTopicPublished(any)).thenAnswer(
    (invocation) => publishedTopics.contains(invocation.positionalArguments[0]),
  );

  when(mockNT3Connection.updateDataFromTopic(any, any)).thenAnswer((
    invocation,
  ) {
    NT3Topic topic = invocation.positionalArguments[0];
    Object? data = invocation.positionalArguments[1];

    virtualValues![topic.name] = data;
  });

  when(mockNT3Connection.updateDataFromTopicName(any, any)).thenAnswer((
    invocation,
  ) {
    String topic = invocation.positionalArguments[0];
    Object? data = invocation.positionalArguments[1];

    virtualValues![topic] = data;
  });

  for (NT3Topic topic in virtualTopics) {
    List<Function(Object?, int)> subscriptionListeners = [];
    List<void Function()> subscriptionNotifiers = [];

    MockNT3Subscription topicSubscription = MockNT3Subscription();

    when(topicSubscription.topic).thenReturn(topic.name);

    when(topicSubscription.value).thenAnswer((_) => virtualValues![topic.name]);

    when(topicSubscription.value = any).thenAnswer((invocation) {
      virtualValues![topic.name] = invocation.positionalArguments[0];
      for (var notifier in subscriptionNotifiers) {
        notifier.call();
      }
    });

    when(topicSubscription.addListener(any)).thenAnswer((invocation) {
      subscriptionNotifiers.add(invocation.positionalArguments[0]);
    });

    when(topicSubscription.removeListener(any)).thenAnswer((invocation) {
      subscriptionNotifiers.remove(invocation.positionalArguments[0]);
    });

    when(mockNT3Connection.updateDataFromTopic(topic, any)).thenAnswer((
      invocation,
    ) {
      virtualValues![topic.name] = invocation.positionalArguments[1];
      topicSubscription.updateValue(invocation.positionalArguments[1], 0);
    });

    when(mockNT3Connection.updateDataFromTopicName(topic.name, any)).thenAnswer(
      (invocation) {
        virtualValues![topic.name] = invocation.positionalArguments[1];
        topicSubscription.updateValue(invocation.positionalArguments[1], 0);
      },
    );

    when(
      mockNT3Connection.updateDataFromSubscription(topicSubscription, any),
    ).thenAnswer((invocation) {
      virtualValues![topic.name] = invocation.positionalArguments[1];
      topicSubscription.updateValue(invocation.positionalArguments[1], 0);
    });

    when(mockNT3Connection.getTopicFromName(topic.name)).thenReturn(topic);

    when(
      topicSubscription.periodicStream(yieldAll: anyNamed('yieldAll')),
    ).thenAnswer((_) => Stream.value(virtualValues![topic.name]));

    when(topicSubscription.listen(any)).thenAnswer((invocation) {
      subscriptionListeners.add(invocation.positionalArguments[0]);
    });

    when(topicSubscription.updateValue(any, any)).thenAnswer((invocation) {
      virtualValues![topic.name] = invocation.positionalArguments[0];
      for (var value in subscriptionListeners) {
        value.call(
          invocation.positionalArguments[0],
          invocation.positionalArguments[1],
        );
      }
      topicSubscription.value = invocation.positionalArguments[0];
    });

    when(
      mockNT3Connection.getLastAnnouncedValue(topic.name),
    ).thenAnswer((_) => virtualValues![topic.name]);

    when(
      mockNT3Connection.subscribeWithOptions(topic.name, any),
    ).thenAnswer((_) => topicSubscription);

    when(
      mockNT3Connection.subscribe(topic.name, any),
    ).thenAnswer((_) => topicSubscription);

    when(
      mockNT3Connection.subscribeAll(topic.name, any),
    ).thenAnswer((_) => topicSubscription);
  }

  return mockNT3Connection;
}

@GenerateNiceMocks([MockSpec<UpdateChecker>()])
MockUpdateChecker createMockUpdateChecker({
  bool updateAvailable = false,
  String latestVersion = '0.0.0.0',
}) {
  MockUpdateChecker updateChecker = MockUpdateChecker();

  when(updateChecker.isUpdateAvailable()).thenAnswer(
    (_) => Future.value(
      UpdateCheckerResponse(
        updateAvailable: updateAvailable,
        error: false,
        latestVersion: latestVersion,
      ),
    ),
  );

  return updateChecker;
}

@GenerateNiceMocks([MockSpec<Client>()])
MockClient createHttpClient({Map<String, Response>? mockGetResponses}) {
  MockClient mockClient = MockClient();

  if (mockGetResponses != null) {
    for (MapEntry<String, Response> mockRequest in mockGetResponses.entries) {
      when(
        mockClient.get(Uri.parse(mockRequest.key)),
      ).thenAnswer((_) => Future.value(mockRequest.value));
    }
  }
  return mockClient;
}

void ignoreOverflowErrors(
  FlutterErrorDetails details, {
  bool forceReport = false,
}) {
  // ---

  bool ifIsOverflowError = false;
  bool isUnableToLoadAsset = false;

  // Detect overflow error.
  var exception = details.exception;
  if (exception is FlutterError) {
    ifIsOverflowError = !exception.diagnostics.any(
      (e) => e.value.toString().startsWith('A RenderFlex overflowed by'),
    );
    isUnableToLoadAsset = !exception.diagnostics.any(
      (e) => e.value.toString().startsWith('Unable to load asset'),
    );
  }

  // Ignore if is overflow error.
  if (ifIsOverflowError || isUnableToLoadAsset) {
    return;
  } else {
    FlutterError.dumpErrorToConsole(details, forceReport: forceReport);
    // exit(1);
  }
}

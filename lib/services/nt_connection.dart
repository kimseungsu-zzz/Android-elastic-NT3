import 'package:flutter/foundation.dart';

import 'package:elastic_dashboard/services/ds_interop.dart';
import 'package:elastic_dashboard/services/nt3_client.dart';
import 'package:elastic_dashboard/services/nt3_type.dart';
import 'package:elastic_dashboard/services/settings.dart';

typedef SubscriptionIdentification = ({
  String topic,
  NT3SubscriptionOptions options,
});

enum NTServerTarget {
  robotCode('NetworkTables 3', NT3Client.defaultPort);

  const NTServerTarget(this.name, this.port);

  final String name;
  final int port;

  static NTServerTarget? fromIndex(int? index) {
    if (index == null || index < 0 || index >= values.length) {
      return null;
    }
    return values.firstWhere((e) => e.index == index);
  }
}

class NTConnection {
  late NT3Client _ntClient;
  late DSInteropClient _dsClient;

  NTServerTarget serverMode;
  List<VoidCallback> onConnectedListeners = [];
  List<VoidCallback> onDisconnectedListeners = [];

  final ValueNotifier<bool> _ntConnected = ValueNotifier(false);
  ValueNotifier<bool> get ntConnected => _ntConnected;

  bool get isNT3Connected => _ntConnected.value;

  bool get isDSConnected => _dsClient.connectionStatus.value;

  ValueNotifier<bool> get dsConnected => _dsClient.connectionStatus;
  ValueNotifier<int?> get dsHeight => _dsClient.dsHeightNotifier;
  ValueNotifier<String?> get dsIpAddress => _dsClient.ipNotifier;

  int get serverTime => _ntClient.getServerTimeUS();

  @visibleForTesting
  List<NT3Subscription> get subscriptions => subscriptionUseCount.keys.toList();

  @visibleForTesting
  String get serverBaseAddress => _ntClient.serverBaseAddress;

  Map<int, NT3Subscription> subscriptionMap = {};
  Map<NT3Subscription, int> subscriptionUseCount = {};

  NTConnection(String ipAddress, [this.serverMode = Defaults.targetServer]) {
    nt3Connect(ipAddress);
  }

  void nt3Connect(String ipAddress) {
    _ntClient = NT3Client(
      serverBaseAddress: ipAddress,
      serverPort: serverMode.port,
      onConnect: () {
        _ntConnected.value = true;

        for (VoidCallback callback in onConnectedListeners) {
          callback.call();
        }
      },
      onDisconnect: () {
        _ntConnected.value = false;

        for (VoidCallback callback in onDisconnectedListeners) {
          callback.call();
        }
      },
    );
  }

  void dsClientConnect() {
    _dsClient = DSInteropClient();
  }

  void addConnectedListener(VoidCallback callback) {
    onConnectedListeners.add(callback);
  }

  void removeConnectedListener(VoidCallback callback) {
    onConnectedListeners.remove(callback);
  }

  void addDisconnectedListener(VoidCallback callback) {
    onDisconnectedListeners.add(callback);
  }

  void removeDisconnectedListener(VoidCallback callback) {
    onDisconnectedListeners.remove(callback);
  }

  void addTopicAnnounceListener(Function(NT3Topic topic) onAnnounce) {
    _ntClient.addTopicAnnounceListener(onAnnounce);
  }

  void removeTopicAnnounceListener(Function(NT3Topic topic) onAnnounce) {
    _ntClient.removeTopicAnnounceListener(onAnnounce);
  }

  void addTopicUnannounceListener(Function(NT3Topic topic) onUnannounce) {
    _ntClient.addTopicUnannounceListener(onUnannounce);
  }

  void removeTopicUnannounceListener(Function(NT3Topic topic) onUnannounce) {
    _ntClient.removeTopicUnannounceListener(onUnannounce);
  }

  Future<T?>? subscribeAndRetrieveData<T>(
    String topic, {
    period = 0.1,
    timeout = const Duration(seconds: 2, milliseconds: 500),
  }) async {
    NT3Subscription subscription = subscribe(topic, period);

    T? value;
    try {
      value =
          await subscription
                  .periodicStream()
                  .firstWhere((element) => element != null && element is T)
                  .timeout(timeout)
              as T?;
    } catch (e) {
      value = null;
    }

    unSubscribe(subscription);

    return value;
  }

  Stream<bool> connectionStatus() async* {
    yield _ntConnected.value;
    bool lastYielded = _ntConnected.value;

    while (true) {
      if (_ntConnected.value != lastYielded) {
        yield _ntConnected.value;
        lastYielded = _ntConnected.value;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Map<int, NT3Topic> announcedTopics() => _ntClient.announcedTopics;

  Stream<double> latencyStream() => _ntClient.latencyStream();

  void changeIPAddress(String ipAddress) {
    if (_ntClient.serverBaseAddress == ipAddress) {
      return;
    }

    _ntClient.setServerBaseAddreess(ipAddress);
  }

  void changeServerMode(NTServerTarget mode) {
    if (serverMode == mode) {
      return;
    }
    serverMode = mode;
    _ntClient.setServerPort(mode.port);
  }

  NT3Subscription subscribe(String topic, [double period = 0.1]) =>
      subscribeWithOptions(
        topic,
        NT3SubscriptionOptions(periodicRateSeconds: period),
      );

  NT3Subscription subscribeWithOptions(
    String topic,
    NT3SubscriptionOptions options,
  ) {
    int hashCode = Object.hash(topic, options);

    if (subscriptionMap.containsKey(hashCode)) {
      NT3Subscription existingSubscription = subscriptionMap[hashCode]!;
      subscriptionUseCount.update(existingSubscription, (value) => value + 1);

      return existingSubscription;
    }

    NT3Subscription newSubscription = _ntClient.subscribe(
      topic: topic,
      options: options,
    );

    subscriptionMap[hashCode] = newSubscription;
    subscriptionUseCount[newSubscription] = 1;

    return newSubscription;
  }

  NT3Subscription subscribeAll(String topic, [double period = 0.1]) =>
      subscribeWithOptions(
        topic,
        NT3SubscriptionOptions(periodicRateSeconds: period, all: true),
      );

  void unSubscribe(NT3Subscription subscription) {
    if (!subscriptionUseCount.containsKey(subscription)) {
      _ntClient.unSubscribe(subscription);
      return;
    }

    int hashCode = Object.hash(subscription.topic, subscription.options);

    subscriptionUseCount.update(subscription, (value) => value - 1);

    if (subscriptionUseCount[subscription]! <= 0) {
      subscriptionMap.remove(hashCode);
      subscriptionUseCount.remove(subscription);
      _ntClient.unSubscribe(subscription);
    }
  }

  NT3Topic? getTopicFromSubscription(NT3Subscription subscription) =>
      _ntClient.getTopicFromName(subscription.topic);

  NT3Topic? getTopicFromName(String topic) => _ntClient.getTopicFromName(topic);

  void publishTopic(NT3Topic topic) {
    _ntClient.publishTopic(topic);
  }

  NT3Topic publishNewTopic(
    String name,
    NT3Type type, {
    Map<String, dynamic> properties = const {},
  }) => _ntClient.publishNewTopic(name, type, properties);

  bool isTopicPublished(NT3Topic? topic) => _ntClient.isTopicPublished(topic);

  Object? getLastAnnouncedValue(String topic) =>
      _ntClient.lastAnnouncedValues[topic];

  void unpublishTopic(NT3Topic topic) {
    _ntClient.unpublishTopic(topic);
  }

  void updateDataFromSubscription(
    NT3Subscription subscription,
    dynamic data, [
    int? timestamp,
  ]) {
    _ntClient.addSampleFromName(subscription.topic, data, timestamp);
  }

  void updateDataFromTopic(NT3Topic topic, dynamic data, [int? timestamp]) {
    _ntClient.addSample(topic, data, timestamp);
  }

  @visibleForTesting
  void updateDataFromTopicName(String topic, dynamic data, [int? timestamp]) {
    _ntClient.addSampleFromName(topic, data, timestamp);
  }
}

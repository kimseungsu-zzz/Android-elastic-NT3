import 'package:flutter_test/flutter_test.dart';

import 'package:elastic_dashboard/services/nt3_client.dart';
import 'package:elastic_dashboard/services/nt3_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';

void main() {
  test('NT3 connection shares identical local subscriptions', () {
    final connection = NTConnection('127.0.0.1');
    final first = connection.subscribe('/SmartDashboard/Test');
    final second = connection.subscribe('/SmartDashboard/Test');

    expect(connection.isNT3Connected, false);
    expect(connection.subscriptions, hasLength(1));

    connection.unSubscribe(first);
    expect(connection.subscriptions, hasLength(1));
    connection.unSubscribe(second);
    expect(connection.subscriptions, isEmpty);
  });

  test('NT3 subscription tracks values and timestamps', () {
    final subscription = NT3Subscription(topic: '/Test');
    subscription.updateValue(3.5, 1234);

    expect(subscription.value, 3.5);
    expect(subscription.currentValue, 3.5);
    expect(subscription.timestamp, 1234);
  });

  test('NT3 topic defaults to an unassigned entry id', () {
    final topic = NT3Topic(
      name: '/Test',
      type: NT3Type.double(),
      properties: {},
    );
    expect(topic.id, -1);
  });
}

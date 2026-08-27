import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:elastic_dashboard/services/nt3_client.dart';

void main() {
  test('performs the NT3 handshake and exchanges entry values', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = server.first;
    final connected = Completer<void>();
    final client = NT3Client(
      serverBaseAddress: InternetAddress.loopbackIPv4.address,
      serverPort: server.port,
      onConnect: connected.complete,
    );

    final socket = await accepted.timeout(const Duration(seconds: 3));
    final capture = _SocketCapture(socket);

    final hello = await capture.takeMessage().timeout(
      const Duration(seconds: 3),
    );
    expect(hello[0], 0x01);
    expect((hello[1] << 8) | hello[2], 0x0300);
    expect(utf8.decode(hello.sublist(4)), 'Elastic (NT3)');

    final assignment = BytesBuilder()
      ..addByte(0x04)
      ..addByte(0x00)
      ..add(_string('test-server'))
      ..addByte(0x10)
      ..add(_string('/Test'))
      ..addByte(0x01)
      ..add([0x00, 0x2a, 0x00, 0x07, 0x00])
      ..add(_double(2.5))
      ..addByte(0x03);
    final bytes = assignment.toBytes();
    socket.add(bytes.sublist(0, 5));
    await socket.flush();
    socket.add(bytes.sublist(5));
    await socket.flush();

    await connected.future.timeout(const Duration(seconds: 3));
    final topic = client.announcedTopics[0x2a];
    expect(topic?.name, '/Test');
    expect(client.lastAnnouncedValues['/Test'], 2.5);

    final subscription = client.subscribe(topic: '/Test');
    expect(subscription.value, 2.5);

    client.publishTopic(topic!);
    client.addSample(topic, 4.5);
    final outgoing = await capture.takeUntilEntryUpdate().timeout(
      const Duration(seconds: 3),
    );
    expect(outgoing.sublist(0, 6), [0x11, 0x00, 0x2a, 0x00, 0x08, 0x01]);
    expect(
      ByteData.sublistView(
        Uint8List.fromList(outgoing.sublist(6)),
      ).getFloat64(0, Endian.big),
      4.5,
    );

    await client.dispose();
    await socket.close();
    await server.close();
  });
}

Uint8List _string(String value) {
  final bytes = utf8.encode(value);
  return Uint8List.fromList([bytes.length, ...bytes]);
}

Uint8List _double(double value) {
  final data = ByteData(8)..setFloat64(0, value, Endian.big);
  return data.buffer.asUint8List();
}

class _SocketCapture {
  final List<int> _bytes = [];
  final List<Completer<void>> _waiters = [];

  _SocketCapture(Socket socket) {
    socket.listen((data) {
      _bytes.addAll(data);
      for (final waiter in _waiters.toList()) {
        if (!waiter.isCompleted) waiter.complete();
      }
      _waiters.clear();
    });
  }

  Future<void> _waitForData() async {
    if (_bytes.isNotEmpty) return;
    final waiter = Completer<void>();
    _waiters.add(waiter);
    await waiter.future;
  }

  Future<List<int>> takeMessage() async {
    while (_bytes.length < 4) {
      await _waitForData();
    }
    final length = 4 + _bytes[3];
    while (_bytes.length < length) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    final result = _bytes.take(length).toList();
    _bytes.removeRange(0, length);
    return result;
  }

  Future<List<int>> takeUntilEntryUpdate() async {
    while (true) {
      final index = _bytes.indexOf(0x11);
      if (index >= 0 && _bytes.length >= index + 14) {
        final result = _bytes.sublist(index, index + 14);
        _bytes.removeRange(0, index + 14);
        return result;
      }
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
  }
}

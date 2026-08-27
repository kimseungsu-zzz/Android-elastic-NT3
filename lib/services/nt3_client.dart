import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:collection/collection.dart';

import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/nt3_type.dart';

class NT3Subscription extends ValueNotifier<Object?> {
  final String topic;
  final NT3SubscriptionOptions options;
  final int uid;

  Object? currentValue;
  int timestamp = 0;
  final List<Function(Object?, int)> _listeners = [];

  NT3Subscription({
    required this.topic,
    this.options = const NT3SubscriptionOptions(),
    this.uid = -1,
  }) : super(null);

  void listen(Function(Object?, int) onChanged) {
    _listeners.add(onChanged);
    onChanged(value, timestamp);
  }

  Stream<Object?> periodicStream({bool yieldAll = true}) async* {
    final delay = Duration(
      microseconds: (options.periodicRateSeconds * 1e6).round(),
    );
    yield currentValue;
    Object? lastYielded = currentValue;
    while (true) {
      await Future.delayed(delay);
      if (yieldAll || lastYielded != currentValue) {
        yield currentValue;
        lastYielded = currentValue;
      }
    }
  }

  Stream<({Object? value, DateTime timestamp})> timestampedStream({
    bool yieldAll = false,
  }) async* {
    int lastTimestamp = -1;
    while (true) {
      if (yieldAll || lastTimestamp != timestamp) {
        yield (
          value: currentValue,
          timestamp: DateTime.fromMicrosecondsSinceEpoch(timestamp),
        );
        lastTimestamp = timestamp;
      }
      await Future.delayed(
        Duration(microseconds: (options.periodicRateSeconds * 1e6).round()),
      );
    }
  }

  void updateValue(Object? newValue, int newTimestamp) {
    currentValue = newValue;
    timestamp = newTimestamp;
    for (final listener in _listeners) {
      listener(newValue, newTimestamp);
    }
    super.value = newValue;
  }

  @override
  bool operator ==(Object other) =>
      other is NT3Subscription &&
      other.topic == topic &&
      other.options == options;

  @override
  int get hashCode => Object.hash(topic, options);
}

/// Subscription options retained for the dashboard API. NT3 broadcasts all
/// entries; filtering and update periods are therefore handled locally.
class NT3SubscriptionOptions {
  final double periodicRateSeconds;
  final bool all;
  final bool topicsOnly;
  final bool prefix;

  const NT3SubscriptionOptions({
    this.periodicRateSeconds = 0.1,
    this.all = false,
    this.topicsOnly = false,
    this.prefix = true,
  });

  @override
  bool operator ==(Object other) =>
      other is NT3SubscriptionOptions &&
      other.periodicRateSeconds == periodicRateSeconds &&
      other.all == all &&
      other.topicsOnly == topicsOnly &&
      other.prefix == prefix;

  @override
  int get hashCode => Object.hash(periodicRateSeconds, all, topicsOnly, prefix);
}

class NT3Topic {
  final String name;
  NT3Type type;
  int id;
  int sequenceNumber;
  final Map<String, dynamic> properties;

  NT3Topic({
    required this.name,
    required this.type,
    this.id = -1,
    this.sequenceNumber = 0,
    required this.properties,
  });

  int getTypeId() => type.typeId;
  bool get isPersistent => properties['persistent'] == true;

  @override
  String toString() =>
      'NT3Topic(Name: $name, Type: $type, ID: $id, Sequence: $sequenceNumber)';
}

/// A client implementation of the WPILib NetworkTables 3.0 TCP protocol.
class NT3Client {
  static const int defaultPort = 1735;
  static const int _protocolRevision = 0x0300;

  String serverBaseAddress;
  int serverPort;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  final List<Function(NT3Topic)> _topicAnnounceListeners = [];
  final List<Function(NT3Topic)> _topicUnannounceListeners = [];
  final Map<int, NT3Subscription> _subscriptions = {};
  final Set<NT3Subscription> _subscribedTopics = {};
  final Map<String, NT3Topic> _clientPublishedTopics = {};
  final Map<String, Object?> _pendingValues = {};
  final Map<int, NT3Topic> announcedTopics = {};
  final Map<String, Object?> lastAnnouncedValues = {};
  final Map<String, int> lastAnnouncedTimestamps = {};

  Socket? _socket;
  StreamSubscription<Uint8List>? _socketListener;
  Timer? _connectionTimer;
  Timer? _keepAliveTimer;
  final List<int> _receiveBuffer = [];
  bool _attemptingConnection = false;
  bool _connected = false;
  int _subscriptionUIDCounter = 0;

  NT3Client({
    required this.serverBaseAddress,
    this.serverPort = defaultPort,
    this.onConnect,
    this.onDisconnect,
  }) {
    Future<void>.delayed(const Duration(milliseconds: 250), _connect);
    _connectionTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _connect(),
    );
  }

  Map<int, NT3Subscription> get subscriptions => _subscriptions;
  Set<NT3Subscription> get subscribedTopics => _subscribedTopics;
  List<Function(NT3Topic)> get topicAnnounceListeners =>
      _topicAnnounceListeners;

  @visibleForTesting
  void cancelConnectionTimer() => _connectionTimer?.cancel();

  Future<void> dispose() async {
    _connectionTimer?.cancel();
    _connectionTimer = null;
    await _close();
  }

  Future<void> setServerBaseAddreess(String address) async {
    if (address == serverBaseAddress) return;
    serverBaseAddress = address;
    await _close();
    unawaited(_connect());
  }

  Future<void> setServerPort(int port) async {
    if (port == serverPort) return;
    serverPort = port;
    await _close();
    unawaited(_connect());
  }

  Stream<double> latencyStream() async* {
    // NT3 has no time-sync/RTT channel. Keep the footer API stable.
    yield 0;
  }

  int getServerTimeUS() => DateTime.now().microsecondsSinceEpoch;

  void addTopicAnnounceListener(Function(NT3Topic) listener) {
    _topicAnnounceListeners.add(listener);
    for (final topic in announcedTopics.values) {
      listener(topic);
    }
  }

  void removeTopicAnnounceListener(Function(NT3Topic) listener) =>
      _topicAnnounceListeners.remove(listener);

  void addTopicUnannounceListener(Function(NT3Topic) listener) =>
      _topicUnannounceListeners.add(listener);

  void removeTopicUnannounceListener(Function(NT3Topic) listener) =>
      _topicUnannounceListeners.remove(listener);

  NT3Subscription subscribe({
    required String topic,
    NT3SubscriptionOptions options = const NT3SubscriptionOptions(),
  }) {
    final subscription = NT3Subscription(
      topic: topic,
      options: options,
      uid: _subscriptionUIDCounter++,
    );
    _subscriptions[subscription.uid] = subscription;
    _subscribedTopics.add(subscription);
    if (lastAnnouncedValues.containsKey(topic)) {
      subscription.updateValue(
        lastAnnouncedValues[topic],
        lastAnnouncedTimestamps[topic] ?? getServerTimeUS(),
      );
    }
    return subscription;
  }

  void unSubscribe(NT3Subscription subscription) {
    _subscriptions.remove(subscription.uid);
    _subscribedTopics.remove(subscription);
  }

  void clearAllSubscriptions() {
    _subscriptions.clear();
    _subscribedTopics.clear();
  }

  NT3Topic? getTopicFromName(String name) =>
      announcedTopics.values.firstWhereOrNull((topic) => topic.name == name) ??
      _clientPublishedTopics[name];

  bool isTopicPublished(NT3Topic? topic) =>
      topic != null && _clientPublishedTopics[topic.name] == topic;

  NT3Topic publishNewTopic(
    String name,
    NT3Type type, [
    Map<String, dynamic> properties = const {},
  ]) {
    final topic = NT3Topic(
      name: name,
      type: _normalizeType(type),
      properties: Map<String, dynamic>.from(properties),
    );
    publishTopic(topic);
    return topic;
  }

  void publishTopic(NT3Topic topic) {
    final existing = getTopicFromName(topic.name);
    if (existing != null && existing.id >= 0) {
      topic.id = existing.id;
      topic.sequenceNumber = existing.sequenceNumber;
      topic.type = existing.type;
    }
    _clientPublishedTopics[topic.name] = topic;
    if (topic.id >= 0) _sendFlags(topic);
  }

  /// NT3 has no publisher lifetime. This only releases local ownership; it
  /// intentionally does not delete the shared entry from the server.
  void unpublishTopic(NT3Topic topic) {
    _clientPublishedTopics.remove(topic.name);
    _pendingValues.remove(topic.name);
  }

  void setProperties(NT3Topic topic, bool persistent, bool retained) {
    topic.properties['persistent'] = persistent;
    _sendFlags(topic);
  }

  void addSample(NT3Topic topic, dynamic data, [int? timestamp]) {
    final Object value = _normalizeValue(topic.type, data);
    _clientPublishedTopics[topic.name] = topic;

    if (topic.id < 0) {
      _pendingValues[topic.name] = value;
      _sendEntryAssignment(topic, value);
    } else {
      topic.sequenceNumber = (topic.sequenceNumber + 1) & 0xffff;
      final writer = _NT3Writer()
        ..write8(0x11)
        ..write16(topic.id)
        ..write16(topic.sequenceNumber)
        ..write8(topic.type.typeId)
        ..writeValue(topic.type, value);
      _send(writer.bytes);
    }
    _updateLocalValue(topic, value, timestamp ?? getServerTimeUS());
  }

  void addSampleFromName(String name, dynamic data, [int? timestamp]) {
    final topic = getTopicFromName(name);
    if (topic == null) {
      logger.debug('[NT3] Entry not found: $name');
      return;
    }
    addSample(topic, data, timestamp);
  }

  Future<void> _connect() async {
    if (kIsWeb || _connected || _attemptingConnection || _socket != null) {
      return;
    }
    _attemptingConnection = true;
    try {
      final socket = await Socket.connect(
        serverBaseAddress,
        serverPort,
        timeout: const Duration(seconds: 1),
      );
      socket.setOption(SocketOption.tcpNoDelay, true);
      _socket = socket;
      _receiveBuffer.clear();
      _socketListener = socket.listen(
        _onData,
        onDone: _close,
        onError: (Object error, StackTrace stack) {
          logger.debug('[NT3] Socket error: $error');
          unawaited(_close());
        },
        cancelOnError: true,
      );

      final hello = _NT3Writer()
        ..write8(0x01)
        ..write16(_protocolRevision)
        ..writeString('Elastic (NT3)');
      _send(hello.bytes);
      logger.info(
        'Connecting to NetworkTables 3 at $serverBaseAddress:$serverPort',
      );
    } catch (error) {
      logger.trace('[NT3] Connection attempt failed: $error');
      await _close(notify: false);
    } finally {
      _attemptingConnection = false;
    }
  }

  void _onData(Uint8List data) {
    _receiveBuffer.addAll(data);
    int consumed = 0;
    while (consumed < _receiveBuffer.length) {
      final reader = _NT3Reader(_receiveBuffer, consumed);
      try {
        _readMessage(reader);
        consumed = reader.offset;
      } on _NeedMoreData {
        break;
      } catch (error, stack) {
        logger.warning('[NT3] Invalid server message', error, stack);
        unawaited(_close());
        return;
      }
    }
    if (consumed > 0) _receiveBuffer.removeRange(0, consumed);
  }

  void _readMessage(_NT3Reader reader) {
    final int messageType = reader.read8();
    switch (messageType) {
      case 0x00:
        return;
      case 0x02:
        final revision = reader.read16();
        throw StateError(
          'Server does not support NT3 (reported 0x${revision.toRadixString(16)})',
        );
      case 0x03:
        for (final topic in _clientPublishedTopics.values) {
          if (topic.id < 0) {
            final value = _pendingValues[topic.name];
            if (value != null) _sendEntryAssignment(topic, value);
          }
        }
        _send(Uint8List.fromList([0x05]));
        if (!_connected) {
          _connected = true;
          _keepAliveTimer?.cancel();
          _keepAliveTimer = Timer.periodic(
            const Duration(seconds: 1),
            (_) => _send(Uint8List.fromList([0x00])),
          );
          logger.info('NetworkTables 3 connected');
          onConnect?.call();
        }
        return;
      case 0x04:
        reader.read8();
        reader.readString();
        return;
      case 0x10:
        final name = reader.readString();
        final type = NT3Type.fromTypeId(reader.read8());
        if (type.dataType == NT3DataType.unknown) {
          throw FormatException('Unknown NT3 entry type');
        }
        final id = reader.read16();
        final sequence = reader.read16();
        final flags = reader.read8();
        final value = reader.readValue(type);
        _handleAssignment(name, type, id, sequence, flags, value);
        return;
      case 0x11:
        final id = reader.read16();
        final sequence = reader.read16();
        final wireType = NT3Type.fromTypeId(reader.read8());
        if (wireType.dataType == NT3DataType.unknown) {
          throw FormatException('Unknown NT3 update type');
        }
        final value = reader.readValue(wireType);
        final topic = announcedTopics[id];
        if (topic != null && topic.type == wireType) {
          topic.sequenceNumber = sequence;
          _updateLocalValue(topic, value, getServerTimeUS());
        }
        return;
      case 0x12:
        final topic = announcedTopics[reader.read16()];
        final flags = reader.read8();
        if (topic != null) topic.properties['persistent'] = flags & 1 != 0;
        return;
      case 0x13:
        final topic = announcedTopics.remove(reader.read16());
        if (topic != null) {
          lastAnnouncedValues.remove(topic.name);
          lastAnnouncedTimestamps.remove(topic.name);
          for (final listener in _topicUnannounceListeners) {
            listener(topic);
          }
        }
        return;
      case 0x14:
        if (reader.read32() != 0xd06cb27a) {
          throw const FormatException('Invalid NT3 clear-all magic');
        }
        final removed = announcedTopics.values.toList();
        announcedTopics.clear();
        lastAnnouncedValues.clear();
        lastAnnouncedTimestamps.clear();
        for (final topic in removed) {
          for (final listener in _topicUnannounceListeners) {
            listener(topic);
          }
        }
        return;
      case 0x20:
      case 0x21:
        reader.read16();
        reader.read16();
        reader.readBytes(reader.readUleb128());
        return;
      default:
        throw FormatException(
          'Unknown NT3 message 0x${messageType.toRadixString(16)}',
        );
    }
  }

  void _handleAssignment(
    String name,
    NT3Type type,
    int id,
    int sequence,
    int flags,
    Object value,
  ) {
    final localTopic = _clientPublishedTopics[name];
    final existing = announcedTopics[id];
    final topic =
        localTopic ??
        existing ??
        NT3Topic(name: name, type: type, properties: <String, dynamic>{});
    topic
      ..id = id
      ..sequenceNumber = sequence
      ..type = type
      ..properties['persistent'] = flags & 1 != 0;
    announcedTopics[id] = topic;
    _updateLocalValue(topic, value, getServerTimeUS());

    if (existing == null) {
      for (final listener in _topicAnnounceListeners) {
        listener(topic);
      }
    }

    final desired = _pendingValues.remove(name);
    if (desired != null &&
        !const DeepCollectionEquality().equals(desired, value)) {
      addSample(topic, desired);
    }
  }

  void _updateLocalValue(NT3Topic topic, Object value, int timestamp) {
    lastAnnouncedValues[topic.name] = value;
    lastAnnouncedTimestamps[topic.name] = timestamp;
    for (final subscription in _subscriptions.values) {
      if (subscription.topic == topic.name) {
        subscription.updateValue(value, timestamp);
      }
    }
  }

  void _sendEntryAssignment(NT3Topic topic, Object value) {
    final writer = _NT3Writer()
      ..write8(0x10)
      ..writeString(topic.name)
      ..write8(topic.type.typeId)
      ..write16(0xffff)
      ..write16(0)
      ..write8(topic.isPersistent ? 1 : 0)
      ..writeValue(topic.type, value);
    _send(writer.bytes);
  }

  void _sendFlags(NT3Topic topic) {
    if (topic.id < 0) return;
    final writer = _NT3Writer()
      ..write8(0x12)
      ..write16(topic.id)
      ..write8(topic.isPersistent ? 1 : 0);
    _send(writer.bytes);
  }

  void _send(Uint8List data) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.add(data);
    } catch (error) {
      logger.debug('[NT3] Send failed: $error');
      unawaited(_close());
    }
  }

  Future<void> _close({bool notify = true}) async {
    final wasConnected = _connected;
    _connected = false;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    final listener = _socketListener;
    final socket = _socket;
    _socketListener = null;
    _socket = null;
    if (listener != null) await listener.cancel();
    if (socket != null) await socket.close();

    final removed = announcedTopics.values.toList();
    announcedTopics.clear();
    lastAnnouncedValues.clear();
    lastAnnouncedTimestamps.clear();
    for (final topic in removed) {
      topic.id = -1;
      for (final callback in _topicUnannounceListeners) {
        callback(topic);
      }
    }
    if (notify && wasConnected) {
      logger.info('NetworkTables 3 disconnected');
      onDisconnect?.call();
    }
  }

  static NT3Type _normalizeType(NT3Type type) {
    if (type.dataType == NT3DataType.unknown) return NT3Type.string();
    return type;
  }

  static Object _normalizeValue(NT3Type type, dynamic value) {
    if (type.isArray) {
      final values = value is List ? value : const [];
      return switch (type.dataType) {
        NT3DataType.boolean => values.map((item) => item == true).toList(),
        NT3DataType.float64 =>
          values.whereType<num>().map((item) => item.toDouble()).toList(),
        NT3DataType.string => values.map((item) => item.toString()).toList(),
        _ => Uint8List(0),
      };
    }
    return switch (type.dataType) {
      NT3DataType.boolean => value == true,
      NT3DataType.float64 => value is num ? value.toDouble() : 0.0,
      NT3DataType.string => value.toString(),
      NT3DataType.raw || NT3DataType.rpc =>
        value is Uint8List
            ? value
            : Uint8List.fromList(value is List<int> ? value : const []),
      NT3DataType.unknown => value.toString(),
    };
  }
}

class _NeedMoreData implements Exception {
  const _NeedMoreData();
}

class _NT3Reader {
  final List<int> data;
  int offset;

  _NT3Reader(this.data, this.offset);

  void _require(int count) {
    if (offset + count > data.length) throw const _NeedMoreData();
  }

  int read8() {
    _require(1);
    return data[offset++];
  }

  int read16() => (read8() << 8) | read8();
  int read32() => (read16() << 16) | read16();

  int readUleb128() {
    int value = 0;
    int shift = 0;
    while (true) {
      final byte = read8();
      value |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) return value;
      shift += 7;
      if (shift > 35) throw const FormatException('Invalid ULEB128 value');
    }
  }

  Uint8List readBytes(int count) {
    _require(count);
    final result = Uint8List.fromList(data.sublist(offset, offset + count));
    offset += count;
    return result;
  }

  String readString() => utf8.decode(readBytes(readUleb128()));

  Object readValue(NT3Type type) {
    if (type.isArray) {
      final length = read8();
      return switch (type.dataType) {
        NT3DataType.boolean => List<bool>.generate(length, (_) => read8() != 0),
        NT3DataType.float64 => List<double>.generate(
          length,
          (_) => _readDouble(),
        ),
        NT3DataType.string => List<String>.generate(
          length,
          (_) => readString(),
        ),
        _ => throw const FormatException('Invalid NT3 array type'),
      };
    }
    return switch (type.dataType) {
      NT3DataType.boolean => read8() != 0,
      NT3DataType.float64 => _readDouble(),
      NT3DataType.string => readString(),
      NT3DataType.raw || NT3DataType.rpc => readBytes(readUleb128()),
      NT3DataType.unknown => throw const FormatException('Unknown NT3 type'),
    };
  }

  double _readDouble() {
    final bytes = readBytes(8);
    return ByteData.sublistView(bytes).getFloat64(0, Endian.big);
  }
}

class _NT3Writer {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  Uint8List get bytes => _builder.toBytes();

  void write8(int value) => _builder.addByte(value & 0xff);

  void write16(int value) {
    write8(value >> 8);
    write8(value);
  }

  void writeUleb128(int value) {
    do {
      int byte = value & 0x7f;
      value >>= 7;
      if (value != 0) byte |= 0x80;
      write8(byte);
    } while (value != 0);
  }

  void writeString(String value) {
    final encoded = utf8.encode(value);
    writeUleb128(encoded.length);
    _builder.add(encoded);
  }

  void writeValue(NT3Type type, Object value) {
    if (type.isArray) {
      final values = value as List;
      final length = values.length.clamp(0, 255);
      write8(length);
      for (int index = 0; index < length; index++) {
        switch (type.dataType) {
          case NT3DataType.boolean:
            write8(values[index] == true ? 1 : 0);
          case NT3DataType.float64:
            _writeDouble((values[index] as num).toDouble());
          case NT3DataType.string:
            writeString(values[index].toString());
          default:
            throw const FormatException('Invalid NT3 array type');
        }
      }
      return;
    }

    switch (type.dataType) {
      case NT3DataType.boolean:
        write8(value == true ? 1 : 0);
      case NT3DataType.float64:
        _writeDouble((value as num).toDouble());
      case NT3DataType.string:
        writeString(value.toString());
      case NT3DataType.raw:
      case NT3DataType.rpc:
        final bytes = value as Uint8List;
        writeUleb128(bytes.length);
        _builder.add(bytes);
      case NT3DataType.unknown:
        throw const FormatException('Unknown NT3 type');
    }
  }

  void _writeDouble(double value) {
    final bytes = ByteData(8)..setFloat64(0, value, Endian.big);
    _builder.add(bytes.buffer.asUint8List());
  }
}

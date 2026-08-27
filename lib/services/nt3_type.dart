import 'dart:convert';

import 'package:dot_cast/dot_cast.dart';

import 'package:elastic_dashboard/services/log.dart';

/// Data types supported by the NetworkTables 3.0 wire protocol.
enum NT3DataType {
  boolean,
  float64,
  string,
  raw,
  rpc,
  unknown;

  bool get isViewable => {
    NT3DataType.boolean,
    NT3DataType.float64,
    NT3DataType.string,
  }.contains(this);

  bool get isNumber => this == NT3DataType.float64;
  bool get isBinary => this == NT3DataType.raw || this == NT3DataType.rpc;
}

enum NT3TypeModifier { array, normal }

/// A NetworkTables 3 value type.
///
/// NT3 only has one numeric wire type (`double`).
class NT3Type {
  final NT3DataType dataType;
  final NT3TypeModifier modifier;
  final String name;

  const NT3Type({
    required this.dataType,
    required this.name,
    this.modifier = NT3TypeModifier.normal,
  });

  factory NT3Type.boolean() =>
      const NT3Type(dataType: NT3DataType.boolean, name: 'boolean');

  factory NT3Type.double() =>
      const NT3Type(dataType: NT3DataType.float64, name: 'double');

  factory NT3Type.string() =>
      const NT3Type(dataType: NT3DataType.string, name: 'string');

  factory NT3Type.raw() =>
      const NT3Type(dataType: NT3DataType.raw, name: 'raw');

  factory NT3Type.rpc() =>
      const NT3Type(dataType: NT3DataType.rpc, name: 'rpc');

  factory NT3Type.unknown(String type) =>
      NT3Type(dataType: NT3DataType.unknown, name: type);

  factory NT3Type.array(NT3Type subType) {
    if (subType.dataType.isBinary || subType.isArray) return subType;
    return NT3Type(
      dataType: subType.dataType,
      modifier: NT3TypeModifier.array,
      name: subType.name,
    );
  }

  static NT3Type? parseNullable(String? type) =>
      type == null ? null : parse(type);

  static NT3Type parse(String type) {
    final bool array = type.endsWith('[]');
    final String base = array ? type.substring(0, type.length - 2) : type;
    final NT3Type parsed = switch (base) {
      'boolean' => NT3Type.boolean(),
      'double' => NT3Type.double(),
      'string' || 'json' || 'enum' => NT3Type.string(),
      'raw' => NT3Type.raw(),
      'rpc' => NT3Type.rpc(),
      _ => NT3Type.unknown(type),
    };

    if (parsed.dataType == NT3DataType.unknown) {
      logger.debug('Unsupported NT3 type $type');
      return parsed;
    }
    return array ? NT3Type.array(parsed) : parsed;
  }

  dynamic convertString(String str) {
    if (!isViewable) return null;
    if (isArray) {
      final List<dynamic>? values = tryCast<List<dynamic>>(jsonDecode(str));
      return switch (dataType) {
        NT3DataType.boolean => values?.whereType<bool>().toList(),
        NT3DataType.float64 =>
          values?.whereType<num>().map((value) => value.toDouble()).toList(),
        NT3DataType.string => values?.whereType<String>().toList(),
        _ => null,
      };
    }

    return switch (dataType) {
      NT3DataType.boolean => bool.tryParse(str),
      NT3DataType.float64 => double.tryParse(str),
      NT3DataType.string => str,
      _ => null,
    };
  }

  bool get isArray => modifier == NT3TypeModifier.array;
  bool get isViewable => dataType.isViewable;

  String serialize() => isArray ? '$name[]' : name;

  int get typeId {
    if (isArray) {
      return switch (dataType) {
        NT3DataType.boolean => 0x10,
        NT3DataType.float64 => 0x11,
        NT3DataType.string => 0x12,
        _ => throw StateError('Unsupported NT3 array type: $this'),
      };
    }
    return switch (dataType) {
      NT3DataType.boolean => 0x00,
      NT3DataType.float64 => 0x01,
      NT3DataType.string => 0x02,
      NT3DataType.raw => 0x03,
      NT3DataType.rpc => 0x20,
      NT3DataType.unknown => throw StateError('Unsupported NT3 type: $this'),
    };
  }

  static NT3Type fromTypeId(int id) => switch (id) {
    0x00 => NT3Type.boolean(),
    0x01 => NT3Type.double(),
    0x02 => NT3Type.string(),
    0x03 => NT3Type.raw(),
    0x10 => NT3Type.array(NT3Type.boolean()),
    0x11 => NT3Type.array(NT3Type.double()),
    0x12 => NT3Type.array(NT3Type.string()),
    0x20 => NT3Type.rpc(),
    _ => NT3Type.unknown('0x${id.toRadixString(16)}'),
  };

  @override
  String toString() => 'NT3Type(${serialize()})';

  @override
  bool operator ==(Object other) =>
      other is NT3Type &&
      dataType == other.dataType &&
      modifier == other.modifier;

  @override
  int get hashCode => Object.hash(dataType, modifier);
}

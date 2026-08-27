import 'package:flutter_test/flutter_test.dart';

import 'package:elastic_dashboard/services/nt3_type.dart';

void main() {
  test('parses all NT3 wire types', () {
    expect(NT3Type.parse('boolean').typeId, 0x00);
    expect(NT3Type.parse('double').typeId, 0x01);
    expect(NT3Type.parse('string').typeId, 0x02);
    expect(NT3Type.parse('raw').typeId, 0x03);
    expect(NT3Type.parse('boolean[]').typeId, 0x10);
    expect(NT3Type.parse('double[]').typeId, 0x11);
    expect(NT3Type.parse('string[]').typeId, 0x12);
    expect(NT3Type.parse('rpc').typeId, 0x20);
  });

  test('converts editable string values', () {
    expect(NT3Type.boolean().convertString('true'), true);
    expect(NT3Type.double().convertString('5'), 5.0);
    expect(NT3Type.string().convertString('hello'), 'hello');
    expect(NT3Type.array(NT3Type.double()).convertString('[1, 2.5]'), [
      1.0,
      2.5,
    ]);
  });
}

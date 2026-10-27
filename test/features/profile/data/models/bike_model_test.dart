import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/profile/data/models/bike_model.dart';

void main() {
  /// One record of the bike list; [line] is whatever the backend put under
  /// `Line`, or absent when null.
  Map<String, dynamic> record({Object? line}) => {
    'Line': ?line,
    'UnitID': 'YAMAHA R25',
    'PlateNo': 'L 1234 AB',
    'ChasisNo': 'MH3RG1',
    'EngineNo': 'G3E1',
    'Color': 'Hitam',
    'Year': '2023',
    'Photo': '',
  };

  group('Line', () {
    test('is read when it arrives as a string', () {
      expect(BikeModel.fromJson(record(line: '12')).line, '12');
    });

    test('is read when it arrives as a number', () {
      expect(BikeModel.fromJson(record(line: 12)).line, '12');
    });

    test('is kept exactly as sent, leading zeros included', () {
      expect(BikeModel.fromJson(record(line: '0012')).line, '0012');
    });

    test('is empty when the record carries none', () {
      expect(BikeModel.fromJson(record()).line, '');
    });

    test('reaches the entity, which is what an edit or a delete sends', () {
      final entity = BikeModel.fromJson(record(line: 5)).toEntity();

      expect(entity.line, '5');
      expect(entity.plateNo, 'L 1234 AB');
    });
  });
}

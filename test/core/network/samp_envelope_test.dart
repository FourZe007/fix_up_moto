import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/network/samp_envelope.dart';

Response<dynamic> responseWith(dynamic body) => Response<dynamic>(
  requestOptions: RequestOptions(path: '/x'),
  data: body,
);

void main() {
  group('SampEnvelope.message', () {
    test('returns the Msg', () {
      expect(
        SampEnvelope.message(responseWith({'Msg': 'Berhasil', 'Data': []})),
        'Berhasil',
      );
    });

    test('trims it', () {
      expect(
        SampEnvelope.message(responseWith({'Msg': '  Gagal \n'})),
        'Gagal',
      );
    });

    test('accepts the other spellings of the key', () {
      for (final key in ['msg', 'Message', 'message']) {
        expect(
          SampEnvelope.message(responseWith({key: 'Sukses'})),
          'Sukses',
          reason: key,
        );
      }
    });

    test('is null when the body has none, or it is blank', () {
      expect(SampEnvelope.message(responseWith({'Data': []})), isNull);
      expect(SampEnvelope.message(responseWith({'Msg': ''})), isNull);
      expect(SampEnvelope.message(responseWith({'Msg': '   '})), isNull);
    });

    test('is null when the Msg is not text', () {
      expect(SampEnvelope.message(responseWith({'Msg': 100})), isNull);
      expect(SampEnvelope.message(responseWith({'Msg': null})), isNull);
    });

    test('is null when the body is not a map at all', () {
      expect(SampEnvelope.message(responseWith('plain text')), isNull);
      expect(SampEnvelope.message(responseWith(null)), isNull);
    });
  });
}

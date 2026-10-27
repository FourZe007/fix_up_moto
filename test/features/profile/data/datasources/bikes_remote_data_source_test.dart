import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/features/profile/data/datasources/bikes_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late BikesRemoteDataSource dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = BikesRemoteDataSourceImpl(dio);
  });

  Future<void> update({String line = '7', String plateNo = 'L 1234 AB'}) =>
      dataSource.updateBike(
        memberId: 'M-001',
        line: line,
        plateNo: plateNo,
        unitId: 'YAMAHA R25',
        chasisNo: 'MH3RG1',
        engineNo: 'G3E1',
        color: 'Hitam',
        year: '2023',
        photo: '',
      );

  /// Makes Modify answer with [body].
  void answerWith(Map<String, dynamic>? body) {
    when(
      () => dio.post<dynamic>(
        ApiConstants.modify,
        data: any<dynamic>(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: ApiConstants.modify),
        statusCode: 200,
        data: body,
      ),
    );
  }

  /// Makes Modify fail with an HTTP error.
  void failWith(int statusCode, {Map<String, dynamic>? body}) {
    when(
      () => dio.post<dynamic>(
        ApiConstants.modify,
        data: any<dynamic>(named: 'data'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ApiConstants.modify),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.modify),
          statusCode: statusCode,
          data: body,
        ),
      ),
    );
  }

  group('addBike', () {
    test(
      'leaves Line out entirely — a new bike has no record to point at',
      () async {
        answerWith({
          'Code': '100',
          'Msg': 'Berhasil',
          'Data': [
            {'ResultMessage': 'Berhasil'},
          ],
        });

        await dataSource.addBike(
          memberId: 'M-001',
          plateNumber: 'L 1234 AB',
          unitId: 'YAMAHA R25',
          chasisNo: 'MH3RG1',
          engineNo: 'G3E1',
          color: 'Hitam',
          year: '2023',
          photo: '',
        );

        final body =
            verify(
                  () => dio.post<dynamic>(
                    ApiConstants.modify,
                    data: captureAny<dynamic>(named: 'data'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(body['Mode'], '1');
        expect(body['TransID'], 'REGISTERMOTOR');
        expect(body['Data'], {
          'MemberID': 'M-001',
          'PlateNo': 'L 1234 AB',
          'UnitID': 'YAMAHA R25',
          'ChasisNo': 'MH3RG1',
          'EngineNo': 'G3E1',
          'Color': 'Hitam',
          'Year': '2023',
          'Photo': '',
        });
        // Not sent empty either: the key itself is absent.
        expect((body['Data'] as Map).containsKey('Line'), isFalse);
      },
    );
  });

  group('updateBike', () {
    Map<String, dynamic> sentBody() =>
        verify(
              () => dio.post<dynamic>(
                ApiConstants.modify,
                data: captureAny<dynamic>(named: 'data'),
              ),
            ).captured.single
            as Map<String, dynamic>;

    test('posts Modify with Mode 2 and REGISTERMOTOR, and the bike\'s Line '
        'among every field', () async {
      answerWith({'Code': '100', 'Msg': 'Sukses'});

      await update();

      final body = sentBody();
      // The same call as adding a bike (Mode 1) with the mode swapped and the
      // record's Line filled in, the way a member edit reuses REGISTRATION.
      expect(body['Mode'], '2');
      expect(body['TransID'], 'REGISTERMOTOR');
      expect(body['Data'], {
        'MemberID': 'M-001',
        'Line': '7',
        'PlateNo': 'L 1234 AB',
        'UnitID': 'YAMAHA R25',
        'ChasisNo': 'MH3RG1',
        'EngineNo': 'G3E1',
        'Color': 'Hitam',
        'Year': '2023',
        'Photo': '',
      });
    });

    test(
      'sends a changed plate as a plain field, with the Line unchanged',
      () async {
        answerWith({'Code': '100', 'Msg': 'Sukses'});

        // The plate is no longer the key: it can differ from what the list held,
        // and the Line alone says which bike this is.
        await update(line: '12', plateNo: 'B 9 ZZ');

        final data = sentBody()['Data'] as Map;
        expect(data['Line'], '12');
        expect(data['PlateNo'], 'B 9 ZZ');
      },
    );

    test('succeeds on any answer that is not an explicit Gagal', () async {
      // The success wording of this call is unknown, so none of these may turn
      // a saved edit into an error.
      for (final msg in ['Sukses', 'Berhasil', 'OK']) {
        answerWith({'Code': '100', 'Msg': msg});
        await expectLater(update(), completes, reason: msg);
      }
      answerWith({'Code': '100'});
      await expectLater(update(), completes, reason: 'no Msg at all');
    });

    test('succeeds when the answer carries no Data rows', () async {
      answerWith({'Code': '100', 'Msg': 'Berhasil', 'Data': []});

      await expectLater(update(), completes);
    });

    test('treats Gagal as a refusal, with the server\'s own reason', () async {
      answerWith({
        'Code': '100',
        'Msg': 'Gagal',
        'Data': [
          {'ResultMessage': 'Plat nomor tidak ditemukan'},
        ],
      });

      expect(
        update(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'Plat nomor tidak ditemukan')
              .having((e) => e.statusCode, 'statusCode', 200),
        ),
      );
    });

    test('reads Gagal whatever its case', () async {
      answerWith({'Code': '100', 'Msg': ' GAGAL '});

      expect(update(), throwsA(isA<ServerException>()));
    });

    test(
      'falls back to generic wording when a refusal gives no reason',
      () async {
        for (final data in <List<Map<String, dynamic>>?>[
          null,
          [],
          [
            {'ResultMessage': '  '},
          ],
        ]) {
          answerWith({'Code': '100', 'Msg': 'Gagal', 'Data': ?data});

          await expectLater(
            update(),
            throwsA(
              isA<ServerException>().having(
                (e) => e.message,
                'message',
                'Gagal mengubah data motor',
              ),
            ),
            reason: '$data',
          );
        }
      },
    );

    test('turns a 401 into UnauthorizedException', () async {
      failWith(401);

      expect(update(), throwsA(isA<UnauthorizedException>()));
    });

    test('turns a server error into a ServerException with its Msg', () async {
      failWith(500, body: {'Code': '500', 'Msg': 'Server sedang sibuk'});

      expect(
        update(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'Server sedang sibuk')
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });

  group('deleteBike', () {
    Future<void> delete({String line = '7'}) =>
        dataSource.deleteBike(memberId: 'M-001', line: line);

    Map<String, dynamic> sentBody() =>
        verify(
              () => dio.post<dynamic>(
                ApiConstants.modify,
                data: captureAny<dynamic>(named: 'data'),
              ),
            ).captured.single
            as Map<String, dynamic>;

    test('posts exactly four things: Mode 3, REGISTERMOTOR, the member and the '
        'Line', () async {
      answerWith({'Code': '100', 'Msg': 'Sukses'});

      await delete();

      final body = sentBody();
      expect(body['Mode'], '3');
      expect(body['TransID'], 'REGISTERMOTOR');
      expect(body['Data'], {'MemberID': 'M-001', 'Line': '7'});
      expect(body.keys, unorderedEquals(['Mode', 'TransID', 'Data']));
    });

    test('sends no plate and no other bike detail', () async {
      answerWith({'Code': '100', 'Msg': 'Sukses'});

      await delete();

      expect((sentBody()['Data'] as Map).keys, ['MemberID', 'Line']);
    });

    test('is not ModifyMode.delete or changePassword — a bike has its own '
        'mode', () async {
      answerWith({'Code': '100', 'Msg': 'Sukses'});

      await delete();

      expect(sentBody()['Mode'], isNot(ModifyMode.delete.wireValue));
    });

    test('sends the Line exactly as given', () async {
      answerWith({'Code': '100', 'Msg': 'Sukses'});

      await delete(line: '0042');

      expect((sentBody()['Data'] as Map)['Line'], '0042');
    });

    test('succeeds on any answer that is not an explicit Gagal', () async {
      for (final msg in ['Sukses', 'Berhasil', 'OK']) {
        answerWith({'Code': '100', 'Msg': msg});
        await expectLater(delete(), completes, reason: msg);
      }
      answerWith({'Code': '100'});
      await expectLater(delete(), completes, reason: 'no Msg at all');
    });

    test('treats Gagal as a refusal, with the server\'s own reason', () async {
      answerWith({
        'Code': '100',
        'Msg': 'Gagal',
        'Data': [
          {'ResultMessage': 'Motor masih memiliki booking'},
        ],
      });

      expect(
        delete(),
        throwsA(
          isA<ServerException>()
              .having(
                (e) => e.message,
                'message',
                'Motor masih memiliki booking',
              )
              .having((e) => e.statusCode, 'statusCode', 200),
        ),
      );
    });

    test('reads Gagal whatever its case', () async {
      answerWith({'Code': '100', 'Msg': ' GAGAL '});

      expect(delete(), throwsA(isA<ServerException>()));
    });

    test(
      'falls back to its own generic wording when a refusal gives no reason',
      () async {
        for (final data in <List<Map<String, dynamic>>?>[
          null,
          [],
          [
            {'ResultMessage': '  '},
          ],
        ]) {
          answerWith({'Code': '100', 'Msg': 'Gagal', 'Data': ?data});

          await expectLater(
            delete(),
            throwsA(
              isA<ServerException>().having(
                (e) => e.message,
                'message',
                'Gagal menghapus motor',
              ),
            ),
            reason: '$data',
          );
        }
      },
    );

    test('turns a 401 into UnauthorizedException', () async {
      failWith(401);

      expect(delete(), throwsA(isA<UnauthorizedException>()));
    });

    test('turns a server error into a ServerException with its Msg', () async {
      failWith(500, body: {'Code': '500', 'Msg': 'Server sedang sibuk'});

      expect(
        delete(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'Server sedang sibuk')
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });
}

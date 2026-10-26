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

  Future<void> update({String plateNo = 'L 1234 AB'}) => dataSource.updateBike(
    memberId: 'M-001',
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

  group('updateBike', () {
    test('posts Modify with Mode 2 and REGISTERMOTOR, and the bike\'s plate '
        'as its key', () async {
      answerWith({'Code': '100', 'Msg': 'Sukses'});

      await update();

      final body =
          verify(
                () => dio.post<dynamic>(
                  ApiConstants.modify,
                  data: captureAny<dynamic>(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;

      // The same call as adding a bike (Mode 1) with only the mode swapped,
      // the way a member edit reuses REGISTRATION.
      expect(body['Mode'], '2');
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
    });

    test(
      'sends the plate exactly as given, never re-cased or re-spaced',
      () async {
        answerWith({'Code': '100', 'Msg': 'Sukses'});

        await update(plateNo: 'l1234ab');

        final body =
            verify(
                  () => dio.post<dynamic>(
                    ApiConstants.modify,
                    data: captureAny<dynamic>(named: 'data'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect((body['Data'] as Map)['PlateNo'], 'l1234ab');
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
}

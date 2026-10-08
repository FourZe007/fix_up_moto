import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/features/membership/data/datasources/rewards_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late RewardsRemoteDataSource dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = RewardsRemoteDataSourceImpl(dio);
  });

  void givenResponse(Object? body) {
    when(
      () => dio.post<dynamic>(
        ApiConstants.master,
        data: any<dynamic>(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: ApiConstants.master),
        data: body,
      ),
    );
  }

  test('requests POINTID from the Master endpoint and maps every reward', () async {
    givenResponse({
      'Msg': 'Sukses',
      'Code': '100',
      'Data': [
        {
          'PointID': 'C01',
          'PointName': 'DISKON JASA SERVICE Rp. 20.000,00',
          'PointQty': 100,
        },
        {'PointID': 'C02', 'PointName': 'GRATIS GANTI OLI', 'PointQty': 250},
      ],
    });

    final rewards = await dataSource.getRewards();

    expect(rewards, hasLength(2));
    expect(rewards[0].pointId, 'C01');
    expect(rewards[0].pointName, 'DISKON JASA SERVICE Rp. 20.000,00');
    expect(rewards[0].pointQty, 100);
    expect(rewards[1].toEntity().pointId, 'C02');
    expect(rewards[1].toEntity().pointQty, 250);
    verify(
      () => dio.post<dynamic>(ApiConstants.master, data: {'Jenis': 'POINTID'}),
    ).called(1);
  });

  test('an empty Data array is an empty list, not an error', () async {
    givenResponse({'Msg': 'Sukses', 'Code': '100', 'Data': []});

    expect(await dataSource.getRewards(), isEmpty);
  });

  test('a response without a Data array is a ServerException', () async {
    givenResponse({'Msg': 'Gagal', 'Code': '500'});

    expect(
      dataSource.getRewards(),
      throwsA(
        isA<ServerException>().having((e) => e.message, 'message', 'Gagal'),
      ),
    );
  });

  test('a 401 from the server becomes UnauthorizedException', () async {
    when(
      () => dio.post<dynamic>(
        ApiConstants.master,
        data: any<dynamic>(named: 'data'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ApiConstants.master),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.master),
          statusCode: 401,
        ),
      ),
    );

    expect(dataSource.getRewards(), throwsA(isA<UnauthorizedException>()));
  });

  group('redeemReward', () {
    void givenModifyResponse(Object? body) {
      when(
        () => dio.post<dynamic>(
          ApiConstants.modify,
          data: any<dynamic>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.modify),
          data: body,
        ),
      );
    }

    test('posts REDEEMPOINT to Modify with the member and the voucher', () async {
      givenModifyResponse({
        'Msg': 'Sukses',
        'Code': '100',
        'Data': [
          {'ResultMessage': 'Berhasil'},
        ],
      });

      final result = await dataSource.redeemReward(
        memberId: '0101202300000003',
        pointId: 'B01',
      );

      expect(result.resultMessage, 'Berhasil');
      verify(
        () => dio.post<dynamic>(
          ApiConstants.modify,
          data: {
            'Mode': '1',
            'TransID': 'REDEEMPOINT',
            'Data': {'MemberID': '0101202300000003', 'PointID': 'B01'},
          },
        ),
      ).called(1);
    });

    test('a refusal with no Data becomes a ServerException with its Msg', () async {
      givenModifyResponse({'Msg': 'Point tidak cukup', 'Code': '400'});

      expect(
        dataSource.redeemReward(memberId: 'M', pointId: 'B01'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'Point tidak cukup',
          ),
        ),
      );
    });

    test('a 401 from the server becomes UnauthorizedException', () async {
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
            statusCode: 401,
          ),
        ),
      );

      expect(
        dataSource.redeemReward(memberId: 'M', pointId: 'B01'),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });
}

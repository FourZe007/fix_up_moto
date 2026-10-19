import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/features/profile/data/datasources/profile_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late ProfileRemoteDataSource dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = ProfileRemoteDataSourceImpl(dio);
  });

  Future<void> update() => dataSource.updateProfile(
    memberId: 'M-001',
    name: 'Budi',
    phoneNo: '81234567890',
    email: 'budi@example.com',
  );

  group('updateProfile', () {
    test('posts Modify with Mode 2 and the existing member\'s id', () async {
      when(
        () => dio.post<dynamic>(
          ApiConstants.modify,
          data: any<dynamic>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.modify),
          data: {'Code': '100', 'Msg': 'Sukses'},
        ),
      );

      await update();

      final body =
          verify(
                () => dio.post<dynamic>(
                  ApiConstants.modify,
                  data: captureAny<dynamic>(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;

      // Same body shape as registration; only Mode differs, and MemberID is
      // filled because a blank one means "new account".
      expect(body['Mode'], '2');
      expect(body['TransID'], 'REGISTRATION');
      expect(body['Data'], {
        'MemberID': 'M-001',
        'MemberName': 'Budi',
        'PhoneNo': '81234567890',
        'EmailAddress': 'budi@example.com',
      });
    });

    test('never sends a password field', () async {
      when(
        () => dio.post<dynamic>(
          ApiConstants.modify,
          data: any<dynamic>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.modify),
          data: {'Code': '100'},
        ),
      );

      await update();

      final body =
          verify(
                () => dio.post<dynamic>(
                  ApiConstants.modify,
                  data: captureAny<dynamic>(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      final data = body['Data'] as Map<String, dynamic>;

      // A blank MemberPass could be read as "set the password to nothing".
      expect(data.containsKey('MemberPass'), isFalse);
      expect(data.containsKey('OldPass'), isFalse);
    });

    test('turns a 401 into UnauthorizedException', () async {
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

      expect(update(), throwsA(isA<UnauthorizedException>()));
    });

    test('turns a server error into a ServerException with its Msg', () async {
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
            statusCode: 500,
            data: {'Code': '500', 'Msg': 'Nomor sudah terdaftar'},
          ),
        ),
      );

      expect(
        update(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'Nomor sudah terdaftar')
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });
}

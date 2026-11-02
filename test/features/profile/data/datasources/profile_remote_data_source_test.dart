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

  group('changePassword', () {
    Future<void> change() => dataSource.changePassword(
      memberId: '0101202300000003',
      phoneNo: '8123456789',
      oldPassword: 'JAngelus21',
      newPassword: '123456789',
    );

    /// Modify's answer: HTTP 200 with `Data[0].ResultMessage` set to [message].
    void givenAnswer(dynamic data) {
      when(
        () => dio.post<dynamic>(
          ApiConstants.modify,
          data: any<dynamic>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.modify),
          statusCode: 200,
          data: data,
        ),
      );
    }

    Map<String, dynamic> answer(String message, {String msg = 'Sukses'}) => {
      'Code': '100',
      'Msg': msg,
      'Data': [
        {'ResultMessage': message},
      ],
    };

    test('posts Modify with Mode 3 and the confirmed body', () async {
      givenAnswer(answer('0101202300000003'));

      await change();

      final body =
          verify(
                () => dio.post<dynamic>(
                  ApiConstants.modify,
                  data: captureAny<dynamic>(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(body['Mode'], '3');
      expect(body['TransID'], 'REGISTRATION');
      // Exactly the keys the backend takes: the new password is MemberPass, the
      // old one OldPass, and PhoneNo is the login ID.
      expect(body['Data'], {
        'MemberID': '0101202300000003',
        'MemberPass': '123456789',
        'PhoneNo': '8123456789',
        'OldPass': 'JAngelus21',
        'IsGoogle': '0',
      });
    });

    test('succeeds when ResultMessage is the member\'s id', () async {
      givenAnswer(answer('0101202300000003'));

      await expectLater(change(), completes);
    });

    test('succeeds on the id whatever the Msg says', () async {
      givenAnswer(answer('0101202300000003', msg: 'Berhasil'));

      await expectLater(change(), completes);
    });

    test('ignores spaces around the returned id', () async {
      givenAnswer(answer(' 0101202300000003 '));

      await expectLater(change(), completes);
    });

    test('throws a ServerException with the server\'s reason when '
        'ResultMessage is not the id', () async {
      givenAnswer(answer('Password lama salah', msg: 'Gagal'));

      await expectLater(
        change(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'Password lama salah')
              .having((e) => e.statusCode, 'statusCode', 200),
        ),
      );
    });

    test('is a refusal even though the status was 200', () async {
      // The id of some other member is not this member's confirmation either.
      givenAnswer(answer('0101202300000099'));

      await expectLater(change(), throwsA(isA<ServerException>()));
    });

    test('falls back to a message when the reason is blank', () async {
      givenAnswer(answer('   '));

      await expectLater(
        change(),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'Gagal mengubah sandi',
          ),
        ),
      );
    });

    test('reads an answer with no Data as a refusal, not a crash', () async {
      givenAnswer({'Code': '100', 'Msg': 'Gagal'});

      await expectLater(
        change(),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'Gagal mengubah sandi',
          ),
        ),
      );
    });

    test('reads a ResultMessage that is not text as a refusal', () async {
      givenAnswer({
        'Code': '100',
        'Data': [
          {'ResultMessage': 12345},
        ],
      });

      await expectLater(change(), throwsA(isA<ServerException>()));
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

      await expectLater(change(), throwsA(isA<UnauthorizedException>()));
    });
  });
}

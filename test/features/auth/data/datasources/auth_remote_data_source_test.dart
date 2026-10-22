import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:fix_up_moto/features/auth/data/models/login_user_model.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late AuthRemoteDataSource dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = AuthRemoteDataSourceImpl(dio);
  });

  /// The real login response: no PhoneNo, no isGoogle echoed back.
  void givenLoginResponds() {
    when(
      () => dio.post<dynamic>(
        ApiConstants.login,
        data: any<dynamic>(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: ApiConstants.login),
        data: {
          'Msg': 'Sukses',
          'Code': '100',
          'Data': [
            {
              'Flag': 1,
              'Memo': 'SUKSES',
              'MemberID': '0101202400000014',
              'MemberName': 'ANTONIUS',
              'EmailAddress': '-',
            },
          ],
        },
      ),
    );
  }

  group('login', () {
    test('stamps the normalised phone number on a manual login', () async {
      givenLoginResponds();

      final user = await dataSource.login('081234567890', 'Password1');

      // The leading zero is stripped before sending, and that sent value is
      // what the session remembers — it is what booking's UPhoneNo needs.
      expect(user.loginId, '81234567890');
      expect(user.isGoogleLogin, '0');
    });

    test('stamps the untouched email and isGoogle on a Google login', () async {
      givenLoginResponds();

      final user = await dataSource.login(
        'member@example.com',
        'member-google',
        isGoogleLogin: '1',
      );

      // The backend never echoes isGoogle, so without the stamp this would
      // silently stay '0' for a Google account.
      expect(user.loginId, 'member@example.com');
      expect(user.isGoogleLogin, '1');
    });

    test(
      'keeps the stamp through the cached-session JSON round trip',
      () async {
        givenLoginResponds();

        final user = await dataSource.login(
          'member@example.com',
          'member-google',
          isGoogleLogin: '1',
        );
        final restored = LoginUserModel.fromJson(user.toJson());
        final entity = restored.toEntity();

        expect(entity.loginId, 'member@example.com');
        expect(entity.isGoogle, '1');
      },
    );
  });

  group('register', () {
    /// What `Modify` answers when the sign-up was handled: [msg] is the
    /// envelope's verdict and [data] is `Data` (the new member's id in
    /// `ResultMessage` on success, the reason on a refusal).
    void givenModifyAnswers({String? msg, Object? data}) {
      when(
        () => dio.post<dynamic>(
          ApiConstants.modify,
          data: any<dynamic>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.modify),
          statusCode: 200,
          data: {'Msg': ?msg, 'Code': '100', 'Data': ?data},
        ),
      );
    }

    Future<void> register() => dataSource.register(
      name: 'Budi Santoso',
      phone: '081234567890',
      password: 'Password1',
    );

    void verifyLoginNeverAttempted() => verifyNever(
      () => dio.post<dynamic>(
        ApiConstants.login,
        data: any<dynamic>(named: 'data'),
      ),
    );

    Matcher refusedWith(String message) => throwsA(
      isA<ServerException>().having((e) => e.message, 'message', message),
    );

    group('when Modify says Berhasil and returns the new id', () {
      test('logs in and returns the member', () async {
        givenModifyAnswers(
          msg: 'Berhasil',
          data: [
            {'ResultMessage': '0101202400000014'},
          ],
        );
        givenLoginResponds();

        final user = await dataSource.register(
          name: 'Budi Santoso',
          phone: '081234567890',
          password: 'Password1',
        );

        expect(user.id, '0101202400000014');
        expect(user.loginId, '81234567890');
        verify(
          () => dio.post<dynamic>(
            ApiConstants.login,
            data: any<dynamic>(named: 'data'),
          ),
        ).called(1);
      });

      test('sends the new-account body, with the bare phone number', () async {
        givenModifyAnswers(
          msg: 'Berhasil',
          data: [
            {'ResultMessage': '0101202400000014'},
          ],
        );
        givenLoginResponds();

        await register();

        final body =
            verify(
                  () => dio.post<dynamic>(
                    ApiConstants.modify,
                    data: captureAny<dynamic>(named: 'data'),
                  ),
                ).captured.single
                as Map;
        expect(body['Mode'], '1');
        expect(body['TransID'], 'REGISTRATION');
        expect(body['Data'], {
          'MemberName': 'Budi Santoso',
          'MemberPass': 'Password1',
          'PhoneNo': '81234567890',
          'EmailAddress': '',
          'IsGoogle': '0',
        });
      });

      test('does not mind the case or spacing of the verdict', () async {
        givenModifyAnswers(
          msg: '  BERHASIL ',
          data: [
            {'ResultMessage': '0101202400000014'},
          ],
        );
        givenLoginResponds();

        await expectLater(register(), completes);
      });
    });

    group('when Modify does not say Berhasil with an id', () {
      test('Gagal is an error carrying the server\'s reason, and no login '
          'is attempted', () async {
        givenModifyAnswers(
          msg: 'Gagal',
          data: [
            {'ResultMessage': 'No HP sudah terdaftar'},
          ],
        );

        await expectLater(register(), refusedWith('No HP sudah terdaftar'));
        verifyLoginNeverAttempted();
      });

      test('Gagal with no reason falls back to a plain message', () async {
        givenModifyAnswers(msg: 'Gagal', data: <Object>[]);

        await expectLater(register(), refusedWith('Gagal membuat akun'));
        verifyLoginNeverAttempted();
      });

      test('Gagal with no Data at all is the same', () async {
        givenModifyAnswers(msg: 'Gagal');

        await expectLater(register(), refusedWith('Gagal membuat akun'));
        verifyLoginNeverAttempted();
      });

      test('Berhasil with a blank id is not enough', () async {
        givenModifyAnswers(
          msg: 'Berhasil',
          data: [
            {'ResultMessage': '   '},
          ],
        );

        await expectLater(register(), refusedWith('Gagal membuat akun'));
        verifyLoginNeverAttempted();
      });

      test('Berhasil with no ResultMessage is an error, not a crash', () async {
        givenModifyAnswers(
          msg: 'Berhasil',
          data: [
            {'Other': 'x'},
          ],
        );

        await expectLater(register(), refusedWith('Gagal membuat akun'));
        verifyLoginNeverAttempted();
      });

      test(
        'a ResultMessage that is not text is an error, not a crash',
        () async {
          givenModifyAnswers(
            msg: 'Berhasil',
            data: [
              {'ResultMessage': null},
            ],
          );

          await expectLater(register(), refusedWith('Gagal membuat akun'));
          verifyLoginNeverAttempted();
        },
      );

      test('an id without the Berhasil verdict is still a refusal', () async {
        givenModifyAnswers(
          msg: 'Sukses',
          data: [
            {'ResultMessage': '0101202400000014'},
          ],
        );

        await expectLater(register(), throwsA(isA<ServerException>()));
        verifyLoginNeverAttempted();
      });

      test('a missing Msg is a refusal', () async {
        givenModifyAnswers(
          data: [
            {'ResultMessage': '0101202400000014'},
          ],
        );

        await expectLater(register(), throwsA(isA<ServerException>()));
        verifyLoginNeverAttempted();
      });
    });

    test(
      'a failed request (HTTP 500) is still an error, with no login',
      () async {
        when(
          () => dio.post<dynamic>(
            ApiConstants.modify,
            data: any<dynamic>(named: 'data'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ApiConstants.modify),
            type: DioExceptionType.badResponse,
            response: Response<dynamic>(
              requestOptions: RequestOptions(path: ApiConstants.modify),
              statusCode: 500,
              data: {'Msg': 'Internal error'},
            ),
          ),
        );

        await expectLater(register(), refusedWith('Internal error'));
        verifyLoginNeverAttempted();
      },
    );
  });
}

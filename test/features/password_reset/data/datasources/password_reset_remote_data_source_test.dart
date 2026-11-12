import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/network/interceptors/logging_interceptor.dart';
import 'package:fix_up_moto/features/password_reset/data/datasources/password_reset_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late PasswordResetRemoteDataSource dataSource;

  setUp(() {
    dio = MockDio();
    // Seeded, so the throwaway password is repeatable inside one test.
    dataSource = PasswordResetRemoteDataSourceImpl(dio, random: Random(7));
  });

  Response<dynamic> answer(dynamic data, {int statusCode = 200}) =>
      Response<dynamic>(
        requestOptions: RequestOptions(path: ''),
        data: data,
        statusCode: statusCode,
      );

  DioException failure(int statusCode, {dynamic body}) => DioException(
    requestOptions: RequestOptions(path: ''),
    response: answer(body, statusCode: statusCode),
  );

  /// What the login endpoint answered for a wrong password, from the owner's
  /// own capture (the name and id are a test member's).
  Map<String, dynamic> wrongPasswordAnswer({
    Object? flag = 0,
    String memo = 'PASSWORD SALAH',
    Object? memberId = '0101202400000014',
    String isGoogle = '0',
  }) => {
    'Msg': 'Sukses',
    'Code': '100',
    'Data': [
      {
        'Flag': flag,
        'Memo': memo,
        'MemberID': memberId,
        'MemberName': 'ANTONIUS',
        'EmailAddress': '-',
        'IsGoogle': isGoogle,
      },
    ],
  };

  void loginAnswers(dynamic data) {
    when(
      () => dio.post<dynamic>(ApiConstants.login, data: any(named: 'data')),
    ).thenAnswer((_) async => answer(data));
  }

  Map<String, dynamic> sentLoginBody() =>
      verify(
            () => dio.post<dynamic>(
              ApiConstants.login,
              data: captureAny(named: 'data'),
            ),
          ).captured.last
          as Map<String, dynamic>;

  group('findMember', () {
    test('reads the MemberID out of a wrong-password answer', () async {
      loginAnswers(wrongPasswordAnswer());

      final found = await dataSource.findMember('81234567890');

      expect(found.memberId, '0101202400000014');
      expect(found.isGoogle, isFalse);
    });

    test('asks the login endpoint, as a manual (non-Google) login', () async {
      loginAnswers(wrongPasswordAnswer());

      await dataSource.findMember('81234567890');

      final body = sentLoginBody();
      expect(body['PhoneNo'], '81234567890');
      expect(body['isGoogle'], '0');
      expect(body.keys, containsAll(['PhoneNo', 'DecryptedPassword']));
    });

    test('sends the subscriber number however the phone was typed', () async {
      loginAnswers(wrongPasswordAnswer());

      await dataSource.findMember('+62 0812-3456-7890');

      expect(sentLoginBody()['PhoneNo'], '81234567890');
    });

    test(
      'sends a long throwaway password, never an empty or fixed one',
      () async {
        loginAnswers(wrongPasswordAnswer());

        await dataSource.findMember('81234567890');
        final first = sentLoginBody()['DecryptedPassword'] as String;
        await dataSource.findMember('81234567890');
        final second = sentLoginBody()['DecryptedPassword'] as String;

        expect(first, hasLength(24));
        expect(second, hasLength(24));
        // A new one each time: a lookup can never sign somebody in by luck.
        expect(first, isNot(second));
      },
    );

    test('still finds the member when the throwaway password was somehow '
        'right (Flag 1): it only reads the id, nothing is signed in', () async {
      loginAnswers(wrongPasswordAnswer(flag: 1, memo: 'SUKSES'));

      final found = await dataSource.findMember('81234567890');

      expect(found.memberId, '0101202400000014');
    });

    test('reads Flag when it arrives as a numeric string', () async {
      loginAnswers(wrongPasswordAnswer(flag: '0'));

      final found = await dataSource.findMember('81234567890');

      expect(found.memberId, '0101202400000014');
    });

    test('says an account made through Google is one', () async {
      loginAnswers(wrongPasswordAnswer(isGoogle: '1'));

      final found = await dataSource.findMember('81234567890');

      expect(found.isGoogle, isTrue);
    });

    test('throws NotFoundException for Flag 2, the server\'s "no such '
        'account"', () async {
      loginAnswers(wrongPasswordAnswer(flag: 2, memo: 'USER TIDAK ADA'));

      expect(
        dataSource.findMember('81234567890'),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.message,
            'message',
            PasswordResetRemoteDataSourceImpl.notFoundMessage,
          ),
        ),
      );
    });

    test('reads the owner\'s capture of an unregistered number (Flag 2, every '
        'field blank) as not found', () async {
      loginAnswers({
        'Msg': 'Sukses',
        'Code': '100',
        'Data': [
          {
            'Flag': 2,
            'Memo': 'NO TELEPON/EMAIL TIDAK TERDAFTAR',
            'MemberID': '',
            'MemberName': '',
            'EmailAddress': '',
            'IsGoogle': '',
          },
        ],
      });

      expect(
        dataSource.findMember('81234567890'),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.message,
            'message',
            'Nomor telepon belum terdaftar',
          ),
        ),
      );
    });

    test('throws NotFoundException when the answer carries no id', () async {
      loginAnswers(wrongPasswordAnswer(memberId: ''));

      expect(
        dataSource.findMember('81234567890'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test(
      'throws NotFoundException when the answer has no member at all',
      () async {
        loginAnswers({'Msg': 'Sukses', 'Code': '100', 'Data': <dynamic>[]});

        expect(
          dataSource.findMember('81234567890'),
          throwsA(isA<NotFoundException>()),
        );
      },
    );

    test('throws a ServerException with the server\'s words when the answer '
        'has no Data array', () async {
      loginAnswers({'Msg': 'FORMAT SALAH', 'Code': '400'});

      expect(
        dataSource.findMember('81234567890'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'FORMAT SALAH',
          ),
        ),
      );
    });

    test('turns a failed request into a ServerException', () async {
      when(
        () => dio.post<dynamic>(ApiConstants.login, data: any(named: 'data')),
      ).thenThrow(failure(500, body: {'Msg': 'SERVER ERROR'}));

      expect(
        dataSource.findMember('81234567890'),
        throwsA(isA<ServerException>()),
      );
    });

    test('turns a 401 into UnauthorizedException', () async {
      when(
        () => dio.post<dynamic>(ApiConstants.login, data: any(named: 'data')),
      ).thenThrow(failure(401));

      expect(
        dataSource.findMember('81234567890'),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('resetPassword', () {
    void modifyAnswers(dynamic data) {
      when(
        () => dio.post<dynamic>(
          ApiConstants.modify,
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => answer(data));
    }

    Future<void> reset() => dataSource.resetPassword(
      memberId: '0101202400000014',
      newPassword: 'Baru12345',
    );

    VerificationResult sent() => verify(
      () => dio.post<dynamic>(
        ApiConstants.modify,
        data: captureAny(named: 'data'),
        options: captureAny(named: 'options'),
      ),
    );

    Map<String, dynamic> succeeded() => {
      'Msg': 'Berhasil',
      'Code': '100',
      'Data': [
        {'ResultMessage': '0101202400000014'},
      ],
    };

    test('posts Modify with Mode 5 and exactly the owner\'s body', () async {
      modifyAnswers(succeeded());

      await reset();

      final body = sent().captured.first as Map<String, dynamic>;
      expect(body['Mode'], '5');
      expect(body['TransID'], 'REGISTRATION');
      expect(body['Data'], {
        'MemberID': '0101202400000014',
        'MemberPass': 'Baru12345',
        'IsGoogle': '0',
      });
    });

    test('sends no phone number and no old password', () async {
      modifyAnswers(succeeded());

      await reset();

      final data =
          (sent().captured.first as Map<String, dynamic>)['Data']
              as Map<String, dynamic>;
      expect(data.containsKey('PhoneNo'), isFalse);
      expect(data.containsKey('OldPass'), isFalse);
    });

    test('keeps the request body, which carries the new password, out of the '
        'debug log', () async {
      modifyAnswers(succeeded());

      await reset();

      final options = sent().captured.last as Options;
      expect(options.extra?[LoggingInterceptor.hideBodyKey], isTrue);
    });

    test('returns normally when the answer is the member\'s id', () async {
      modifyAnswers(succeeded());

      await expectLater(reset(), completes);
    });

    test('throws a ServerException with the reason when the answer is text '
        'instead of the id', () async {
      modifyAnswers({
        'Msg': 'Gagal',
        'Data': [
          {'ResultMessage': 'MEMBER TIDAK DITEMUKAN'},
        ],
      });

      expect(
        reset(),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'MEMBER TIDAK DITEMUKAN',
          ),
        ),
      );
    });

    test('does not trust a 200 with no usable ResultMessage: it falls back '
        'to the envelope\'s Msg', () async {
      modifyAnswers({'Msg': 'Gagal', 'Code': '500'});

      expect(
        reset(),
        throwsA(
          isA<ServerException>().having((e) => e.message, 'message', 'Gagal'),
        ),
      );
    });

    test(
      'says so in plain words when the answer has nothing to read',
      () async {
        modifyAnswers('not even a map');

        expect(
          reset(),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              'Gagal mengatur password baru',
            ),
          ),
        );
      },
    );

    test('does not count a blank ResultMessage as success', () async {
      modifyAnswers({
        'Msg': 'Berhasil',
        'Data': [
          {'ResultMessage': '   '},
        ],
      });

      expect(reset(), throwsA(isA<ServerException>()));
    });

    test('turns a failed request into a ServerException', () async {
      when(
        () => dio.post<dynamic>(
          ApiConstants.modify,
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(failure(500, body: {'Msg': 'SERVER ERROR'}));

      expect(reset(), throwsA(isA<ServerException>()));
    });
  });
}

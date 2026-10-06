import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/api_constants.dart';
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
}

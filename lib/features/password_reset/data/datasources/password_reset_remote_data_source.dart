import 'dart:math';

import 'package:dio/dio.dart';

import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/helpers/phone_number.dart';
import 'package:fix_up_moto/core/network/interceptors/logging_interceptor.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';

/// Who a login lookup found: the id and whether the account came from Google.
class MemberLookupModel {
  final String memberId;
  final bool isGoogle;

  const MemberLookupModel({required this.memberId, required this.isGoogle});
}

abstract class PasswordResetRemoteDataSource {
  /// Finds the member behind [phone] without knowing their password.
  ///
  /// There is no "who owns this number" endpoint, so this asks the login
  /// endpoint with a password nobody has. It refuses (`Flag: 0`, `Memo:
  /// "PASSWORD SALAH"`) but still answers with the member's `MemberID` — which
  /// is all a reset needs. Nothing is signed in and nothing is cached: only the
  /// answer's id is read.
  ///
  /// A number no member has answers `Flag: 2` with a blank `MemberID`.
  ///
  /// Throws [NotFoundException] when the number belongs to no member,
  /// [ServerException] when the server rejects the request.
  Future<MemberLookupModel> findMember(String phone);

  /// Sets a new password ([ModifyMode.forgotPassword], Mode '5').
  ///
  /// Modify answers HTTP 200 whether or not it changed anything. Like Mode 3,
  /// this expects `Data[0].ResultMessage` to be the member's id on success and
  /// the reason, as text, otherwise, and throws a [ServerException] carrying
  /// that reason unless the id came back — so returning normally means the
  /// password changed.
  ///
  /// The request body and both answers are the owner's own: a success answers
  /// with the member's id in `ResultMessage`, and a refusal has the same shape
  /// with an error sentence there instead.
  Future<void> resetPassword({
    required String memberId,
    required String newPassword,
  });
}

class PasswordResetRemoteDataSourceImpl
    implements PasswordResetRemoteDataSource {
  final Dio _dio;
  final Random _random;

  /// [random] is injectable so a test can pin the throwaway password.
  PasswordResetRemoteDataSourceImpl(this._dio, {Random? random})
    : _random = random ?? Random.secure();

  /// The wording shown when no member has the number.
  static const String notFoundMessage = 'Nomor telepon belum terdaftar';

  /// The new password is in this body, so it must never reach the debug log.
  static final Options _unlogged = Options(
    extra: {LoggingInterceptor.hideBodyKey: true},
  );

  @override
  Future<MemberLookupModel> findMember(String phone) async {
    final subscriber = PhoneNumber.toSubscriberNumber(phone);

    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {
          'PhoneNo': subscriber,
          'DecryptedPassword': _passwordNobodyHas(),
          'isGoogle': '0',
        },
      );

      final records = SampEnvelope.rows(response);
      if (records.isEmpty) {
        throw const NotFoundException(message: notFoundMessage);
      }
      final record = records.first;

      final memberId = _text(record['MemberID']);
      // `Flag` 2 is the server's "no such account" (see AuthRepositoryImpl.login);
      // an answer with no id has nobody to reset either way.
      if (memberId.isEmpty || _flagOf(record['Flag']) == 2) {
        throw const NotFoundException(message: notFoundMessage);
      }

      return MemberLookupModel(
        memberId: memberId,
        isGoogle: _text(record['IsGoogle'] ?? record['isGoogle']) == '1',
      );
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  @override
  Future<void> resetPassword({
    required String memberId,
    required String newPassword,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.post(
        ApiConstants.modify,
        data: {
          'Mode': ModifyMode.forgotPassword.wireValue,
          'TransID': 'REGISTRATION',
          'Data': {
            'MemberID': memberId,
            'MemberPass': newPassword,
            // Always '0': a Google account has no password to reset, and the
            // repository refuses one before it gets here.
            'IsGoogle': '0',
          },
        },
        options: _unlogged,
      );
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }

    // The verdict is in the answer, not the status code: the member's id means
    // it worked, anything else is the reason it did not.
    var reason = '';
    try {
      final result = SampEnvelope.first(response)['ResultMessage'];
      if (result is String) reason = result.trim();
    } on ServerException {
      // No Data array, or an empty one: nothing to read a reason from.
    }
    if (reason == memberId) return;

    throw ServerException(
      message: reason.isNotEmpty
          ? reason
          : (SampEnvelope.message(response) ?? 'Gagal mengatur password baru'),
      statusCode: response.statusCode,
    );
  }

  /// A password no member can have chosen: long, random and different every
  /// time, so the lookup can never accidentally sign somebody in.
  String _passwordNobodyHas() {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
      24,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }

  /// A text field's trimmed value, or empty when it is missing or not text.
  /// A number is read as its digits, since this family of endpoints is not
  /// consistent about wire types.
  String _text(Object? value) {
    if (value is String) return value.trim();
    if (value is num) return '$value';
    return '';
  }

  /// `Flag` as an int, whether it arrives as a number or a numeric string;
  /// anything unreadable is 0, which no rule here treats as "no such account".
  int _flagOf(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }
}

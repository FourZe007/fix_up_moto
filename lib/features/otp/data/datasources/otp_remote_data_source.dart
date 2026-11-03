import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/network/interceptors/logging_interceptor.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';

/// Delivers a finished verification message. It does not make or check codes:
/// the app does that, and these two calls only carry the words.
abstract class OtpRemoteDataSource {
  /// Sends [message] to [phoneNumber] through the WhatsApp gateway
  /// ([ApiConstants.whatsAppSendUrl]). [phoneNumber] is the full number,
  /// starting with `62`.
  ///
  /// Throws [NetworkException] when the gateway cannot be reached and
  /// [ServerException] when it refuses or fails, or when no API key is set (in
  /// which case nothing is sent).
  Future<void> sendWhatsApp({
    required String phoneNumber,
    required String message,
  });

  /// Sends an email through the backend's mail sender
  /// ([ApiConstants.sendEmail]). [body] is HTML.
  ///
  /// Throws a [ServerException] when the backend refuses.
  Future<void> sendEmail({
    required String emailAddress,
    required String subject,
    required String body,
  });
}

class OtpRemoteDataSourceImpl implements OtpRemoteDataSource {
  final Dio _dio;
  final String _whatsAppApiKey;

  /// [whatsAppApiKey] is for tests; in the app it is the build-time
  /// [ApiConstants.whatsAppApiKey].
  OtpRemoteDataSourceImpl(
    this._dio, {
    String whatsAppApiKey = ApiConstants.whatsAppApiKey,
  }) : _whatsAppApiKey = whatsAppApiKey;

  /// Both bodies carry the code, so neither may reach the debug log.
  static final Options _unlogged = Options(
    extra: {LoggingInterceptor.hideBodyKey: true},
  );

  /// What the gateway may answer with, on a 2xx, to say it did *not* take the
  /// message. Only "pending" has been seen (an accepted message); these are
  /// guesses at the words for the opposite, and anything else counts as taken.
  static const Set<String> _refusedStatuses = {'failed', 'error', 'rejected'};

  @override
  Future<void> sendWhatsApp({
    required String phoneNumber,
    required String message,
  }) async {
    final key = _whatsAppApiKey.trim();
    if (key.isEmpty) {
      // Nothing to send it with, and asking the gateway would only be refused.
      // The member sees the first line; the second is for whoever builds this.
      if (kDebugMode) {
        debugPrint(
          'KIRIMWA_API_KEY is not set: put it in dart_defines.json and run '
          'with --dart-define-from-file=dart_defines.json.',
        );
      }
      throw const ServerException(message: 'Layanan WhatsApp belum diatur');
    }

    try {
      final response = await _dio.post<dynamic>(
        ApiConstants.whatsAppSendUrl,
        data: {
          'phone_number': phoneNumber,
          'message': message,
          'device_id': ApiConstants.whatsAppDeviceId,
          'message_type': 'text',
        },
        // The key goes to the gateway and nowhere else, and neither it nor the
        // body (which carries the code) may reach the debug log.
        options: Options(
          headers: {'Authorization': 'Bearer $key'},
          extra: {LoggingInterceptor.hideBodyKey: true},
        ),
      );

      // Dio throws for anything but a 2xx, so the gateway took the request. It
      // answers a taken message with status "pending": queued, not delivered.
      _throwIfGatewayRefused(response);
    } on DioException catch (e) {
      throw _gatewayException(e);
    }
  }

  @override
  Future<void> sendEmail({
    required String emailAddress,
    required String subject,
    required String body,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiConstants.sendEmail,
        data: {
          'EmailAddress': emailAddress,
          'EmailSubject': subject,
          'EmailBody': body,
        },
        options: _unlogged,
      );

      // A SAMP write answers HTTP 200 whether or not it did the job. This one's
      // success wording is unknown, so only an explicit "Gagal" counts as a
      // refusal, as for marking a message read.
      if (SampEnvelope.message(response)?.toLowerCase() == 'gagal') {
        throw ServerException(
          message: _refusalReason(response),
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  /// The server's own reason for a refusal — `Data[0].ResultMessage` — or a
  /// plain fallback when it gave none.
  String _refusalReason(Response<dynamic> response) {
    try {
      final reason = SampEnvelope.first(response)['ResultMessage'];
      if (reason is String && reason.trim().isNotEmpty) return reason.trim();
    } on ServerException {
      // No Data row to read a reason from.
    }
    return 'Gagal mengirim kode verifikasi';
  }

  /// A 2xx answer whose `status` says the message was not taken, with the
  /// gateway's own `message` as the reason. Anything that is not a JSON record
  /// with such a status — including "pending" — is let through.
  static void _throwIfGatewayRefused(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map) return;

    final status = body['status'];
    if (status is! String ||
        !_refusedStatuses.contains(status.trim().toLowerCase())) {
      return;
    }

    final said = body['message'];
    throw ServerException(
      message: said is String && said.trim().isNotEmpty
          ? said.trim()
          : 'Gagal mengirim pesan WhatsApp',
      statusCode: response.statusCode,
    );
  }

  /// What a failed gateway request means.
  ///
  /// Not [SampEnvelope.error]: that reads a 401 as an expired member session,
  /// and a 401 from the gateway is about the gateway, not the member.
  static Exception _gatewayException(DioException e) {
    switch (e.type) {
      // Could not get to the gateway at all.
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.badCertificate:
        return NetworkException(message: e.message ?? 'No connection');

      // Got there, and it did not answer in time.
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ServerException(
          message: 'Layanan WhatsApp terlalu lama merespons',
        );

      // It answered with an error: use its own words when it gave them as
      // JSON, and the status otherwise.
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final body = e.response?.data;
        final said = body is Map && body['message'] is String
            ? (body['message'] as String)
            : null;
        return ServerException(
          message: said != null && said.trim().isNotEmpty
              ? said.trim()
              : 'Gagal mengirim pesan WhatsApp (HTTP $status)',
          statusCode: status,
        );

      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return ServerException(
          message: e.message ?? 'Gagal mengirim pesan WhatsApp',
        );
    }
  }
}

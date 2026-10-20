import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/chat_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';

/// Where Fima's answers come from.
abstract class ChatRemoteDataSource {
  /// Sends [question] to Fima and returns the text of her answer.
  ///
  /// Throws [NetworkException] when the service cannot be reached and
  /// [ServerException] when it cannot answer. Anything else it throws is
  /// treated as a failure too (see ChatRepositoryImpl), never allowed to reach
  /// the screen.
  Future<String> ask(String question);
}

/// Asks the real chat service — see [ChatConstants.askUrl] for what it takes
/// and what it answers.
class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final Dio _dio;

  ChatRemoteDataSourceImpl(this._dio);

  @override
  Future<String> ask(String question) async {
    try {
      final response = await _dio.post<dynamic>(
        ChatConstants.askUrl,
        data: {'question': question},
        // Longer than Dio's default: an answer is made on the spot, and takes
        // as long as it takes.
        options: Options(receiveTimeout: ChatConstants.replyTimeout),
      );

      return _answerIn(response);
    } on DioException catch (e) {
      throw _exceptionFor(e);
    }
  }

  /// The answer inside a `200` response, or a [ServerException] saying why it
  /// is not one.
  static String _answerIn(Response<dynamic> response) {
    final body = response.data;

    // Anything but JSON here — a proxy's page, an empty body — is not Fima.
    if (body is! Map) {
      throw ServerException(
        message: 'Unexpected reply from the chat service',
        statusCode: response.statusCode,
      );
    }

    final message = body['message'];
    final text = message is String ? message : null;

    // A refusal, with its reason in the message.
    if (body['status'] != true) {
      throw ServerException(
        message: text != null && text.trim().isNotEmpty
            ? text
            : 'The chat service did not answer',
        statusCode: response.statusCode,
      );
    }

    if (text == null) {
      throw ServerException(
        message: 'The chat service sent no answer',
        statusCode: response.statusCode,
      );
    }

    // Blank is for the repository to refuse: it is one rule for every source.
    return text;
  }

  /// What a failed request means, as the data layer's own exceptions.
  static Exception _exceptionFor(DioException e) {
    switch (e.type) {
      // Could not get to the service at all.
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.badCertificate:
        return NetworkException(message: e.message ?? 'No connection');

      // Got there, and it did not answer in time.
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ServerException(
          message: 'The chat service took too long to answer',
        );

      // It answered with an error. The body of that is usually an HTML page,
      // which is no use to anybody: use the service's own words only when it
      // gave them as JSON.
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final body = e.response?.data;
        final said = body is Map && body['message'] is String
            ? (body['message'] as String)
            : null;
        return ServerException(
          message: said != null && said.trim().isNotEmpty
              ? said
              : 'The chat service failed (HTTP $status)',
          statusCode: status,
        );

      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return ServerException(message: e.message ?? 'Request failed');
    }
  }
}

import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';

/// Unwraps the Yamaha SAMP response envelope.
///
/// Every `/apiSAMP/*` endpoint is a POST that answers with the same shape:
///
/// ```json
/// { "Code": "100", "Msg": "Sukses", "Data": [ { ...record... } ] }
/// ```
///
/// Records always arrive inside a `Data` **array**, even when the caller wants
/// a single record — hence [first] as well as [rows].
///
/// **Why this exists:** before it, each data source subscripted
/// `response.data['data']` by hand, and they drifted — the home dashboard read
/// `'Data'` while the profile feature read `'data'` from the *same* endpoint,
/// so one of them could never have worked. Unwrapping in one place makes that
/// class of bug impossible.
///
/// Data sources should never subscript `response.data` directly; call [rows] or
/// [first], and funnel [DioException]s through [error].
class SampEnvelope {
  SampEnvelope._(); // static-only class — never instantiated

  /// Accepted spellings of the payload key, most likely first.
  /// The backend uses `Data`; `data` is tolerated so a casing change upstream
  /// degrades into a working request rather than a runtime type error.
  static const List<String> _dataKeys = ['Data', 'data'];

  /// Accepted spellings of the human-readable message key.
  static const List<String> _messageKeys = ['Msg', 'msg', 'Message', 'message'];

  /// Returns every record in the envelope's `Data` array.
  ///
  /// Throws [ServerException] when the body carries no `Data` array at all —
  /// that means the request was rejected, and the envelope's `Msg` explains why.
  /// An empty array is a valid result (no matching records) and returns `[]`.
  static List<Map<String, dynamic>> rows(Response<dynamic> response) {
    final raw = _pick(response.data, _dataKeys);

    if (raw is! List) {
      throw ServerException(
        message: _messageFrom(
          response.data,
          'Malformed response: no Data array',
        ),
        statusCode: response.statusCode,
      );
    }

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Returns the first record in the envelope's `Data` array.
  ///
  /// Throws [ServerException] when the array is empty, using the envelope's
  /// `Msg` as the message so the user sees the server's own wording.
  static Map<String, dynamic> first(Response<dynamic> response) {
    final records = rows(response);

    if (records.isEmpty) {
      throw ServerException(
        message: _messageFrom(response.data, 'No records returned'),
        statusCode: response.statusCode,
      );
    }

    return records.first;
  }

  /// Converts a [DioException] into the matching typed data-layer exception.
  ///
  /// Never returns — always throws, so callers need no `rethrow` afterwards:
  /// ```dart
  /// } on DioException catch (e) {
  ///   SampEnvelope.error(e);
  /// }
  /// ```
  static Never error(DioException e) {
    final statusCode = e.response?.statusCode;

    if (statusCode == 401) throw const UnauthorizedException();
    if (statusCode == 403) throw ForbiddenException();
    if (statusCode == 404) throw NotFoundException();

    throw ServerException(
      message: _messageFrom(
        e.response?.data,
        e.message ?? 'Unexpected server error',
      ),
      statusCode: statusCode,
    );
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  /// Returns the first of [keys] present in [body], or null if [body] is not a
  /// map or holds none of them.
  static Object? _pick(dynamic body, List<String> keys) {
    if (body is! Map) return null;

    for (final key in keys) {
      if (body.containsKey(key)) return body[key];
    }
    return null;
  }

  /// Pulls the server's own message out of [body], falling back to [orElse]
  /// when the body is absent, unparsed, or carries a blank message.
  static String _messageFrom(dynamic body, String orElse) {
    final message = _pick(body, _messageKeys);

    return message is String && message.trim().isNotEmpty ? message : orElse;
  }
}

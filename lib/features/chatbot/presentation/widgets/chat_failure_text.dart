import 'package:fix_up_moto/core/error/failures.dart';

/// Why a message did not go through, in words for the member.
///
/// Deliberately not [Failure.message]: that is whatever the data layer
/// reported — often English, or the server's own wording — where this is
/// short, calm and the same wherever it is shown. [failure] is null when the
/// reason is not known.
String chatFailureText(Failure? failure) => switch (failure) {
  NetworkFailure() => 'Tidak ada koneksi internet',
  ServerFailure() => 'Fima sedang bermasalah',
  AuthFailure() => 'Sesi berakhir, silakan masuk lagi',
  _ => 'Pesan belum terkirim',
};

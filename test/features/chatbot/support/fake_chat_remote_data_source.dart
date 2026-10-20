import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/features/chatbot/data/datasources/chat_remote_data_source.dart';

/// A stand-in for the chat service, for tests: it answers every question with a
/// sample, after a short wait like a real answer would take, and can be made to
/// fail on demand.
///
/// This used to be what the app ran on while the real service was not ready;
/// it now lives with the tests that still use it.
///
/// To get its other behaviours, ask one of these as the question:
/// - `/error`   — the service fails (HTTP 500)
/// - `/offline` — there is no connection
/// - `/kosong`  — the service answers with nothing
/// - `/panjang` — a long, multi-paragraph answer
/// - `/lambat`  — a slow answer ([slowDelay])
class FakeChatRemoteDataSource implements ChatRemoteDataSource {
  /// How long a normal answer takes.
  final Duration delay;

  const FakeChatRemoteDataSource({
    this.delay = const Duration(milliseconds: 1200),
  });

  /// How long `/lambat` takes.
  static const Duration slowDelay = Duration(seconds: 8);

  static const String longAnswer =
      'Ini contoh jawaban panjang dari Fima, supaya terlihat bagaimana teks '
      'yang banyak ditampilkan di dalam gelembung chat.\n\n'
      'Paragraf kedua ada di baris baru. Kata yang panjang turun ke baris '
      'berikutnya dengan rapi, dan gelembung tidak pernah lebih lebar dari '
      'layar.\n\n'
      '1. Poin pertama\n'
      '2. Poin kedua\n'
      '3. Poin ketiga\n\n'
      'Jawaban sebenarnya akan muncul setelah layanan chat tersambung.';

  @override
  Future<String> ask(String question) async {
    final trigger = question.trim().toLowerCase();

    await Future<void>.delayed(trigger == '/lambat' ? slowDelay : delay);

    switch (trigger) {
      case '/error':
        throw const ServerException(
          message: 'Simulated server error',
          statusCode: 500,
        );
      case '/offline':
        throw const NetworkException(message: 'Simulated: no connection');
      case '/kosong':
        return '';
      case '/panjang':
        return longAnswer;
      default:
        return 'Ini contoh jawaban Fima untuk: “${question.trim()}”. '
            'Jawaban sebenarnya akan muncul setelah layanan chat tersambung.';
    }
  }
}

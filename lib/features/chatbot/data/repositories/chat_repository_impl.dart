import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/chatbot/data/datasources/chat_remote_data_source.dart';
import 'package:fix_up_moto/features/chatbot/domain/entities/chat_message.dart';
import 'package:fix_up_moto/features/chatbot/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ChatRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  // The conversation is kept in memory for the app session, for one member at
  // a time: saving for a different member replaces it, and loading for one who
  // does not own it finds nothing, so a member never sees another's chat.
  String? _historyOwner;
  List<ChatMessage> _history = const [];

  @override
  Future<Either<Failure, String>> ask(String question) async {
    // Without a connection there is no point sending anything.
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    try {
      final answer = (await remoteDataSource.ask(question)).trim();

      if (answer.isEmpty) {
        return const Left(ServerFailure('Fima tidak mengirim jawaban'));
      }
      return Right(answer);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(AuthFailure('Session expired. Please sign in again.'));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (_) {
      // Whatever else goes wrong below this line (a reply in a shape nobody
      // planned for, say) is still just "no answer", not a crash on screen.
      return const Left(ServerFailure('Terjadi kesalahan tak terduga'));
    }
  }

  @override
  List<ChatMessage> loadHistory(String memberId) =>
      _historyOwner == memberId ? _history : const [];

  @override
  void saveHistory(String memberId, List<ChatMessage> messages) {
    _historyOwner = memberId;
    _history = List.unmodifiable(messages);
  }
}

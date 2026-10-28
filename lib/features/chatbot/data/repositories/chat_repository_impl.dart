import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/chatbot/data/datasources/chat_knowledge_data_source.dart';
import 'package:fix_up_moto/features/chatbot/data/datasources/chat_remote_data_source.dart';
import 'package:fix_up_moto/features/chatbot/domain/entities/chat_message.dart';
import 'package:fix_up_moto/features/chatbot/domain/entities/fima_apology.dart';
import 'package:fix_up_moto/features/chatbot/domain/entities/knowledge_base.dart';
import 'package:fix_up_moto/features/chatbot/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  /// Fima's own knowledge, for the questions the service apologises for. Null
  /// means she has none, and the apology stands.
  final ChatKnowledgeDataSource? knowledgeDataSource;

  ChatRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    this.knowledgeDataSource,
  });

  // Read on the first apology and kept: the file is bundled with the app, so it
  // cannot change while it runs.
  Future<KnowledgeBase>? _knowledge;

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

      // The service has nothing to say: see whether Fima's own file does. If it
      // does not either, the apology is the answer, as it always was.
      if (isFimaApology(answer)) {
        final known = (await _knowledgeBase()).answerFor(question);
        if (known != null) return Right(known);
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

  Future<KnowledgeBase> _knowledgeBase() => _knowledge ??= _readKnowledge();

  /// The file, or nothing at all when there is none or it cannot be read — a
  /// missing file must never cost the member the answer they already have.
  Future<KnowledgeBase> _readKnowledge() async {
    final source = knowledgeDataSource;
    if (source == null) return KnowledgeBase.empty;

    try {
      return KnowledgeBase.parse(await source.load());
    } catch (_) {
      return KnowledgeBase.empty;
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

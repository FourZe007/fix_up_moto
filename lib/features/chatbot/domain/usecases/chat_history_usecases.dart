import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/chatbot/domain/entities/chat_message.dart';
import 'package:fix_up_moto/features/chatbot/domain/repositories/chat_repository.dart';

/// Reads the conversation kept for a member earlier in this app session.
///
/// The chat page is a top-level route with its own bloc per visit, so without
/// this, backing out to Home would wipe the conversation.
class GetChatHistoryUseCase
    extends UseCase<List<ChatMessage>, ChatHistoryParams> {
  final ChatRepository repository;
  GetChatHistoryUseCase(this.repository);

  @override
  Future<Either<Failure, List<ChatMessage>>> call(
    ChatHistoryParams params,
  ) async => Right(repository.loadHistory(params.memberId));
}

class ChatHistoryParams extends Equatable {
  final String memberId;

  const ChatHistoryParams(this.memberId);

  @override
  List<Object> get props => [memberId];
}

/// Keeps a member's conversation so [GetChatHistoryUseCase] can bring it back.
class SaveChatHistoryUseCase extends UseCase<void, SaveChatHistoryParams> {
  final ChatRepository repository;
  SaveChatHistoryUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(SaveChatHistoryParams params) async {
    repository.saveHistory(params.memberId, params.messages);
    return const Right(null);
  }
}

class SaveChatHistoryParams extends Equatable {
  final String memberId;
  final List<ChatMessage> messages;

  const SaveChatHistoryParams(this.memberId, this.messages);

  @override
  List<Object> get props => [memberId, messages];
}

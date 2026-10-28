import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/chatbot/domain/entities/chat_message.dart';

abstract class ChatRepository {
  /// Asks Fima [question] and returns her answer, or why there is none.
  ///
  /// An answer that is blank counts as no answer (a [ServerFailure]).
  ///
  /// When the service apologises instead of answering, Fima's own knowledge is
  /// tried: a topic that fits the question is her answer. With none that fits,
  /// the apology comes back as it was (see isFimaApology).
  Future<Either<Failure, String>> ask(String question);

  /// The conversation [memberId] had earlier in this app session, oldest
  /// first — empty when there is none, or when the one kept belongs to someone
  /// else (a different member signed in since).
  List<ChatMessage> loadHistory(String memberId);

  /// Keeps [messages] as [memberId]'s conversation for the rest of the
  /// session, replacing whatever was kept before.
  void saveHistory(String memberId, List<ChatMessage> messages);
}

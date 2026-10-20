import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/core/constants/chat_constants.dart';
import 'package:fix_up_moto/features/chatbot/domain/entities/chat_message.dart';
import 'package:fix_up_moto/features/chatbot/domain/usecases/ask_fima_usecase.dart';
import 'package:fix_up_moto/features/chatbot/domain/usecases/chat_history_usecases.dart';
import 'chat_event.dart';
import 'chat_state.dart';

/// Runs the chat with Fima for [ChatbotPage].
///
/// Page-scoped (a factory in the DI container), like every other page's bloc.
/// What must outlive a visit — the conversation — is kept by the repository for
/// the rest of the session, and brought back by [ChatStarted].
///
/// One question is in flight at a time: while Fima is answering, further sends
/// and retries are ignored. Every way a question can go wrong ends the same
/// way — the member's message is marked failed, and can be sent again.
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final AskFimaUseCase _ask;
  final GetChatHistoryUseCase _getHistory;
  final SaveChatHistoryUseCase _saveHistory;

  /// Injected so tests get fixed times and ids.
  final DateTime Function() _now;
  final String Function() _newId;

  String _memberId = '';

  ChatBloc({
    required AskFimaUseCase ask,
    required GetChatHistoryUseCase getHistory,
    required SaveChatHistoryUseCase saveHistory,
    DateTime Function()? now,
    String Function()? newId,
  }) : _ask = ask,
       _getHistory = getHistory,
       _saveHistory = saveHistory,
       _now = now ?? DateTime.now,
       _newId = newId ?? _defaultId,
       super(const ChatState()) {
    on<ChatStarted>(_onStarted);
    on<ChatMessageSent>(_onSent);
    on<ChatRetryRequested>(_onRetry);
  }

  /// Ids only need to be unique within a conversation; the microsecond clock
  /// plus a running number is enough even for two messages in the same tick.
  static int _sequence = 0;
  static String _defaultId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  Future<void> _onStarted(ChatStarted event, Emitter<ChatState> emit) async {
    _memberId = event.memberId;

    final result = await _getHistory(ChatHistoryParams(event.memberId));
    final history = result.getOrElse(() => const []);

    // A message still "sending" was left that way by a visit that ended
    // before its answer came back; that answer is not coming, so it is a
    // failed message like any other, and can be sent again.
    emit(
      ChatState(
        messages: [
          for (final message in history)
            message.status == ChatMessageStatus.sending
                ? message.asFailed()
                : message,
        ],
        loaded: true,
      ),
    );
  }

  Future<void> _onSent(ChatMessageSent event, Emitter<ChatState> emit) async {
    if (state.replying) return;

    final text = event.text.trim();
    if (text.isEmpty || text.length > ChatConstants.maxMessageLength) return;

    final message = ChatMessage(
      id: _newId(),
      text: text,
      sender: ChatSender.user,
      status: ChatMessageStatus.sending,
      createdAt: _now(),
    );

    await _answer(emit, [...state.messages, message], message);
  }

  Future<void> _onRetry(
    ChatRetryRequested event,
    Emitter<ChatState> emit,
  ) async {
    if (state.replying) return;

    final index = state.messages.indexWhere(
      (m) =>
          m.id == event.messageId &&
          m.isFromUser &&
          m.status == ChatMessageStatus.failed,
    );
    if (index < 0) return;

    final retried = state.messages[index].asSending();
    await _answer(emit, [...state.messages]..[index] = retried, retried);
  }

  /// Shows [messages] with [question] marked as sending, asks Fima, and settles
  /// the conversation on what comes back: the question sent and her answer
  /// right after it, or the question failed.
  Future<void> _answer(
    Emitter<ChatState> emit,
    List<ChatMessage> messages,
    ChatMessage question,
  ) async {
    emit(state.copyWith(messages: messages, replying: true));
    _save(messages);

    final result = await _ask(AskFimaParams(question.text));

    // Built from `state`, which still holds this question even if the page
    // was left while it was out: the answer is then saved for the next visit
    // (the emit below does nothing on a closed bloc).
    final settled = [...state.messages];
    final index = settled.indexWhere((m) => m.id == question.id);
    if (index < 0) return;

    result.fold(
      (failure) => settled[index] = settled[index].asFailed(failure),
      (answer) {
        settled[index] = settled[index].asSent();
        // Right after the question it answers, which for a retry is not the end
        // of the conversation.
        settled.insert(
          index + 1,
          ChatMessage(
            id: _newId(),
            text: answer,
            sender: ChatSender.fima,
            status: ChatMessageStatus.sent,
            createdAt: _now(),
          ),
        );
      },
    );

    _save(settled);
    emit(state.copyWith(messages: settled, replying: false));
  }

  void _save(List<ChatMessage> messages) =>
      _saveHistory(SaveChatHistoryParams(_memberId, messages));
}

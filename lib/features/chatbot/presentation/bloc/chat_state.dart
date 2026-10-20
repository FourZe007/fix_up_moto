import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/features/chatbot/domain/entities/chat_message.dart';

class ChatState extends Equatable {
  /// The conversation, oldest first.
  final List<ChatMessage> messages;

  /// A question is out and its answer has not come back. Only one is ever in
  /// flight: nothing else can be sent until it is.
  final bool replying;

  /// The earlier conversation has been looked up. False only for a moment on
  /// opening, so the page does not flash its empty-chat greeting before the
  /// messages that belong there appear.
  final bool loaded;

  const ChatState({
    this.messages = const [],
    this.replying = false,
    this.loaded = false,
  });

  ChatState copyWith({List<ChatMessage>? messages, bool? replying}) =>
      ChatState(
        messages: messages ?? this.messages,
        replying: replying ?? this.replying,
        loaded: loaded,
      );

  @override
  List<Object?> get props => [messages, replying, loaded];
}

import 'package:equatable/equatable.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// The page opened for [memberId]: bring back the conversation kept for them
/// earlier in this session, if any.
final class ChatStarted extends ChatEvent {
  final String memberId;

  const ChatStarted(this.memberId);

  @override
  List<Object?> get props => [memberId];
}

/// The member sent [text] as a question to Fima.
final class ChatMessageSent extends ChatEvent {
  final String text;

  const ChatMessageSent(this.text);

  @override
  List<Object?> get props => [text];
}

/// The member tapped "try again" on a message that did not go through.
final class ChatRetryRequested extends ChatEvent {
  final String messageId;

  const ChatRetryRequested(this.messageId);

  @override
  List<Object?> get props => [messageId];
}

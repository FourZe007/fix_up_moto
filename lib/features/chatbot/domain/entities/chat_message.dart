import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';

/// Who wrote a [ChatMessage].
enum ChatSender { user, fima }

/// Where a message is on its way to being answered.
///
/// Fima's own messages are always [sent]; the other two only matter for the
/// member's.
enum ChatMessageStatus {
  /// Asked, and no answer yet.
  sending,

  /// Delivered (and, for the member's messages, answered).
  sent,

  /// Could not be delivered; the member can try again.
  failed,
}

/// One bubble in the chat with Fima.
class ChatMessage extends Equatable {
  final String id;
  final String text;
  final ChatSender sender;
  final ChatMessageStatus status;

  /// Why a [failed] message did not go through, or null when that is not
  /// known (for example, the page was left while it was still being sent).
  final Failure? failure;

  final DateTime createdAt;

  /// Fima's answer is an apology: she had nothing to say to the question. The
  /// chat then offers the member a person to talk to. Only ever set on her
  /// messages.
  final bool unanswered;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.status,
    required this.createdAt,
    this.failure,
    this.unanswered = false,
  });

  bool get isFromUser => sender == ChatSender.user;

  /// This message, being sent (again) — its old [failure], if any, is dropped.
  ChatMessage asSending() => ChatMessage(
    id: id,
    text: text,
    sender: sender,
    status: ChatMessageStatus.sending,
    createdAt: createdAt,
  );

  ChatMessage asSent() => ChatMessage(
    id: id,
    text: text,
    sender: sender,
    status: ChatMessageStatus.sent,
    createdAt: createdAt,
  );

  ChatMessage asFailed([Failure? failure]) => ChatMessage(
    id: id,
    text: text,
    sender: sender,
    status: ChatMessageStatus.failed,
    createdAt: createdAt,
    failure: failure,
  );

  @override
  List<Object?> get props => [
    id,
    text,
    sender,
    status,
    failure,
    createdAt,
    unanswered,
  ];
}

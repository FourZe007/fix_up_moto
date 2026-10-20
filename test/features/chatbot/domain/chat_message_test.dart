import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/chatbot/domain/entities/chat_message.dart';

void main() {
  final time = DateTime(2026, 10, 20, 9, 30);
  final message = ChatMessage(
    id: 'm1',
    text: 'Halo',
    sender: ChatSender.user,
    status: ChatMessageStatus.sending,
    createdAt: time,
  );

  test('a member\'s message is from the user, Fima\'s is not', () {
    expect(message.isFromUser, isTrue);
    expect(
      ChatMessage(
        id: 'm2',
        text: 'Halo juga',
        sender: ChatSender.fima,
        status: ChatMessageStatus.sent,
        createdAt: time,
      ).isFromUser,
      isFalse,
    );
  });

  group('changing status', () {
    test('keeps everything else about the message', () {
      for (final changed in [
        message.asSent(),
        message.asFailed(),
        message.asSending(),
      ]) {
        expect(changed.id, 'm1');
        expect(changed.text, 'Halo');
        expect(changed.sender, ChatSender.user);
        expect(changed.createdAt, time);
      }
    });

    test('sets the status asked for', () {
      expect(message.asSent().status, ChatMessageStatus.sent);
      expect(message.asFailed().status, ChatMessageStatus.failed);
      expect(message.asFailed().asSending().status, ChatMessageStatus.sending);
    });

    test('remembers why a message failed, and forgets it when it is sent '
        'again', () {
      const failure = NetworkFailure('offline');
      final failed = message.asFailed(failure);

      expect(failed.failure, failure);
      expect(failed.asSending().failure, isNull);
      expect(failed.asSending().asSent().failure, isNull);
    });

    test('a failure with no known reason is allowed', () {
      expect(message.asFailed().failure, isNull);
    });
  });

  test('is equal to another with the same everything', () {
    expect(
      message.asFailed(const NetworkFailure('x')),
      message.asFailed(const NetworkFailure('x')),
    );
    expect(
      message.asFailed(const NetworkFailure('x')),
      isNot(message.asFailed(const NetworkFailure('y'))),
    );
    expect(message.asSent(), isNot(message.asFailed()));
  });
}

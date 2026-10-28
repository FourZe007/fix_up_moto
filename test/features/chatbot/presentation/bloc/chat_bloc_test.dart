import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/chat_constants.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/chatbot/domain/entities/chat_message.dart';
import 'package:fix_up_moto/features/chatbot/domain/usecases/ask_fima_usecase.dart';
import 'package:fix_up_moto/features/chatbot/domain/usecases/chat_history_usecases.dart';
import 'package:fix_up_moto/features/chatbot/presentation/bloc/chat_bloc.dart';
import 'package:fix_up_moto/features/chatbot/presentation/bloc/chat_event.dart';
import 'package:fix_up_moto/features/chatbot/presentation/bloc/chat_state.dart';

class MockAskFima extends Mock implements AskFimaUseCase {}

class MockGetChatHistory extends Mock implements GetChatHistoryUseCase {}

class MockSaveChatHistory extends Mock implements SaveChatHistoryUseCase {}

void main() {
  late MockAskFima ask;
  late MockGetChatHistory getHistory;
  late MockSaveChatHistory saveHistory;
  late int idCounter;

  final time = DateTime(2026, 10, 20, 9, 30);

  setUpAll(() {
    registerFallbackValue(const AskFimaParams(''));
    registerFallbackValue(const ChatHistoryParams(''));
    registerFallbackValue(const SaveChatHistoryParams('', []));
  });

  setUp(() {
    ask = MockAskFima();
    getHistory = MockGetChatHistory();
    saveHistory = MockSaveChatHistory();
    idCounter = 0;

    when(() => getHistory(any())).thenAnswer((_) async => const Right([]));
    when(() => saveHistory(any())).thenAnswer((_) async => const Right(null));
  });

  ChatBloc build() => ChatBloc(
    ask: ask,
    getHistory: getHistory,
    saveHistory: saveHistory,
    now: () => time,
    newId: () => 'm${++idCounter}',
  );

  /// The member's message.
  ChatMessage user(
    String id,
    String text,
    ChatMessageStatus status, {
    Failure? failure,
  }) => ChatMessage(
    id: id,
    text: text,
    sender: ChatSender.user,
    status: status,
    failure: failure,
    createdAt: time,
  );

  /// Fima's answer.
  ChatMessage fima(String id, String text, {bool unanswered = false}) =>
      ChatMessage(
        id: id,
        text: text,
        sender: ChatSender.fima,
        status: ChatMessageStatus.sent,
        createdAt: time,
        unanswered: unanswered,
      );

  void givenAnswer(String answer) =>
      when(() => ask(any())).thenAnswer((_) async => Right(answer));

  void givenFailure(Failure failure) =>
      when(() => ask(any())).thenAnswer((_) async => Left(failure));

  /// What the bloc last saved for the conversation.
  List<ChatMessage> lastSaved() =>
      (verify(() => saveHistory(captureAny())).captured.last
              as SaveChatHistoryParams)
          .messages;

  const loadedEmpty = ChatState(loaded: true);

  group('ChatStarted', () {
    blocTest<ChatBloc, ChatState>(
      'opens an empty conversation when nothing was kept',
      build: build,
      act: (bloc) => bloc.add(const ChatStarted('M-1')),
      expect: () => [loadedEmpty],
      verify: (_) =>
          verify(() => getHistory(const ChatHistoryParams('M-1'))).called(1),
    );

    blocTest<ChatBloc, ChatState>(
      'brings back the conversation that was kept, in order',
      setUp: () => when(() => getHistory(any())).thenAnswer(
        (_) async => Right([
          user('a', 'Halo', ChatMessageStatus.sent),
          fima('b', 'Hai'),
        ]),
      ),
      build: build,
      act: (bloc) => bloc.add(const ChatStarted('M-1')),
      expect: () => [
        ChatState(
          messages: [
            user('a', 'Halo', ChatMessageStatus.sent),
            fima('b', 'Hai'),
          ],
          loaded: true,
        ),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'turns a message left "sending" into a failed one — its answer was '
      'lost when the page was left, and it can be sent again',
      setUp: () => when(() => getHistory(any())).thenAnswer(
        (_) async => Right([user('a', 'Halo', ChatMessageStatus.sending)]),
      ),
      build: build,
      act: (bloc) => bloc.add(const ChatStarted('M-1')),
      expect: () => [
        ChatState(
          messages: [user('a', 'Halo', ChatMessageStatus.failed)],
          loaded: true,
        ),
      ],
    );

    test('is not "loaded" until it has looked', () {
      expect(build().state.loaded, isFalse);
    });
  });

  group('sending a question', () {
    blocTest<ChatBloc, ChatState>(
      'shows it at once as sending, then settles it as sent with Fima\'s answer '
      'right after',
      setUp: () => givenAnswer('Jawaban'),
      build: build,
      act: (bloc) => bloc
        ..add(const ChatStarted('M-1'))
        ..add(const ChatMessageSent('Halo')),
      skip: 1,
      expect: () => [
        ChatState(
          messages: [user('m1', 'Halo', ChatMessageStatus.sending)],
          replying: true,
          loaded: true,
        ),
        ChatState(
          messages: [
            user('m1', 'Halo', ChatMessageStatus.sent),
            fima('m2', 'Jawaban'),
          ],
          loaded: true,
        ),
      ],
      verify: (_) => verify(() => ask(const AskFimaParams('Halo'))).called(1),
    );

    blocTest<ChatBloc, ChatState>(
      'keeps the conversation as it goes, for the member who is chatting',
      setUp: () => givenAnswer('Jawaban'),
      build: build,
      act: (bloc) => bloc
        ..add(const ChatStarted('M-7'))
        ..add(const ChatMessageSent('Halo')),
      verify: (_) {
        final calls = verify(
          () => saveHistory(captureAny()),
        ).captured.cast<SaveChatHistoryParams>();

        // Once as soon as it is out, once when it is answered.
        expect(calls, hasLength(2));
        expect(calls.every((c) => c.memberId == 'M-7'), isTrue);
        expect(calls.first.messages, [
          user('m1', 'Halo', ChatMessageStatus.sending),
        ]);
        expect(calls.last.messages, [
          user('m1', 'Halo', ChatMessageStatus.sent),
          fima('m2', 'Jawaban'),
        ]);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'asks with the text trimmed, and shows it trimmed',
      setUp: () => givenAnswer('Jawaban'),
      build: build,
      act: (bloc) => bloc
        ..add(const ChatStarted('M-1'))
        ..add(const ChatMessageSent('  Halo  \n')),
      verify: (bloc) {
        verify(() => ask(const AskFimaParams('Halo'))).called(1);
        expect(bloc.state.messages.first.text, 'Halo');
      },
    );

    for (final blank in ['', '   ', '\n\t  ']) {
      blocTest<ChatBloc, ChatState>(
        'ignores a blank question (${blank.codeUnits})',
        build: build,
        act: (bloc) => bloc
          ..add(const ChatStarted('M-1'))
          ..add(ChatMessageSent(blank)),
        expect: () => [loadedEmpty],
        verify: (_) => verifyNever(() => ask(any())),
      );
    }

    blocTest<ChatBloc, ChatState>(
      'ignores a question over the limit...',
      build: build,
      act: (bloc) => bloc
        ..add(const ChatStarted('M-1'))
        ..add(ChatMessageSent('x' * (ChatConstants.maxMessageLength + 1))),
      expect: () => [loadedEmpty],
      verify: (_) => verifyNever(() => ask(any())),
    );

    blocTest<ChatBloc, ChatState>(
      '...but sends one exactly at it',
      setUp: () => givenAnswer('Jawaban'),
      build: build,
      act: (bloc) => bloc
        ..add(const ChatStarted('M-1'))
        ..add(ChatMessageSent('x' * ChatConstants.maxMessageLength)),
      verify: (_) => verify(() => ask(any())).called(1),
    );

    test(
      'puts every message in at the time it was written, with its own id',
      () async {
        givenAnswer('Jawaban');
        final bloc = build()..add(const ChatStarted('M-1'));
        bloc.add(const ChatMessageSent('Satu'));
        await pumpEventQueue();
        bloc.add(const ChatMessageSent('Dua'));
        await pumpEventQueue();

        final messages = bloc.state.messages;
        expect(messages.map((m) => m.text), [
          'Satu',
          'Jawaban',
          'Dua',
          'Jawaban',
        ]);
        expect(messages.map((m) => m.id).toSet(), hasLength(4));
        expect(messages.every((m) => m.createdAt == time), isTrue);
        await bloc.close();
      },
    );

    test('makes ids that do not repeat, without any help', () async {
      givenAnswer('Jawaban');
      final bloc = ChatBloc(
        ask: ask,
        getHistory: getHistory,
        saveHistory: saveHistory,
      )..add(const ChatStarted('M-1'));

      for (var i = 0; i < 5; i++) {
        bloc.add(ChatMessageSent('Pertanyaan $i'));
        await pumpEventQueue();
      }

      expect(bloc.state.messages, hasLength(10));
      expect(bloc.state.messages.map((m) => m.id).toSet(), hasLength(10));
      await bloc.close();
    });
  });

  group('an answer that is an apology', () {
    const apology =
        'Mohon Maaf untuk saat ini saya belum bisa menjawab pertanyaan anda.';

    blocTest<ChatBloc, ChatState>(
      'is marked unanswered, so the chat can offer a person to talk to',
      setUp: () => givenAnswer(apology),
      build: build,
      act: (bloc) => bloc
        ..add(const ChatStarted('M-1'))
        ..add(const ChatMessageSent('Berapa poin saya?')),
      skip: 2,
      expect: () => [
        ChatState(
          messages: [
            user('m1', 'Berapa poin saya?', ChatMessageStatus.sent),
            fima('m2', apology, unanswered: true),
          ],
          loaded: true,
        ),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'keeps that mark in the conversation it saves for the next visit',
      setUp: () => givenAnswer(apology),
      build: build,
      act: (bloc) => bloc
        ..add(const ChatStarted('M-1'))
        ..add(const ChatMessageSent('Berapa poin saya?')),
      verify: (_) => expect(lastSaved().last, fima('m2', apology, unanswered: true)),
    );

    blocTest<ChatBloc, ChatState>(
      'is not marked once Fima could answer it herself: that answer is not an '
      'apology',
      setUp: () => givenAnswer('Poin didapat dari setiap servis.'),
      build: build,
      act: (bloc) => bloc
        ..add(const ChatStarted('M-1'))
        ..add(const ChatMessageSent('Bagaimana cara dapat poin?')),
      skip: 2,
      expect: () => [
        ChatState(
          messages: [
            user('m1', 'Bagaimana cara dapat poin?', ChatMessageStatus.sent),
            fima('m2', 'Poin didapat dari setiap servis.'),
          ],
          loaded: true,
        ),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'is marked on a retry too, right after the question it answers',
      setUp: () => givenAnswer(apology),
      seed: () => ChatState(
        messages: [
          user(
            'a',
            'Berapa poin saya?',
            ChatMessageStatus.failed,
            failure: const NetworkFailure('offline'),
          ),
        ],
        loaded: true,
      ),
      build: build,
      act: (bloc) => bloc.add(const ChatRetryRequested('a')),
      skip: 1,
      expect: () => [
        ChatState(
          messages: [
            user('a', 'Berapa poin saya?', ChatMessageStatus.sent),
            fima('m1', apology, unanswered: true),
          ],
          loaded: true,
        ),
      ],
    );
  });

  group('while Fima is answering', () {
    late Completer<Either<Failure, String>> pending;

    setUp(() {
      pending = Completer<Either<Failure, String>>();
      when(() => ask(any())).thenAnswer((_) => pending.future);
    });

    test('says so, and takes no second question', () async {
      final bloc = build()..add(const ChatStarted('M-1'));
      bloc.add(const ChatMessageSent('Satu'));
      await pumpEventQueue();

      expect(bloc.state.replying, isTrue);

      bloc.add(const ChatMessageSent('Dua'));
      await pumpEventQueue();

      // Only the first went out, and the second left no trace.
      verify(() => ask(any())).called(1);
      expect(bloc.state.messages.map((m) => m.text), ['Satu']);

      pending.complete(const Right('Jawaban'));
      await pumpEventQueue();

      expect(bloc.state.replying, isFalse);
      expect(bloc.state.messages.map((m) => m.text), ['Satu', 'Jawaban']);
      await bloc.close();
    });

    test('takes no retry either', () async {
      when(() => getHistory(any())).thenAnswer(
        (_) async => Right([user('old', 'Lama', ChatMessageStatus.failed)]),
      );
      final bloc = build()..add(const ChatStarted('M-1'));
      bloc.add(const ChatMessageSent('Baru'));
      await pumpEventQueue();

      bloc.add(const ChatRetryRequested('old'));
      await pumpEventQueue();

      verify(() => ask(any())).called(1);
      expect(
        bloc.state.messages.first.status,
        ChatMessageStatus.failed,
        reason: 'the old message is still failed, not being sent',
      );

      pending.complete(const Right('Jawaban'));
      await pumpEventQueue();
      await bloc.close();
    });

    test(
      'is over as soon as it answers, and the next question goes through',
      () async {
        final bloc = build()..add(const ChatStarted('M-1'));
        bloc.add(const ChatMessageSent('Satu'));
        await pumpEventQueue();
        pending.complete(const Right('Jawaban satu'));
        await pumpEventQueue();

        when(
          () => ask(any()),
        ).thenAnswer((_) async => const Right('Jawaban dua'));
        bloc.add(const ChatMessageSent('Dua'));
        await pumpEventQueue();

        expect(bloc.state.messages.map((m) => m.text), [
          'Satu',
          'Jawaban satu',
          'Dua',
          'Jawaban dua',
        ]);
        await bloc.close();
      },
    );
  });

  group('when the question cannot be answered', () {
    for (final failure in [
      const NetworkFailure('offline'),
      const ServerFailure('Boom', statusCode: 500),
      const AuthFailure('expired'),
    ]) {
      blocTest<ChatBloc, ChatState>(
        'marks it failed with ${failure.runtimeType}, adds no answer, and is '
        'ready for the next question',
        setUp: () => givenFailure(failure),
        build: build,
        act: (bloc) => bloc
          ..add(const ChatStarted('M-1'))
          ..add(const ChatMessageSent('Halo')),
        skip: 2,
        expect: () => [
          ChatState(
            messages: [
              user('m1', 'Halo', ChatMessageStatus.failed, failure: failure),
            ],
            loaded: true,
          ),
        ],
      );
    }

    test('keeps the failed message in the saved conversation', () async {
      givenFailure(const NetworkFailure('offline'));
      final bloc = build()..add(const ChatStarted('M-1'));
      bloc.add(const ChatMessageSent('Halo'));
      await pumpEventQueue();

      expect(lastSaved(), [
        user(
          'm1',
          'Halo',
          ChatMessageStatus.failed,
          failure: const NetworkFailure('offline'),
        ),
      ]);
      await bloc.close();
    });

    test('lets a new question be asked straight away', () async {
      givenFailure(const NetworkFailure('offline'));
      final bloc = build()..add(const ChatStarted('M-1'));
      bloc.add(const ChatMessageSent('Satu'));
      await pumpEventQueue();

      givenAnswer('Jawaban');
      bloc.add(const ChatMessageSent('Dua'));
      await pumpEventQueue();

      expect(bloc.state.messages.map((m) => (m.text, m.status)), [
        ('Satu', ChatMessageStatus.failed),
        ('Dua', ChatMessageStatus.sent),
        ('Jawaban', ChatMessageStatus.sent),
      ]);
      await bloc.close();
    });
  });

  group('ChatRetryRequested', () {
    final failure = const NetworkFailure('offline');

    blocTest<ChatBloc, ChatState>(
      'sends the failed message again and settles it on the answer',
      setUp: () {
        when(() => getHistory(any())).thenAnswer(
          (_) async => Right([
            user('a', 'Halo', ChatMessageStatus.failed, failure: failure),
          ]),
        );
        givenAnswer('Jawaban');
      },
      build: build,
      act: (bloc) => bloc
        ..add(const ChatStarted('M-1'))
        ..add(const ChatRetryRequested('a')),
      skip: 1,
      expect: () => [
        ChatState(
          // Sending again: the old failure is forgotten.
          messages: [user('a', 'Halo', ChatMessageStatus.sending)],
          replying: true,
          loaded: true,
        ),
        ChatState(
          messages: [
            user('a', 'Halo', ChatMessageStatus.sent),
            fima('m1', 'Jawaban'),
          ],
          loaded: true,
        ),
      ],
      verify: (_) => verify(() => ask(const AskFimaParams('Halo'))).called(1),
    );

    blocTest<ChatBloc, ChatState>(
      'puts the answer right after the message it answers, not at the end of '
      'the conversation',
      setUp: () {
        when(() => getHistory(any())).thenAnswer(
          (_) async => Right([
            user('a', 'Pertama', ChatMessageStatus.failed, failure: failure),
            user('b', 'Kedua', ChatMessageStatus.sent),
            fima('c', 'Jawaban kedua'),
          ]),
        );
        givenAnswer('Jawaban pertama');
      },
      build: build,
      act: (bloc) => bloc
        ..add(const ChatStarted('M-1'))
        ..add(const ChatRetryRequested('a')),
      verify: (bloc) {
        expect(bloc.state.messages.map((m) => m.text), [
          'Pertama',
          'Jawaban pertama',
          'Kedua',
          'Jawaban kedua',
        ]);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'fails again with the new reason when it still cannot be answered',
      setUp: () {
        when(() => getHistory(any())).thenAnswer(
          (_) async => Right([
            user('a', 'Halo', ChatMessageStatus.failed, failure: failure),
          ]),
        );
        givenFailure(const ServerFailure('Boom'));
      },
      build: build,
      act: (bloc) => bloc
        ..add(const ChatStarted('M-1'))
        ..add(const ChatRetryRequested('a')),
      verify: (bloc) {
        expect(bloc.state.messages.single.status, ChatMessageStatus.failed);
        expect(bloc.state.messages.single.failure, const ServerFailure('Boom'));
        expect(bloc.state.replying, isFalse);
      },
    );

    for (final (label, history, id) in [
      ('one that does not exist', <ChatMessage>[], 'nope'),
      (
        'a message that already went through',
        [user('a', 'Halo', ChatMessageStatus.sent)],
        'a',
      ),
      ('one of Fima\'s answers', [fima('a', 'Hai')], 'a'),
    ]) {
      blocTest<ChatBloc, ChatState>(
        'ignores a retry of $label',
        setUp: () => when(
          () => getHistory(any()),
        ).thenAnswer((_) async => Right(history)),
        build: build,
        act: (bloc) => bloc
          ..add(const ChatStarted('M-1'))
          ..add(ChatRetryRequested(id)),
        expect: () => [ChatState(messages: history, loaded: true)],
        verify: (_) => verifyNever(() => ask(any())),
      );
    }
  });

  group('leaving the page while a question is out', () {
    test('keeps the answer for the next visit, and does not break', () async {
      final pending = Completer<Either<Failure, String>>();
      when(() => ask(any())).thenAnswer((_) => pending.future);

      final bloc = build()..add(const ChatStarted('M-1'));
      bloc.add(const ChatMessageSent('Halo'));
      await pumpEventQueue();

      // The page is left: its bloc is closed with the question still out.
      await bloc.close();
      clearInteractions(saveHistory);

      pending.complete(const Right('Jawaban'));
      await pumpEventQueue();

      // The answer arrived to nobody on screen, but is kept: the conversation
      // the next visit loads has it.
      expect(lastSaved(), [
        user('m1', 'Halo', ChatMessageStatus.sent),
        fima('m2', 'Jawaban'),
      ]);
    });

    test('keeps a failure too', () async {
      final pending = Completer<Either<Failure, String>>();
      when(() => ask(any())).thenAnswer((_) => pending.future);

      final bloc = build()..add(const ChatStarted('M-1'));
      bloc.add(const ChatMessageSent('Halo'));
      await pumpEventQueue();
      await bloc.close();
      clearInteractions(saveHistory);

      pending.complete(const Left(NetworkFailure('offline')));
      await pumpEventQueue();

      expect(lastSaved().single.status, ChatMessageStatus.failed);
    });
  });
}

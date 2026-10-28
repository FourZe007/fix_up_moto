import 'dart:async';
import 'dart:math' as math;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/constants/chat_constants.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/chatbot/data/datasources/chat_knowledge_data_source.dart';
import 'package:fix_up_moto/features/chatbot/data/datasources/chat_remote_data_source.dart';
import '../../support/fake_chat_remote_data_source.dart';
import 'package:fix_up_moto/features/chatbot/data/repositories/chat_repository_impl.dart';
import 'package:fix_up_moto/features/chatbot/domain/entities/chat_message.dart';
import 'package:fix_up_moto/features/chatbot/domain/repositories/chat_repository.dart';
import 'package:fix_up_moto/features/chatbot/domain/usecases/ask_fima_usecase.dart';
import 'package:fix_up_moto/features/chatbot/domain/usecases/chat_history_usecases.dart';
import 'package:fix_up_moto/features/chatbot/presentation/bloc/chat_bloc.dart';
import 'package:fix_up_moto/features/chatbot/presentation/pages/chatbot_page.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/chat_empty_state.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/typing_indicator.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// A reply source the test controls: every question waits until the test
/// answers it, fails it, or leaves it hanging.
class ScriptedChatDataSource implements ChatRemoteDataSource {
  final questions = <String>[];
  final _calls = <Completer<String>>[];

  @override
  Future<String> ask(String question) {
    questions.add(question);
    final call = Completer<String>();
    _calls.add(call);
    return call.future;
  }

  /// Answers the most recent question.
  void answer(String text) => _calls.last.complete(text);

  /// Fails the most recent question.
  void fail(Object error) => _calls.last.completeError(error);
}

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// A connection that is always there.
class _Online implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

/// Fima's knowledge file, as the text it holds.
class _KnowledgeFile implements ChatKnowledgeDataSource {
  final String text;

  _KnowledgeFile(this.text);

  @override
  Future<String> load() async => text;
}

/// The chat's real layers (repository, use cases, bloc) over [source], and over
/// [knowledge] as Fima's own file when there is one.
void registerChat(ChatRemoteDataSource source, {String? knowledge}) {
  sl.registerLazySingleton<ChatRemoteDataSource>(() => source);
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: _Online(),
      knowledgeDataSource: knowledge == null ? null : _KnowledgeFile(knowledge),
    ),
  );
  sl.registerLazySingleton(() => AskFimaUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => GetChatHistoryUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => SaveChatHistoryUseCase(sl<ChatRepository>()));
  sl.registerFactory(
    () => ChatBloc(ask: sl(), getHistory: sl(), saveHistory: sl()),
  );
}

/// A phone-sized screen, [width] x [height] logical pixels at a pixel ratio of 3.
void usePhone(WidgetTester tester, {double width = 360, double height = 800}) {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// The app with a stand-in Home, signed in as [memberId]. The chat is not
/// opened yet (see [openChat]) unless the app [start]s on it.
Future<GoRouter> pumpApp(
  WidgetTester tester, {
  String memberId = 'M-1',
  ThemeData? theme,
  bool disableAnimations = false,
  String start = '/home',
}) async {
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: RouteNames.home,
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('home-page'))),
      ),
      GoRoute(path: RouteNames.chatbot, builder: (_, _) => const ChatbotPage()),
    ],
  );
  addTearDown(router.dispose);

  final auth = MockAuthBloc();
  whenListen(
    auth,
    const Stream<AuthState>.empty(),
    initialState: AuthAuthenticated(
      UserEntity(
        id: memberId,
        name: 'Tester',
        status: 'Active',
        isActive: true,
      ),
    ),
  );

  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: auth,
      child: MaterialApp.router(
        theme: theme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Opens the chat from the stand-in Home, as Home's button does.
Future<void> openChat(WidgetTester tester, GoRouter router) async {
  unawaited(router.push(RouteNames.chatbot));
  await tester.pumpAndSettle();
}

void main() {
  late ScriptedChatDataSource source;

  setUp(() {
    source = ScriptedChatDataSource();
    registerChat(source);
  });
  tearDown(() => sl.reset());

  final input = find.byKey(const Key('chat-input'));
  final send = find.byKey(const Key('chat-send'));
  final list = find.byKey(const Key('chat-list'));
  final retry = find.byKey(const Key('chat-retry'));

  bool sendEnabled(WidgetTester tester) =>
      tester.widget<IconButton>(send).onPressed != null;

  /// Types [text] and sends it, then lets the frame it causes happen.
  Future<void> ask(WidgetTester tester, String text) async {
    await tester.enterText(input, text);
    await tester.pump();
    await tester.tap(send);
    await tester.pump();
  }

  /// Lets an answer that has just been given reach the screen and the list
  /// finish scrolling to it. Not pumpAndSettle: while Fima is typing the
  /// indicator animates forever.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('on arrival', () {
    testWidgets('introduces Fima and offers questions to start with', (
      tester,
    ) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      expect(find.text('Halo, saya Fima'), findsOneWidget);
      for (final question in ChatEmptyState.suggestions) {
        expect(find.text(question), findsOneWidget);
      }
      expect(list, findsNothing, reason: 'no conversation yet');
      expect(input, findsOneWidget);
      expect(sendEnabled(tester), isFalse);
    });

    testWidgets('has a bar with Fima\'s name and a back arrow', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      final bar = find.byType(AppBar);
      expect(
        find.descendant(of: bar, matching: find.text('Fima')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.text('Asisten virtual')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: bar,
          matching: find.widgetWithIcon(IconButton, Icons.arrow_back),
        ),
        findsOneWidget,
      );
    });
  });

  group('the back arrow', () {
    testWidgets('returns to the page the chat was opened from', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('home-page'), findsOneWidget);
      expect(find.byType(ChatbotPage), findsNothing);
    });

    testWidgets('goes Home when there is no page to return to', (tester) async {
      usePhone(tester);
      await pumpApp(tester, start: RouteNames.chatbot);
      expect(find.byType(ChatbotPage), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('home-page'), findsOneWidget);
    });
  });

  group('asking a question', () {
    testWidgets('shows it as the member\'s bubble, empties the box, and hides '
        'the introduction', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      await ask(tester, 'Berapa biaya ganti oli?');

      expect(find.text('Berapa biaya ganti oli?'), findsOneWidget);
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(find.text('Halo, saya Fima'), findsNothing);
      expect(source.questions, ['Berapa biaya ganti oli?']);
    });

    testWidgets('sends one of the starter questions as if it had been typed', (
      tester,
    ) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      await tester.tap(find.text(ChatEmptyState.suggestions.first));
      await tester.pump();

      expect(source.questions, [ChatEmptyState.suggestions.first]);
      // Now a bubble in the conversation (the chip itself is gone).
      expect(find.text(ChatEmptyState.suggestions.first), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);
    });

    testWidgets('does not send blank text', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      await tester.enterText(input, '   \n  ');
      await tester.pump();

      expect(sendEnabled(tester), isFalse);
      expect(source.questions, isEmpty);
    });

    testWidgets('stops the text at the limit', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      await tester.enterText(
        input,
        'x' * (ChatConstants.maxMessageLength + 50),
      );
      await tester.pump();

      expect(
        tester.widget<TextField>(input).controller!.text,
        hasLength(ChatConstants.maxMessageLength),
      );
    });

    testWidgets('puts the member\'s bubble on the right', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      await ask(tester, 'Halo');

      expect(tester.getCenter(find.text('Halo')).dx, greaterThan(360 / 2));
    });
  });

  group('while Fima is answering', () {
    testWidgets('shows she is typing, and the member\'s message as still '
        'being sent', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      await ask(tester, 'Halo');

      expect(find.byType(TypingIndicator), findsOneWidget);
      expect(find.byKey(const Key('chat-sending')), findsOneWidget);
    });

    testWidgets('lets the next question be written but not sent', (
      tester,
    ) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);
      await ask(tester, 'Satu');

      await tester.enterText(input, 'Dua');
      await tester.pump();

      expect(sendEnabled(tester), isFalse);
      expect(tester.widget<TextField>(input).controller!.text, 'Dua');
      expect(source.questions, ['Satu'], reason: 'only the first went out');
    });

    testWidgets('puts her answer in as hers when it comes, takes the typing '
        'indicator away, and frees the send button', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);
      await ask(tester, 'Halo');

      source.answer('Halo juga, ada yang bisa dibantu?');
      await settle(tester);

      expect(find.text('Halo juga, ada yang bisa dibantu?'), findsOneWidget);
      expect(find.byType(TypingIndicator), findsNothing);
      expect(find.byKey(const Key('chat-sending')), findsNothing);
      // Hers is on the left: it starts by her avatar, in the left half (its
      // centre is no test, as the test font makes even a short answer wide).
      expect(
        tester.getTopLeft(find.text('Halo juga, ada yang bisa dibantu?')).dx,
        lessThan(360 / 2),
      );

      await tester.enterText(input, 'Terima kasih');
      await tester.pump();
      expect(sendEnabled(tester), isTrue);
    });

    testWidgets('keeps the conversation in order over several questions', (
      tester,
    ) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      for (final n in ['Satu', 'Dua', 'Tiga']) {
        await ask(tester, n);
        source.answer('Jawab $n');
        await settle(tester);
      }

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      final order = [
        'Satu',
        'Jawab Satu',
        'Dua',
        'Jawab Dua',
        'Tiga',
        'Jawab Tiga',
      ];
      expect([
        for (final t in order) top(t),
      ], orderedEquals([for (final t in order) top(t)]..sort()));
    });

    testWidgets('stays still, instead of animating, when the OS asks for no '
        'animations', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester, disableAnimations: true);
      await openChat(tester, router);
      await ask(tester, 'Halo');

      // With nothing animating this returns; with the dots pulsing it would
      // wait forever.
      await tester.pumpAndSettle();

      expect(find.byType(TypingIndicator), findsOneWidget);
    });
  });

  group('when a question cannot be answered', () {
    testWidgets('marks it, says why, and offers to try again', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);
      await ask(tester, 'Halo');

      source.fail(const ServerException(message: 'Boom', statusCode: 500));
      await settle(tester);

      expect(find.byType(TypingIndicator), findsNothing);
      expect(
        find.text('Fima sedang bermasalah · Ketuk untuk coba lagi'),
        findsOneWidget,
      );
      expect(find.text('Halo'), findsOneWidget, reason: 'the question stays');
      expect(find.byKey(const Key('chat-sending')), findsNothing);
    });

    testWidgets('says there is no connection when that is the reason', (
      tester,
    ) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);
      await ask(tester, 'Halo');

      source.fail(const NetworkException(message: 'offline'));
      await settle(tester);

      expect(
        find.text('Tidak ada koneksi internet · Ketuk untuk coba lagi'),
        findsOneWidget,
      );
    });

    testWidgets('treats an empty answer as a failure, not as a blank bubble', (
      tester,
    ) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);
      await ask(tester, 'Halo');

      source.answer('   ');
      await settle(tester);

      expect(find.textContaining('Fima sedang bermasalah'), findsOneWidget);
    });

    testWidgets('survives anything the service does, without a crash on '
        'screen', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      for (final surprise in [
        const FormatException('not json'),
        StateError('who knows'),
        TypeError(),
      ]) {
        await ask(tester, 'Halo');
        source.fail(surprise);
        await settle(tester);

        expect(tester.takeException(), isNull, reason: '$surprise');
        expect(retry, findsWidgets);
        // Ready for another question.
        expect(find.byType(TypingIndicator), findsNothing);
      }
    });

    testWidgets('tapping the note asks the same question again, and her answer '
        'then comes right after it', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);
      await ask(tester, 'Halo');
      source.fail(const NetworkException(message: 'offline'));
      await settle(tester);

      await tester.tap(retry);
      await tester.pump();

      expect(source.questions, ['Halo', 'Halo']);
      expect(find.byType(TypingIndicator), findsOneWidget);
      expect(retry, findsNothing, reason: 'it is being sent again');

      source.answer('Sudah bisa sekarang');
      await settle(tester);

      expect(find.text('Sudah bisa sekarang'), findsOneWidget);
      expect(find.textContaining('Ketuk untuk coba lagi'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('can fail again, and be tried again, as often as needed', (
      tester,
    ) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);
      await ask(tester, 'Halo');

      for (var i = 0; i < 3; i++) {
        source.fail(const NetworkException(message: 'offline'));
        await settle(tester);
        expect(retry, findsOneWidget);
        await tester.tap(retry);
        await tester.pump();
      }

      expect(source.questions, ['Halo', 'Halo', 'Halo', 'Halo']);
    });

    testWidgets('does not offer to retry an old failure while another '
        'question is being answered', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);
      await ask(tester, 'Satu');
      source.fail(const NetworkException(message: 'offline'));
      await settle(tester);
      expect(retry, findsOneWidget);

      await ask(tester, 'Dua');

      expect(retry, findsNothing);
      expect(find.text('Tidak ada koneksi internet'), findsOneWidget);
      expect(find.textContaining('Ketuk'), findsNothing);

      source.answer('Jawab dua');
      await settle(tester);

      expect(retry, findsOneWidget, reason: 'offered again once Fima is free');
    });

    testWidgets('puts the answer to a retried question where it belongs, not '
        'at the end', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      await ask(tester, 'Pertama');
      source.fail(const NetworkException(message: 'offline'));
      await settle(tester);
      await ask(tester, 'Kedua');
      source.answer('Jawab kedua');
      await settle(tester);

      await tester.tap(retry);
      await tester.pump();
      source.answer('Jawab pertama');
      await settle(tester);

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('Pertama'), lessThan(top('Jawab pertama')));
      expect(top('Jawab pertama'), lessThan(top('Kedua')));
      expect(top('Kedua'), lessThan(top('Jawab kedua')));
    });
  });

  group('the test words of the stand-in', () {
    // The real stand-in, answering at once.
    setUp(() {
      sl.unregister<ChatRemoteDataSource>();
      sl.unregister<ChatRepository>();
      sl.unregister<AskFimaUseCase>();
      sl.unregister<GetChatHistoryUseCase>();
      sl.unregister<SaveChatHistoryUseCase>();
      sl.unregister<ChatBloc>();
      registerChat(const FakeChatRemoteDataSource(delay: Duration.zero));
    });

    for (final (word, shown) in [
      ('/error', 'Fima sedang bermasalah'),
      ('/offline', 'Tidak ada koneksi internet'),
      ('/kosong', 'Fima sedang bermasalah'),
    ]) {
      testWidgets('$word shows "$shown"', (tester) async {
        usePhone(tester);
        final router = await pumpApp(tester);
        await openChat(tester, router);

        await ask(tester, word);
        await tester.pumpAndSettle();

        expect(find.textContaining(shown), findsOneWidget);
      });
    }

    testWidgets('an ordinary question gets a labelled sample answer', (
      tester,
    ) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      await ask(tester, 'Apa kabar?');
      await tester.pumpAndSettle();

      expect(find.textContaining('contoh jawaban Fima'), findsOneWidget);
    });

    testWidgets('/panjang shows a long answer in full, without overflow', (
      tester,
    ) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      await ask(tester, '/panjang');
      await tester.pumpAndSettle();

      expect(find.textContaining('Paragraf kedua'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the kept conversation', () {
    testWidgets('is there again when the chat is left and reopened', (
      tester,
    ) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);
      await ask(tester, 'Halo');
      source.answer('Halo juga');
      await settle(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('home-page'), findsOneWidget);

      await openChat(tester, router);

      expect(find.text('Halo'), findsOneWidget);
      expect(find.text('Halo juga'), findsOneWidget);
      expect(find.text('Halo, saya Fima'), findsNothing);
    });

    testWidgets('has an answer that arrived after the chat was left, when it '
        'is reopened', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);
      await ask(tester, 'Halo');

      // Left before Fima answers.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      source.answer('Jawaban yang terlambat');
      await tester.pump();

      await openChat(tester, router);

      expect(find.text('Halo'), findsOneWidget);
      expect(find.text('Jawaban yang terlambat'), findsOneWidget);
      expect(find.byType(TypingIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('turns a question whose answer never came into a failed one '
        'that can be sent again', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);
      await ask(tester, 'Halo');

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      // The answer never comes. Reopened:
      await openChat(tester, router);

      expect(find.text('Halo'), findsOneWidget);
      expect(find.byType(TypingIndicator), findsNothing);
      expect(retry, findsOneWidget);

      await tester.tap(retry);
      await tester.pump();
      expect(source.questions, ['Halo', 'Halo']);
    });

    testWidgets('is not shown to a different member who signs in next', (
      tester,
    ) async {
      usePhone(tester);
      var router = await pumpApp(tester, memberId: 'M-1');
      await openChat(tester, router);
      await ask(tester, 'Rahasia pertama');
      source.answer('Jawaban pertama');
      await settle(tester);

      // Someone else signs in on the same phone.
      router = await pumpApp(tester, memberId: 'M-2');
      await openChat(tester, router);

      expect(find.text('Rahasia pertama'), findsNothing);
      expect(find.text('Jawaban pertama'), findsNothing);
      expect(find.text('Halo, saya Fima'), findsOneWidget);
    });
  });

  group('a long conversation', () {
    List<ChatMessage> history(int count) => [
      for (var i = 1; i <= count; i++)
        ChatMessage(
          id: 'h$i',
          text: 'Pesan $i',
          sender: i.isOdd ? ChatSender.user : ChatSender.fima,
          status: ChatMessageStatus.sent,
          createdAt: DateTime(2026, 10, 20, 9, i % 60),
        ),
    ];

    testWidgets('opens at the newest message, not the oldest', (tester) async {
      usePhone(tester);
      sl<ChatRepository>().saveHistory('M-1', history(40));
      final router = await pumpApp(tester);
      await openChat(tester, router);

      expect(find.text('Pesan 40'), findsOneWidget);
      expect(find.text('Pesan 1'), findsNothing, reason: 'far above, unbuilt');
      // And it sits at the bottom of the list, right above the box.
      expect(
        tester.getBottomLeft(find.text('Pesan 40')).dy,
        lessThanOrEqualTo(tester.getTopLeft(input).dy),
      );
    });

    testWidgets('scrolls back to the newest when something new arrives, even '
        'from far up', (tester) async {
      usePhone(tester);
      sl<ChatRepository>().saveHistory('M-1', history(40));
      final router = await pumpApp(tester);
      await openChat(tester, router);

      await tester.drag(list, const Offset(0, 1500));
      await tester.pumpAndSettle();
      expect(find.text('Pesan 40'), findsNothing, reason: 'scrolled away');

      await ask(tester, 'Pertanyaan baru');
      await settle(tester);

      expect(find.text('Pertanyaan baru'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('Pertanyaan baru')).dy,
        lessThanOrEqualTo(tester.getTopLeft(input).dy),
      );
    });

    testWidgets('keeps the newest in view when Fima answers', (tester) async {
      usePhone(tester);
      sl<ChatRepository>().saveHistory('M-1', history(40));
      final router = await pumpApp(tester);
      await openChat(tester, router);
      await ask(tester, 'Pertanyaan baru');

      source.answer('Jawaban baru');
      await settle(tester);

      expect(find.text('Jawaban baru'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('Jawaban baru')).dy,
        lessThanOrEqualTo(tester.getTopLeft(input).dy),
      );
    });
  });

  group('with the keyboard up', () {
    testWidgets('keeps the box above the keyboard, without overflowing', (
      tester,
    ) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      // A 300-logical-pixel keyboard.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomLeft(input).dy,
        lessThanOrEqualTo(800 - 300),
        reason: 'the box is not hidden behind the keyboard',
      );
    });

    testWidgets('still fits, with the introduction scrolling, on a small '
        'screen', (tester) async {
      usePhone(tester, width: 320, height: 568);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final router = await pumpApp(tester);
      await openChat(tester, router);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250 * 3);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('in dark mode', () {
    testWidgets('keeps Fima\'s answer readable on its light-grey bubble', (
      tester,
    ) async {
      usePhone(tester);
      final router = await pumpApp(tester, theme: AppTheme.dark);
      await openChat(tester, router);
      await ask(tester, 'Halo');
      source.answer('Halo juga');
      await settle(tester);

      final bubble =
          tester
                  .widget<DecoratedBox>(
                    find
                        .ancestor(
                          of: find.text('Halo juga'),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      final text = tester.widget<SelectableText>(find.byType(SelectableText));

      expect(bubble.color, AppColors.surfaceDark);
      expect(
        contrast(text.style!.color!, bubble.color!),
        greaterThanOrEqualTo(4.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('has a bar that follows the theme', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester, theme: AppTheme.dark);
      await openChat(tester, router);

      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.backgroundColor, AppTheme.dark.scaffoldBackgroundColor);
    });
  });

  group('asking a person on WhatsApp', () {
    const apology =
        'Mohon Maaf untuk saat ini saya belum bisa menjawab pertanyaan anda.';
    const greeting = 'https://wa.me/6285179798961?text='
        'Halo%20FixUp%20Moto%2C%20saya%20butuh%20bantuan.';
    final inline = find.byKey(const Key('chat-agent-inline'));
    final appBarAction = find.byKey(const Key('chat-agent-appbar'));

    /// Stands in for the url_launcher plugin: answers every launch with
    /// [opens] and records the calls it received.
    List<MethodCall> mockLauncher({required bool opens}) {
      final calls = <MethodCall>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return opens;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      return calls;
    }

    String urlOf(MethodCall call) => (call.arguments as Map)['url'] as String;

    Future<void> openAndAsk(
      WidgetTester tester,
      String question,
      String answer,
    ) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);
      await ask(tester, question);
      source.answer(answer);
      await settle(tester);
    }

    testWidgets('offers it under Fima\'s apology', (tester) async {
      await openAndAsk(tester, 'Berapa poin saya?', apology);

      expect(find.text(apology), findsOneWidget);
      expect(inline, findsOneWidget);
    });

    testWidgets('does not offer it under an answer she did give', (
      tester,
    ) async {
      await openAndAsk(tester, 'Jam buka?', 'Buka setiap hari pukul 08.00.');

      expect(inline, findsNothing);
    });

    testWidgets('opens WhatsApp with the question that was not answered', (
      tester,
    ) async {
      final calls = mockLauncher(opens: true);
      await openAndAsk(tester, 'Berapa poin saya?', apology);

      await tester.tap(inline);
      await tester.pump();

      expect(calls, hasLength(1));
      expect(
        urlOf(calls.single),
        'https://wa.me/6285179798961?text='
        'Halo%20FixUp%20Moto%2C%20saya%20butuh%20bantuan.'
        '%20Pertanyaan%20saya%3A%20%22Berapa%20poin%20saya%3F%22',
      );
      // Handed to WhatsApp (or the browser), not shown in an in-app web view.
      expect((calls.single.arguments as Map)['useWebView'], isFalse);
      expect(find.text('WhatsApp tidak dapat dibuka'), findsNothing);
    });

    testWidgets('gives each apology its own question, not the latest', (
      tester,
    ) async {
      final calls = mockLauncher(opens: true);
      await openAndAsk(tester, 'Pertanyaan satu', apology);
      await ask(tester, 'Pertanyaan dua');
      source.answer(apology);
      await settle(tester);
      expect(inline, findsNWidgets(2));

      await tester.tap(inline.at(0));
      await tester.pump();
      await tester.tap(inline.at(1));
      await tester.pump();

      final texts = [
        for (final call in calls) Uri.parse(urlOf(call)).queryParameters['text'],
      ];
      expect(texts, hasLength(2));
      expect(
        texts.any((t) => t!.endsWith('"Pertanyaan satu"')),
        isTrue,
        reason: texts.join(' | '),
      );
      expect(texts.any((t) => t!.endsWith('"Pertanyaan dua"')), isTrue);
    });

    testWidgets('is always in the top bar, even before anything is asked', (
      tester,
    ) async {
      final calls = mockLauncher(opens: true);
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      expect(
        find.descendant(of: find.byType(AppBar), matching: appBarAction),
        findsOneWidget,
      );

      await tester.tap(appBarAction);
      await tester.pump();

      // Nothing asked yet: a plain greeting, no question in it.
      expect(urlOf(calls.single), greeting);
    });

    testWidgets('top bar action carries the latest question', (tester) async {
      final calls = mockLauncher(opens: true);
      await openAndAsk(tester, 'Pertanyaan satu', 'Jawaban satu');
      await ask(tester, 'Pertanyaan dua');
      source.answer('Jawaban dua');
      await settle(tester);

      await tester.tap(appBarAction);
      await tester.pump();

      expect(
        Uri.parse(urlOf(calls.single)).queryParameters['text'],
        'Halo FixUp Moto, saya butuh bantuan. Pertanyaan saya: '
        '"Pertanyaan dua"',
      );
    });

    testWidgets('top bar action is labelled', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      expect(tester.widget<IconButton>(appBarAction).tooltip, 'Hubungi petugas');
    });

    testWidgets('top bar action works while Fima is still answering', (
      tester,
    ) async {
      final calls = mockLauncher(opens: true);
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);
      await ask(tester, 'Sedang ditanya');

      await tester.tap(appBarAction);
      await tester.pump();

      expect(calls, hasLength(1));
    });

    testWidgets('says so when WhatsApp cannot be opened', (tester) async {
      mockLauncher(opens: false);
      await openAndAsk(tester, 'Berapa poin saya?', apology);

      await tester.tap(inline);
      await tester.pump();

      expect(find.text('WhatsApp tidak dapat dibuka'), findsOneWidget);
    });

    testWidgets('keeps the button when the chat is left and reopened', (
      tester,
    ) async {
      await openAndAsk(tester, 'Berapa poin saya?', apology);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      final router = GoRouter.of(tester.element(find.text('home-page')));
      await openChat(tester, router);

      expect(find.text(apology), findsOneWidget);
      expect(inline, findsOneWidget);
    });
  });

  group('answering from Fima\'s own file', () {
    const apology =
        'Mohon Maaf untuk saat ini saya belum bisa menjawab pertanyaan anda.';
    const file = '''
## Poin
Kata kunci: poin, point
Poin didapat dari setiap servis.
''';
    final inline = find.byKey(const Key('chat-agent-inline'));

    setUp(() async {
      // Replace the chat's layers with ones that have the file.
      await sl.reset();
      source = ScriptedChatDataSource();
      registerChat(source, knowledge: file);
    });

    testWidgets('shows the file\'s answer when the service apologises and a '
        'topic fits, with no apology and no button', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      await ask(tester, 'Bagaimana cara dapat poin?');
      source.answer(apology);
      await settle(tester);

      expect(find.text('Poin didapat dari setiap servis.'), findsOneWidget);
      expect(find.text(apology), findsNothing);
      expect(inline, findsNothing);
    });

    testWidgets('still shows the apology, with the button, when no topic '
        'fits', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      await ask(tester, 'Apakah bengkel buka hari Minggu?');
      source.answer(apology);
      await settle(tester);

      expect(find.text(apology), findsOneWidget);
      expect(inline, findsOneWidget);
    });

    testWidgets('leaves the service\'s own answer alone', (tester) async {
      usePhone(tester);
      final router = await pumpApp(tester);
      await openChat(tester, router);

      await ask(tester, 'Jam buka dan poin?');
      source.answer('Buka setiap hari pukul 08.00.');
      await settle(tester);

      expect(find.text('Buka setiap hari pukul 08.00.'), findsOneWidget);
      expect(find.text('Poin didapat dari setiap servis.'), findsNothing);
    });
  });
}

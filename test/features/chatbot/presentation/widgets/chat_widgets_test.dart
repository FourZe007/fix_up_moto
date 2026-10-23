import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/constants/chat_constants.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/features/chatbot/domain/entities/chat_message.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/chat_bubble.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/chat_composer.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/chat_empty_state.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/chat_failure_text.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/fima_avatar.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/typing_indicator.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// A phone-sized screen, [width] x [height] logical pixels at a pixel ratio of 3.
void usePhone(WidgetTester tester, {double width = 360, double height = 800}) {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> pumpWidgetInPage(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  bool disableAnimations = false,
}) {
  usePhone(tester);
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, page) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: page!,
      ),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

void main() {
  final time = DateTime(2026, 10, 20, 7, 5);

  ChatMessage message(
    String text, {
    ChatSender sender = ChatSender.user,
    ChatMessageStatus status = ChatMessageStatus.sent,
    Failure? failure,
  }) => ChatMessage(
    id: 'm',
    text: text,
    sender: sender,
    status: status,
    failure: failure,
    createdAt: time,
  );

  group('chatFailureText', () {
    test('says it in words for the member, by kind of failure', () {
      expect(
        chatFailureText(const NetworkFailure('offline')),
        'Tidak ada koneksi internet',
      );
      expect(
        chatFailureText(const ServerFailure('Boom', statusCode: 500)),
        'Fima sedang bermasalah',
      );
      expect(
        chatFailureText(const AuthFailure('expired')),
        'Sesi berakhir, silakan masuk lagi',
      );
    });

    test('falls back to something plain when the reason is unknown', () {
      expect(chatFailureText(null), 'Pesan belum terkirim');
      expect(chatFailureText(const CacheFailure('x')), 'Pesan belum terkirim');
    });

    test('never shows the data layer\'s own wording', () {
      expect(
        chatFailureText(const ServerFailure('java.lang.NullPointerException')),
        isNot(contains('Null')),
      );
    });
  });

  group('ChatBubble', () {
    testWidgets('shows a member\'s message on the right, in the brand colour, '
        'with the time', (tester) async {
      await pumpWidgetInPage(tester, ChatBubble(message: message('Halo Fima')));

      expect(find.text('Halo Fima'), findsOneWidget);
      expect(find.text('07:05'), findsOneWidget);

      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('Halo Fima'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).color, AppColors.primary);
      // On the right: the bubble's right edge is at the page's, 16 px in.
      expect(
        tester.getTopRight(find.text('Halo Fima')).dx,
        lessThanOrEqualTo(360 - 16),
      );
      expect(tester.getCenter(find.text('Halo Fima')).dx, greaterThan(360 / 2));
    });

    testWidgets('shows Fima\'s answer on the left, beside her avatar, on a '
        'white bubble', (tester) async {
      await pumpWidgetInPage(
        tester,
        ChatBubble(message: message('Halo juga', sender: ChatSender.fima)),
        // The app's own light theme: a bare MaterialApp's surface is not its
        // white.
        theme: AppTheme.light,
      );

      expect(find.text('Halo juga'), findsOneWidget);
      expect(find.byType(FimaAvatar), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
      expect(tester.getCenter(find.text('Halo juga')).dx, lessThan(360 / 2));

      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('Halo juga'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).color, AppColors.surfaceLight);
    });

    testWidgets('lets an answer be selected, so it can be copied', (
      tester,
    ) async {
      await pumpWidgetInPage(
        tester,
        ChatBubble(message: message('Salin ini', sender: ChatSender.fima)),
      );

      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('writes the time with two digits for the hour and the '
        'minute', (tester) async {
      expect(ChatBubble.clock(DateTime(2026, 1, 1, 0, 0)), '00:00');
      expect(ChatBubble.clock(DateTime(2026, 1, 1, 9, 5)), '09:05');
      expect(ChatBubble.clock(DateTime(2026, 1, 1, 23, 59)), '23:59');
    });

    group('a message still being sent', () {
      testWidgets('shows a clock instead of the time, and is dimmed', (
        tester,
      ) async {
        await pumpWidgetInPage(
          tester,
          ChatBubble(
            message: message('Halo', status: ChatMessageStatus.sending),
          ),
        );

        expect(find.byKey(const Key('chat-sending')), findsOneWidget);
        expect(find.text('07:05'), findsNothing);
        expect(
          tester
              .widget<Opacity>(
                find
                    .ancestor(
                      of: find.text('Halo'),
                      matching: find.byType(Opacity),
                    )
                    .first,
              )
              .opacity,
          lessThan(1),
        );
      });
    });

    group('a message that failed', () {
      testWidgets('says why, and offers to try again when it can', (
        tester,
      ) async {
        var retried = 0;
        await pumpWidgetInPage(
          tester,
          ChatBubble(
            message: message(
              'Halo',
              status: ChatMessageStatus.failed,
              failure: const NetworkFailure('offline'),
            ),
            onRetry: () => retried++,
          ),
        );

        expect(
          find.text('Tidak ada koneksi internet · Ketuk untuk coba lagi'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('chat-retry')));
        expect(retried, 1);
      });

      testWidgets('says why but does not offer a retry that would be ignored', (
        tester,
      ) async {
        await pumpWidgetInPage(
          tester,
          ChatBubble(
            message: message(
              'Halo',
              status: ChatMessageStatus.failed,
              failure: const ServerFailure('Boom'),
            ),
          ),
        );

        expect(find.text('Fima sedang bermasalah'), findsOneWidget);
        expect(find.textContaining('Ketuk'), findsNothing);
        expect(find.byKey(const Key('chat-retry')), findsNothing);
      });

      testWidgets('still says something when the reason is not known', (
        tester,
      ) async {
        await pumpWidgetInPage(
          tester,
          ChatBubble(
            message: message('Halo', status: ChatMessageStatus.failed),
            onRetry: () {},
          ),
        );

        expect(
          find.text('Pesan belum terkirim · Ketuk untuk coba lagi'),
          findsOneWidget,
        );
      });

      testWidgets('is not marked as failed when it went through', (
        tester,
      ) async {
        await pumpWidgetInPage(
          tester,
          ChatBubble(message: message('Halo'), onRetry: () {}),
        );

        expect(find.byIcon(Icons.error_outline), findsNothing);
      });

      testWidgets('is readable on a dark page too', (tester) async {
        await pumpWidgetInPage(
          tester,
          ChatBubble(
            message: message(
              'Halo',
              status: ChatMessageStatus.failed,
              failure: const NetworkFailure('offline'),
            ),
            onRetry: () {},
          ),
          theme: AppTheme.dark,
        );

        final color = tester
            .widget<Text>(find.textContaining('Tidak ada koneksi'))
            .style!
            .color!;
        expect(
          contrast(color, AppTheme.dark.scaffoldBackgroundColor),
          greaterThanOrEqualTo(4.5),
        );
      });
    });

    group('layout', () {
      testWidgets('never takes more than its share of the width, and wraps '
          'long text', (tester) async {
        await pumpWidgetInPage(
          tester,
          ChatBubble(message: message('kata ' * 80)),
        );

        final width = tester
            .getSize(
              find
                  .ancestor(
                    of: find.textContaining('kata'),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .width;
        expect(width, lessThanOrEqualTo(360 * ChatBubble.maxWidthFactor));
        expect(tester.takeException(), isNull);
      });

      testWidgets('does not overflow on one very long word', (tester) async {
        // In a scroll view, as in the page: the test font is far wider than
        // the real one, so two such bubbles are taller than the screen.
        await pumpWidgetInPage(
          tester,
          SingleChildScrollView(
            child: Column(
              children: [
                ChatBubble(message: message('a' * 300)),
                ChatBubble(
                  message: message('b' * 300, sender: ChatSender.fima),
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('keeps line breaks in an answer', (tester) async {
        await pumpWidgetInPage(
          tester,
          ChatBubble(
            message: message('Satu\n\nDua\nTiga', sender: ChatSender.fima),
          ),
        );

        expect(
          tester.getSize(find.byType(SelectableText)).height,
          greaterThan(15 * 1.4 * 3),
          reason: 'four lines, not one',
        );
      });
    });

    testWidgets('has an accessible label saying who wrote it', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWidgetInPage(
        tester,
        Column(
          children: [
            ChatBubble(message: message('Pertanyaan saya')),
            ChatBubble(
              message: message('Jawaban Fima', sender: ChatSender.fima),
            ),
          ],
        ),
      );

      expect(find.bySemanticsLabel('Anda: Pertanyaan saya'), findsOneWidget);
      expect(find.bySemanticsLabel('Fima: Jawaban Fima'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('keeps an answer readable on a dark page: dark text on its '
        'light-grey bubble', (tester) async {
      await pumpWidgetInPage(
        tester,
        ChatBubble(message: message('Halo juga', sender: ChatSender.fima)),
        theme: AppTheme.dark,
      );

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
    });
  });

  group('TypingIndicator', () {
    testWidgets('shows Fima\'s avatar and three dots', (tester) async {
      await pumpWidgetInPage(tester, const TypingIndicator());

      expect(find.byType(FimaAvatar), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TypingIndicator),
          matching: find.byType(Opacity),
        ),
        findsNWidgets(3),
      );
    });

    testWidgets('pulses: the dots do not all glow the same, and change over '
        'time', (tester) async {
      await pumpWidgetInPage(tester, const TypingIndicator());

      List<double> glow() => [
        for (final o in tester.widgetList<Opacity>(
          find.descendant(
            of: find.byType(TypingIndicator),
            matching: find.byType(Opacity),
          ),
        ))
          o.opacity,
      ];

      await tester.pump(const Duration(milliseconds: 300));
      final first = glow();
      await tester.pump(const Duration(milliseconds: 300));
      final second = glow();

      expect(first.toSet().length, greaterThan(1));
      expect(second, isNot(first));
      expect([...first, ...second].every((o) => o >= 0.35 && o <= 1), isTrue);
    });

    testWidgets('keeps still, all lit, when the OS asks for no animations', (
      tester,
    ) async {
      await pumpWidgetInPage(
        tester,
        const TypingIndicator(),
        disableAnimations: true,
      );

      // Nothing is animating, so this returns instead of waiting forever.
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<Opacity>(
              find.descendant(
                of: find.byType(TypingIndicator),
                matching: find.byType(Opacity),
              ),
            )
            .map((o) => o.opacity),
        everyElement(1.0),
      );
    });

    testWidgets('is announced as Fima typing', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWidgetInPage(tester, const TypingIndicator());

      expect(find.bySemanticsLabel('Fima sedang mengetik'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('stops cleanly when removed', (tester) async {
      await pumpWidgetInPage(tester, const TypingIndicator());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));

      expect(tester.takeException(), isNull);
    });
  });

  group('ChatComposer', () {
    final input = find.byKey(const Key('chat-input'));
    final send = find.byKey(const Key('chat-send'));

    bool sendEnabled(WidgetTester tester) =>
        tester.widget<IconButton>(send).onPressed != null;

    Future<List<String>> pumpComposer(
      WidgetTester tester, {
      bool canSend = true,
      ThemeData? theme,
    }) async {
      final sent = <String>[];
      await pumpWidgetInPage(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: ChatComposer(canSend: canSend, onSend: sent.add),
        ),
        theme: theme,
      );
      return sent;
    }

    testWidgets('starts with nothing to send, and a hint', (tester) async {
      await pumpComposer(tester);

      expect(find.text('Tulis pertanyaan…'), findsOneWidget);
      expect(sendEnabled(tester), isFalse);
    });

    testWidgets('can send once there is something to send', (tester) async {
      await pumpComposer(tester);

      await tester.enterText(input, 'Halo');
      await tester.pump();

      expect(sendEnabled(tester), isTrue);
    });

    for (final blank in ['   ', '\n', ' \n \t ']) {
      testWidgets('cannot send a blank message (${blank.codeUnits})', (
        tester,
      ) async {
        await pumpComposer(tester);

        await tester.enterText(input, blank);
        await tester.pump();

        expect(sendEnabled(tester), isFalse);
      });
    }

    testWidgets('sends the trimmed text and empties the box', (tester) async {
      final sent = await pumpComposer(tester);

      await tester.enterText(input, '  Halo Fima \n');
      await tester.pump();
      await tester.tap(send);
      await tester.pump();

      expect(sent, ['Halo Fima']);
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(sendEnabled(tester), isFalse, reason: 'nothing left to send');
    });

    testWidgets('can be typed in, but not sent, while Fima is answering', (
      tester,
    ) async {
      final sent = await pumpComposer(tester, canSend: false);

      await tester.enterText(input, 'Pertanyaan berikutnya');
      await tester.pump();

      expect(
        tester.widget<TextField>(input).controller!.text,
        'Pertanyaan berikutnya',
        reason: 'the next question can be written already',
      );
      expect(sendEnabled(tester), isFalse);

      await tester.tap(send, warnIfMissed: false);
      expect(sent, isEmpty);
    });

    testWidgets('keeps what was typed when Fima finishes answering', (
      tester,
    ) async {
      final sent = <String>[];
      final canSend = ValueNotifier(false);
      addTearDown(canSend.dispose);
      await pumpWidgetInPage(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: canSend,
          builder: (_, value, _) =>
              ChatComposer(canSend: value, onSend: sent.add),
        ),
      );

      await tester.enterText(input, 'Tunggu');
      await tester.pump();
      expect(sendEnabled(tester), isFalse);

      canSend.value = true;
      await tester.pump();

      expect(sendEnabled(tester), isTrue);
      await tester.tap(send);
      expect(sent, ['Tunggu']);
    });

    testWidgets('stops at the length limit', (tester) async {
      await pumpComposer(tester);

      await tester.enterText(
        input,
        'x' * (ChatConstants.maxMessageLength + 100),
      );
      await tester.pump();

      expect(
        tester.widget<TextField>(input).controller!.text.length,
        ChatConstants.maxMessageLength,
      );
    });

    testWidgets('shows how much is left only when the limit is near', (
      tester,
    ) async {
      await pumpComposer(tester);
      final limit = ChatConstants.maxMessageLength;

      await tester.enterText(input, 'x' * (limit * 0.5).round());
      await tester.pump();
      expect(find.textContaining('/$limit'), findsNothing);

      await tester.enterText(input, 'x' * (limit * 0.95).round());
      await tester.pump();
      expect(find.text('${(limit * 0.95).round()}/$limit'), findsOneWidget);
    });

    testWidgets('grows with the text, up to a few lines, then scrolls inside', (
      tester,
    ) async {
      await pumpComposer(tester);
      final oneLine = tester.getSize(input).height;

      await tester.enterText(input, 'a\nb\nc');
      await tester.pump();
      final threeLines = tester.getSize(input).height;

      await tester.enterText(input, List.filled(30, 'baris').join('\n'));
      await tester.pump();
      final many = tester.getSize(input).height;

      expect(threeLines, greaterThan(oneLine));
      expect(many, greaterThan(threeLines));
      expect(many, lessThan(oneLine * 6), reason: 'capped at four lines');
    });

    testWidgets('is in the page\'s colours in light mode and readable in dark '
        'mode', (tester) async {
      await pumpComposer(tester, theme: AppTheme.dark);
      await tester.enterText(input, 'Halo');
      await tester.pump();

      expect(tester.takeException(), isNull);
      final style = tester
          .widget<EditableText>(find.byType(EditableText))
          .style;
      // Dark text, on the light-grey box that dark mode gives a field.
      expect(
        contrast(style.color!, AppColors.surfaceDark),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('has a labelled send button', (tester) async {
      await pumpComposer(tester);

      expect(tester.widget<IconButton>(send).tooltip, 'Kirim');
    });
  });

  group('ChatEmptyState', () {
    testWidgets('introduces Fima and says how she answers', (tester) async {
      await pumpWidgetInPage(tester, ChatEmptyState(onSuggestion: (_) {}));

      expect(find.text('Halo, saya Fima'), findsOneWidget);
      expect(find.textContaining('Asisten virtual FixUp Moto'), findsOneWidget);
      expect(find.textContaining('dijawab terpisah'), findsOneWidget);
    });

    testWidgets('offers its starter questions, and hands one back when '
        'tapped', (tester) async {
      final asked = <String>[];
      await pumpWidgetInPage(tester, ChatEmptyState(onSuggestion: asked.add));

      for (final question in ChatEmptyState.suggestions) {
        expect(find.text(question), findsOneWidget);
      }

      await tester.tap(find.text(ChatEmptyState.suggestions[1]));
      expect(asked, [ChatEmptyState.suggestions[1]]);
    });

    testWidgets('scrolls instead of overflowing when there is little room', (
      tester,
    ) async {
      usePhone(tester, width: 320, height: 300);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChatEmptyState(onSuggestion: (_) {})),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(ChatEmptyState.suggestions.last));
      expect(tester.takeException(), isNull);
    });
  });
}

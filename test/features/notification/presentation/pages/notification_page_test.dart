import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/warm_section.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';
import 'package:fix_up_moto/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:fix_up_moto/features/notification/presentation/bloc/notification_event.dart';
import 'package:fix_up_moto/features/notification/presentation/bloc/notification_state.dart';
import 'package:fix_up_moto/features/notification/presentation/pages/notification_page.dart';

class MockNotificationBloc
    extends MockBloc<NotificationEvent, NotificationState>
    implements NotificationBloc {}

final tUnread = NotificationEntity(
  memberId: '0101202300000003',
  id: 'N1',
  type: 'Service Booking Confirmed',
  message: 'Booking Service Anda Telah Dikonfirmasi.\nTerima Kasih',
  date: DateTime(2023, 12, 12),
  isSent: true,
  isRead: false,
  numberOfNotifications: 0,
  image: '',
  link: '',
);

final tRead = NotificationEntity(
  memberId: '0101202300000003',
  id: 'N2',
  type: 'Service Reminder',
  message: 'Jangan lupa servis motor Anda',
  date: DateTime(2023, 12, 5),
  isSent: true,
  isRead: true,
  numberOfNotifications: 0,
  image: '',
  link: '',
);

/// The colour [text] is actually drawn in (the page's default text style with
/// the Text's own style on top).
Color colourOf(WidgetTester tester, String text) {
  final finder = find.text(text);
  return DefaultTextStyle.of(
    tester.element(finder),
  ).style.merge(tester.widget<Text>(finder).style).color!;
}

extension on NotificationEntity {
  /// The same message under another id, so a list can hold several.
  NotificationEntity copyWithId(String newId) => NotificationEntity(
    memberId: memberId,
    id: newId,
    type: type,
    message: message,
    date: date,
    isSent: isSent,
    isRead: isRead,
    numberOfNotifications: numberOfNotifications,
    image: image,
    link: link,
  );

  /// The same message under [newId], sent on [newDate] (null: no readable date).
  NotificationEntity copyWithDate(String newId, DateTime? newDate) =>
      NotificationEntity(
        memberId: memberId,
        id: newId,
        type: type,
        message: message,
        date: newDate,
        isSent: isSent,
        isRead: isRead,
        numberOfNotifications: numberOfNotifications,
        image: image,
        link: link,
      );

  /// The same message carrying [newLink].
  NotificationEntity copyWithLink(String newLink) => NotificationEntity(
    memberId: memberId,
    id: id,
    type: type,
    message: message,
    date: date,
    isSent: isSent,
    isRead: isRead,
    numberOfNotifications: numberOfNotifications,
    image: image,
    link: newLink,
  );
}

/// Pumps the page with a mock bloc in [state]; [thenEmits] lets a test push
/// further states while the page is up.
Future<MockNotificationBloc> pumpPage(
  WidgetTester tester, {
  NotificationState state = const NotificationLoaded([]),
  Stream<NotificationState>? thenEmits,
  ThemeData? theme,
}) async {
  final bloc = MockNotificationBloc();
  whenListen(
    bloc,
    thenEmits ?? const Stream<NotificationState>.empty(),
    initialState: state,
  );
  sl.registerFactory<NotificationBloc>(() => bloc);

  await tester.pumpWidget(
    MaterialApp(theme: theme, home: const NotificationPage()),
  );
  return bloc;
}

void main() {
  setUpAll(() {
    registerFallbackValue(const NotificationsRequested());
  });
  tearDown(() => sl.reset());

  final spinner = find.byType(CircularProgressIndicator);

  testWidgets('asks for the inbox when the page opens', (tester) async {
    final bloc = await pumpPage(tester);

    verify(() => bloc.add(const NotificationsRequested())).called(1);
  });

  testWidgets('keeps the Kotak Masuk app bar and its back button', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Kotak Masuk'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  group('loading', () {
    for (final state in [
      const NotificationInitial(),
      const NotificationLoading(),
    ]) {
      testWidgets('${state.runtimeType} shows a spinner and no messages', (
        tester,
      ) async {
        await pumpPage(tester, state: state);

        expect(spinner, findsOneWidget);
        expect(find.text('Belum ada notifikasi'), findsNothing);
      });
    }
  });

  group('the Lihat Detail button', () {
    const address = 'https://fixupmoto.com/promo';
    final button = find.text('Lihat Detail');

    testWidgets('is there when the message has a web link', (tester) async {
      await pumpPage(
        tester,
        state: NotificationLoaded([tUnread.copyWithLink(address)]),
      );

      expect(button, findsOneWidget);
      expect(find.byKey(const Key('notification-link-N1')), findsOneWidget);
      // The address itself is never printed.
      expect(find.text(address), findsNothing);
    });

    testWidgets('reads Lihat Detail for an ordinary page', (tester) async {
      await pumpPage(
        tester,
        state: NotificationLoaded([tUnread.copyWithLink(address)]),
      );

      expect(find.text('Lihat Detail'), findsOneWidget);
      expect(find.text('Isi Formulir'), findsNothing);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    });

    testWidgets('reads Isi Formulir for a Google Form', (tester) async {
      await pumpPage(
        tester,
        state: NotificationLoaded([
          tUnread.copyWithLink('https://forms.gle/AbCdEf123'),
        ]),
      );

      expect(find.text('Isi Formulir'), findsOneWidget);
      expect(find.text('Lihat Detail'), findsNothing);
      expect(find.byIcon(Icons.edit_note), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsNothing);
    });

    testWidgets('each message gets the wording of its own link', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: NotificationLoaded([
          tUnread.copyWithLink('https://forms.gle/AbCdEf123'),
          tRead.copyWithLink(address),
        ]),
      );

      Finder inRow(String id, String text) => find.descendant(
        of: find.byKey(Key('notification-$id')),
        matching: find.text(text),
      );

      expect(inRow('N1', 'Isi Formulir'), findsOneWidget);
      expect(inRow('N2', 'Lihat Detail'), findsOneWidget);
    });

    for (final link in [
      '',
      '   ',
      '-',
      'fixupmoto.com/promo',
      'ftp://fixupmoto.com/file',
      'not a link',
    ]) {
      testWidgets('is not there for the link "$link"', (tester) async {
        await pumpPage(
          tester,
          state: NotificationLoaded([tUnread.copyWithLink(link)]),
        );

        expect(button, findsNothing);
      });
    }

    testWidgets('sits under the message, starting where its text does, with '
        'the date opposite', (tester) async {
      await pumpPage(
        tester,
        state: NotificationLoaded([tRead.copyWithLink(address)]),
      );

      final row = find.byKey(const Key('notification-N2'));
      final message = find.text('Jangan lupa servis motor Anda');
      final date = find.text('5 Dec 2023');

      expect(
        tester.getTopLeft(button).dy,
        greaterThan(tester.getBottomLeft(message).dy - 1),
      );
      // The label lines up with the message above it, not indented from it.
      expect(
        tester.getTopLeft(button).dx,
        closeTo(tester.getTopLeft(message).dx, 1),
      );
      // The date is on the same line, at the far end.
      expect(date, findsOneWidget);
      expect(
        tester.getCenter(date).dy,
        closeTo(tester.getCenter(button).dy, 8),
      );
      expect(
        tester.getTopLeft(date).dx,
        greaterThan(tester.getTopRight(button).dx),
      );
      expect(
        tester.getTopRight(date).dx,
        lessThanOrEqualTo(tester.getTopRight(row).dx - 12 + 0.5),
      );
    });

    testWidgets('is dark red on an unread row and on a read one', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: NotificationLoaded([
          tUnread.copyWithLink(address),
          tRead.copyWithLink(address),
        ]),
      );

      Color colourOfButton(String id) => tester
          .widget<TextButton>(find.byKey(Key('notification-link-$id')))
          .style!
          .foregroundColor!
          .resolve({})!;

      // Not white (the old fill) and not the brand orange, which is too faint
      // for small text on a light row.
      expect(colourOfButton('N1'), AppColors.primaryDark);
      expect(colourOfButton('N2'), AppColors.primaryDark);
    });

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

    testWidgets('opens the address outside the app', (tester) async {
      final calls = mockLauncher(opens: true);
      await pumpPage(
        tester,
        state: NotificationLoaded([tUnread.copyWithLink(address)]),
      );

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'launch');
      expect((calls.single.arguments as Map)['url'], address);
      expect(find.text('Tautan tidak dapat dibuka'), findsNothing);
    });

    testWidgets('says so when the address cannot be opened', (tester) async {
      mockLauncher(opens: false);
      await pumpPage(
        tester,
        state: NotificationLoaded([tUnread.copyWithLink(address)]),
      );

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Tautan tidak dapat dibuka'), findsOneWidget);
    });
  });

  group('the Tandai sudah dibaca button', () {
    final button = find.text('Tandai sudah dibaca');
    final unreadButton = find.byKey(const Key('notification-mark-read-N1'));

    testWidgets('is on an unread message and not on a read one', (
      tester,
    ) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread, tRead]));

      expect(button, findsOneWidget);
      expect(unreadButton, findsOneWidget);
      expect(find.byKey(const Key('notification-mark-read-N2')), findsNothing);
    });

    testWidgets('sits on a line of its own under the message and the link, '
        'starting where the message does', (tester) async {
      await pumpPage(
        tester,
        state: NotificationLoaded([
          tUnread.copyWithLink('https://forms.gle/abc123'),
        ]),
      );

      final message = find.text(
        'Booking Service Anda Telah Dikonfirmasi.\nTerima Kasih',
      );
      final link = find.byKey(const Key('notification-link-N1'));

      expect(
        tester.getTopLeft(unreadButton).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(link).dy - 1),
      );
      expect(
        tester.getTopLeft(unreadButton).dx,
        closeTo(tester.getTopLeft(message).dx, 1),
      );
    });

    testWidgets('is dark red, like the link', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread]));

      expect(
        tester
            .widget<TextButton>(unreadButton)
            .style!
            .foregroundColor!
            .resolve({}),
        AppColors.primaryDark,
      );
    });

    testWidgets('asks the bloc to mark that message, and tapping the row '
        'itself does nothing', (tester) async {
      final bloc = await pumpPage(
        tester,
        state: NotificationLoaded([tUnread, tRead]),
      );

      await tester.tap(find.text('Jangan lupa servis motor Anda'));
      await tester.tap(find.byKey(const Key('notification-N1')));
      await tester.pump();
      verifyNever(() => bloc.add(const NotificationMarkReadRequested('N1')));

      await tester.tap(button);
      await tester.pump();

      verify(
        () => bloc.add(const NotificationMarkReadRequested('N1')),
      ).called(1);
    });

    testWidgets('waits with a spinner, and cannot be tapped again, while the '
        'server answers', (tester) async {
      final bloc = await pumpPage(
        tester,
        state: NotificationLoaded([tUnread], markingRead: const {'N1'}),
      );

      expect(find.byKey(const Key('mark-read-progress')), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsNothing);
      expect(tester.widget<TextButton>(unreadButton).onPressed, isNull);

      await tester.tap(unreadButton, warnIfMissed: false);
      await tester.pump();
      verifyNever(() => bloc.add(const NotificationMarkReadRequested('N1')));
    });

    testWidgets('shows the tick, not the spinner, when nothing is waiting', (
      tester,
    ) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread]));

      expect(find.byKey(const Key('mark-read-progress')), findsNothing);
      expect(find.byIcon(Icons.done_all), findsOneWidget);
      expect(tester.widget<TextButton>(unreadButton).onPressed, isNotNull);
    });

    testWidgets('is gone, with the dot and the unread count, once the message '
        'is read', (tester) async {
      await pumpPage(
        tester,
        state: NotificationLoaded([tUnread, tRead]),
        thenEmits: Stream.value(NotificationLoaded([tUnread.asRead(), tRead])),
      );
      await tester.pump();

      expect(button, findsNothing);
      expect(find.byKey(const Key('unread-dot-N1')), findsNothing);
      expect(find.byKey(const Key('notification-unread-count')), findsNothing);
      // The message itself is still there, where it was.
      expect(find.byKey(const Key('notification-N1')), findsOneWidget);
    });

    group('when the server refuses', () {
      final snackBar = find.byType(SnackBar);

      testWidgets('says why in a snackbar that can be closed, and keeps the '
          'message unread', (tester) async {
        await pumpPage(
          tester,
          state: NotificationLoaded([tUnread]),
          thenEmits: Stream.fromIterable([
            NotificationLoaded([
              tUnread,
            ], markReadError: 'Notifikasi tidak ada'),
            NotificationLoaded([tUnread]),
          ]),
        );
        await tester.pump();
        await tester.pump();

        expect(snackBar, findsOneWidget);
        expect(
          find.descendant(
            of: snackBar,
            matching: find.text('Notifikasi tidak ada'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: snackBar, matching: find.byIcon(Icons.close)),
          findsOneWidget,
        );
        // Still unread, and still offering the button.
        expect(find.byKey(const Key('unread-dot-N1')), findsOneWidget);
        expect(unreadButton, findsOneWidget);
      });

      testWidgets('tidies a reason the backend shouted in capitals', (
        tester,
      ) async {
        await pumpPage(
          tester,
          state: NotificationLoaded([tUnread]),
          thenEmits: Stream.fromIterable([
            NotificationLoaded([
              tUnread,
            ], markReadError: 'NOTIFIKASI TIDAK ADA'),
          ]),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Notifikasi Tidak Ada'), findsOneWidget);
        expect(find.text('NOTIFIKASI TIDAK ADA'), findsNothing);
      });

      testWidgets('translates an English failure message', (tester) async {
        await pumpPage(
          tester,
          state: NotificationLoaded([tUnread]),
          thenEmits: Stream.fromIterable([
            NotificationLoaded([
              tUnread,
            ], markReadError: 'No internet connection'),
          ]),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Tidak ada koneksi internet'), findsOneWidget);
      });

      testWidgets('says nothing when there was no refusal', (tester) async {
        await pumpPage(
          tester,
          state: NotificationLoaded([tUnread]),
          thenEmits: Stream.fromIterable([
            NotificationLoaded([tUnread], markingRead: const {'N1'}),
            NotificationLoaded([tUnread.asRead()]),
          ]),
        );
        await tester.pump();
        await tester.pump();

        expect(snackBar, findsNothing);
      });
    });
  });

  group('the inbox', () {
    testWidgets('shows each message\'s type, text and date', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread, tRead]));

      expect(find.text('Booking Service Terkonfirmasi'), findsOneWidget);
      expect(
        find.text('Booking Service Anda Telah Dikonfirmasi.\nTerima Kasih'),
        findsOneWidget,
      );
      expect(find.text('12 Dec 2023'), findsOneWidget);

      expect(find.text('Service Reminder'), findsOneWidget);
      expect(find.text('Jangan lupa servis motor Anda'), findsOneWidget);
      expect(find.text('5 Dec 2023'), findsOneWidget);
      expect(spinner, findsNothing);
    });

    testWidgets('lists them in the order they arrive', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tRead, tUnread]));

      expect(
        tester.getTopLeft(find.byKey(const Key('notification-N2'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('notification-N1'))).dy,
        ),
      );
    });

    testWidgets('only an unread message has the dot', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread, tRead]));

      expect(find.byKey(const Key('unread-dot-N1')), findsOneWidget);
      expect(find.byKey(const Key('unread-dot-N2')), findsNothing);
    });

    testWidgets('an unread title is bolder than a read one', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread, tRead]));

      FontWeight? weightOf(String text) =>
          tester.widget<Text>(find.text(text)).style?.fontWeight;

      expect(weightOf('Booking Service Terkonfirmasi'), FontWeight.w700);
      expect(weightOf('Service Reminder'), FontWeight.w500);
    });

    testWidgets('text lines up whether or not there is a dot', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread, tRead]));

      expect(
        tester.getTopLeft(find.text('Booking Service Terkonfirmasi')).dx,
        tester.getTopLeft(find.text('Service Reminder')).dx,
      );
    });

    testWidgets('a message with no readable date simply has no date line', (
      tester,
    ) async {
      final undated = NotificationEntity(
        memberId: '0101202300000003',
        id: 'N3',
        type: 'Promo',
        message: 'Hemat banyak',
        date: null,
        isSent: true,
        isRead: true,
        numberOfNotifications: 0,
        image: '',
        link: '',
      );
      await pumpPage(tester, state: NotificationLoaded([undated]));

      expect(find.text('Promo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is readable in dark mode: dark text on a read row', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: NotificationLoaded([tRead]),
        theme: ThemeData.dark(),
      );

      // The row is light grey in dark mode too, so white text would vanish.
      expect(
        colourOf(tester, 'Service Reminder').computeLuminance(),
        lessThan(0.4),
      );
      expect(
        colourOf(tester, 'Jangan lupa servis motor Anda').computeLuminance(),
        lessThan(0.5),
      );
    });

    testWidgets('is readable in dark mode: dark text on an unread row too', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: NotificationLoaded([tUnread.copyWithLink('https://x.id/a')]),
        theme: ThemeData.dark(),
      );

      // The tint is pale in dark mode too, so white text would vanish.
      expect(
        colourOf(tester, 'Booking Service Terkonfirmasi').computeLuminance(),
        lessThan(0.4),
      );
      expect(
        colourOf(
          tester,
          'Booking Service Anda Telah Dikonfirmasi.\nTerima Kasih',
        ).computeLuminance(),
        lessThan(0.5),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the type is shown in Indonesian', () {
    testWidgets('a known type is translated', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread]));

      expect(find.text('Booking Service Terkonfirmasi'), findsOneWidget);
      expect(find.text('Service Booking Confirmed'), findsNothing);
    });

    testWidgets('a type with no translation is shown as the backend sent it', (
      tester,
    ) async {
      await pumpPage(tester, state: NotificationLoaded([tRead]));

      expect(find.text('Service Reminder'), findsOneWidget);
    });

    testWidgets(
      'the raw type reaches the page untouched (only display changes)',
      (tester) async {
        // The entity keeps what the backend sent; translating is display only.
        expect(tUnread.type, 'Service Booking Confirmed');
      },
    );
  });

  group('the rows', () {
    final unreadRow = find.byKey(const Key('notification-N1'));
    final readRow = find.byKey(const Key('notification-N2'));

    Color? fillOf(WidgetTester tester, Finder row) =>
        tester.widget<Container>(row).color;

    testWidgets('an unread row has a very pale peach tint', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread, tRead]));

      expect(fillOf(tester, unreadRow), AppColors.peachMist);
    });

    testWidgets('a read row is plain: no tint', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread, tRead]));

      expect(fillOf(tester, readRow), isNull);
    });

    testWidgets('unread text is dark, not white, and the dot is the brand '
        'colour', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread]));

      expect(
        colourOf(tester, 'Booking Service Terkonfirmasi').computeLuminance(),
        lessThan(0.4),
      );
      expect(
        colourOf(
          tester,
          'Booking Service Anda Telah Dikonfirmasi.\nTerima Kasih',
        ).computeLuminance(),
        lessThan(0.5),
      );
      expect(colourOf(tester, '12 Dec 2023').computeLuminance(), lessThan(0.5));

      final dot = tester.widget<Container>(
        find.byKey(const Key('unread-dot-N1')),
      );
      expect((dot.decoration! as BoxDecoration).color, AppColors.primary);
    });

    testWidgets('read text is not white', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tRead]));

      expect(
        colourOf(tester, 'Service Reminder'),
        isNot(AppColors.textOnPrimary),
      );
      expect(
        colourOf(tester, 'Jangan lupa servis motor Anda').computeLuminance(),
        lessThan(0.5),
      );
    });

    testWidgets('the dot is announced to a screen reader as unread', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester, state: NotificationLoaded([tUnread, tRead]));

      expect(find.bySemanticsLabel('Belum dibaca'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('add no border, corner or shadow of their own', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread, tRead]));

      for (final row in [unreadRow, readRow]) {
        // A Container given only a `color` has no decoration at all: nothing
        // to hold a border, a radius or a shadow.
        expect(tester.widget<Container>(row).decoration, isNull);
      }
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('sit in one rounded card, split by a single hairline', (
      tester,
    ) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread, tRead]));

      final card = find.byType(SectionCard);
      expect(card, findsOneWidget);
      for (final row in [unreadRow, readRow]) {
        expect(find.descendant(of: card, matching: row), findsOneWidget);
      }
      expect(
        find.descendant(of: card, matching: find.byType(Divider)),
        findsOneWidget,
      );
    });

    testWidgets('the card is inset 16 px from both edges of the screen', (
      tester,
    ) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread, tRead]));

      final screen = tester.getSize(find.byType(MaterialApp)).width;
      final card = find.byType(SectionCard);
      expect(tester.getTopLeft(card).dx, 16);
      expect(tester.getSize(card).width, screen - 32);
    });

    testWidgets('the first heading starts below the app bar', (tester) async {
      await pumpPage(
        tester,
        state: NotificationLoaded([tUnread.copyWithDate('T1', DateTime.now())]),
      );

      expect(
        tester.getTopLeft(find.text('Hari ini')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy),
      );
    });

    testWidgets('the date is under the message, at the far end', (
      tester,
    ) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread]));

      final row = find.byKey(const Key('notification-N1'));
      final date = find.text('12 Dec 2023');
      final message = find.text(
        'Booking Service Anda Telah Dikonfirmasi.\nTerima Kasih',
      );

      expect(
        tester.getTopLeft(date).dy,
        greaterThan(tester.getBottomLeft(message).dy - 1),
      );
      // Right edge of the text column, inside the row's 12 px of padding.
      expect(
        tester.getTopRight(date).dx,
        closeTo(tester.getTopRight(row).dx - 12, 0.5),
      );
    });

    testWidgets('text lines up whether or not there is a dot', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread, tRead]));

      expect(
        tester.getTopLeft(find.text('Booking Service Terkonfirmasi')).dx,
        tester.getTopLeft(find.text('Service Reminder')).dx,
      );
    });

    testWidgets('a long title wraps instead of pushing the dot or date off '
        'the row', (tester) async {
      final long = NotificationEntity(
        memberId: '0101202300000003',
        id: 'N9',
        type:
            'Pengingat Servis Berkala Sepeda Motor Matic Anda Yang Sudah Jatuh Tempo',
        message: 'x',
        date: DateTime(2023, 12, 12),
        isSent: true,
        isRead: false,
        numberOfNotifications: 0,
        image: '',
        link: '',
      );
      await pumpPage(tester, state: NotificationLoaded([long]));

      expect(tester.takeException(), isNull);
      final rowRight = tester
          .getTopRight(find.byKey(const Key('notification-N9')))
          .dx;
      expect(
        tester.getTopRight(find.text('12 Dec 2023')).dx,
        lessThanOrEqualTo(rowRight - 12 + 0.5),
      );
      expect(
        tester.getTopRight(find.byKey(const Key('unread-dot-N9'))).dx,
        lessThanOrEqualTo(rowRight - 12 + 0.5),
      );
    });

    group('the icon tile', () {
      Finder iconIn(String id, IconData icon) => find.descendant(
        of: find.byKey(Key('notification-icon-$id')),
        matching: find.byIcon(icon),
      );

      testWidgets('follows the type: a booking, a reminder', (tester) async {
        await pumpPage(tester, state: NotificationLoaded([tUnread, tRead]));

        expect(iconIn('N1', Icons.calendar_month_outlined), findsOneWidget);
        expect(iconIn('N2', Icons.build_outlined), findsOneWidget);
      });

      testWidgets('is a bell for a type it does not know', (tester) async {
        final promo = NotificationEntity(
          memberId: '0101202300000003',
          id: 'N5',
          type: 'Promo',
          message: 'Hemat banyak',
          date: DateTime(2023, 12, 12),
          isSent: true,
          isRead: true,
          numberOfNotifications: 0,
          image: '',
          link: '',
        );
        await pumpPage(tester, state: NotificationLoaded([promo]));

        expect(iconIn('N5', Icons.notifications_outlined), findsOneWidget);
      });

      testWidgets('is deeper on an unread row, so the tint does not '
          'swallow it', (tester) async {
        await pumpPage(tester, state: NotificationLoaded([tUnread, tRead]));

        Color? tileOf(String id) {
          final tile = tester.widget<Container>(
            find.byKey(Key('notification-icon-$id')),
          );
          return (tile.decoration! as BoxDecoration).color;
        }

        expect(tileOf('N1'), AppColors.peachLight);
        expect(tileOf('N2'), AppColors.peachMist);
      });
    });
  });

  group('the day groups', () {
    final now = DateTime.now();
    final tToday = tUnread.copyWithDate('T1', now);
    final tYesterday = tRead.copyWithDate(
      'Y1',
      now.subtract(const Duration(days: 1)),
    );
    final tOlder = tRead.copyWithDate('O1', DateTime(2023, 12, 5));

    Finder heading(String label) => find.text(label);

    testWidgets('put Hari ini and Kemarin above their messages, and give older '
        'ones no heading', (tester) async {
      await pumpPage(
        tester,
        state: NotificationLoaded([tToday, tYesterday, tOlder]),
      );

      expect(
        tester.getTopLeft(heading('Hari ini')).dy,
        lessThan(tester.getTopLeft(heading('Kemarin')).dy),
      );
      // Each day sits in its own card, the older one without a heading.
      expect(find.byType(SectionCard), findsNWidgets(3));
      expect(
        tester.getTopLeft(heading('Hari ini')).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('notification-T1'))).dy,
        ),
      );
      expect(
        tester.getTopLeft(heading('Kemarin')).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('notification-Y1'))).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('notification-O1'))).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const Key('notification-Y1'))).dy,
        ),
      );
      expect(heading('Sebelumnya'), findsNothing);
    });

    testWidgets('show no heading at all when every message is older', (
      tester,
    ) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread, tRead]));

      expect(heading('Hari ini'), findsNothing);
      expect(heading('Kemarin'), findsNothing);
      expect(heading('Sebelumnya'), findsNothing);
      // The messages are still there, in their card.
      expect(find.byType(SectionCard), findsOneWidget);
      expect(find.byKey(const Key('notification-N1')), findsOneWidget);
      expect(find.byKey(const Key('notification-N2')), findsOneWidget);
    });

    testWidgets('leave a message with no date without a heading', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: NotificationLoaded([tUnread.copyWithDate('U1', null)]),
      );

      expect(heading('Sebelumnya'), findsNothing);
      expect(find.byKey(const Key('notification-U1')), findsOneWidget);
    });

    testWidgets('keep the order the messages arrive in, repeating a heading '
        'rather than reordering', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tOlder, tToday]));

      expect(
        tester.getTopLeft(find.byKey(const Key('notification-O1'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('notification-T1'))).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('notification-O1'))).dy,
        lessThan(tester.getTopLeft(heading('Hari ini')).dy),
      );
    });
  });

  group('the unread count', () {
    final count = find.byKey(const Key('notification-unread-count'));

    testWidgets('sits quietly under the title', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread, tRead]));

      expect(find.text('1 belum dibaca'), findsOneWidget);
      expect(
        tester.getTopLeft(count).dy,
        greaterThan(tester.getBottomLeft(find.text('Kotak Masuk')).dy - 1),
      );
      expect(
        tester.getTopLeft(count).dx,
        tester.getTopLeft(find.text('Kotak Masuk')).dx,
      );
    });

    testWidgets('counts every unread message that is shown', (tester) async {
      await pumpPage(
        tester,
        state: NotificationLoaded([tUnread, tUnread.copyWithId('N3'), tRead]),
      );

      expect(find.text('2 belum dibaca'), findsOneWidget);
    });

    testWidgets('is not there when everything is read', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tRead]));

      expect(count, findsNothing);
    });

    for (final state in <NotificationState>[
      const NotificationLoading(),
      const NotificationError('boom'),
      const NotificationLoaded([]),
    ]) {
      testWidgets('is not there for ${state.runtimeType}', (tester) async {
        await pumpPage(tester, state: state);

        expect(count, findsNothing);
        // The title itself always is.
        expect(find.text('Kotak Masuk'), findsOneWidget);
      });
    }
  });

  group('the backdrop', () {
    testWidgets('is the warm wash of the Profile page, behind a transparent '
        'app bar', (tester) async {
      await pumpPage(tester, state: NotificationLoaded([tUnread]));

      expect(find.byType(WarmWash), findsOneWidget);

      final scaffold = tester.widget<Scaffold>(
        find.descendant(
          of: find.byType(WarmWash),
          matching: find.byType(Scaffold),
        ),
      );
      expect(scaffold.backgroundColor, Colors.transparent);
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        Colors.transparent,
      );
    });

    testWidgets('stays light in dark mode, like the cards on it', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: NotificationLoaded([tUnread]),
        theme: ThemeData.dark(),
      );

      final wash = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(WarmWash),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(wash.color.computeLuminance(), greaterThan(0.5));
    });
  });

  group('the filter', () {
    final filterButton = find.byTooltip('Filter');

    PanelController panelOf(WidgetTester tester) =>
        tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel)).controller!;

    Future<void> openPanel(WidgetTester tester) async {
      await tester.tap(filterButton);
      await tester.pumpAndSettle();
    }

    Future<void> tick(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
    }

    bool isTicked(WidgetTester tester, String key) =>
        tester.widget<CheckboxListTile>(find.byKey(Key(key))).value!;

    Future<void> apply(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('filter-apply')));
      await tester.pumpAndSettle();
    }

    NotificationsRequested request(String isSent, String isRead) =>
        NotificationsRequested(isSent: isSent, isRead: isRead);

    final inbox = NotificationLoaded([tUnread, tRead]);

    testWidgets('the app bar has a filter button', (tester) async {
      await pumpPage(tester, state: inbox);

      expect(filterButton, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.tune),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the panel starts closed, and the button opens it', (
      tester,
    ) async {
      await pumpPage(tester, state: inbox);
      expect(panelOf(tester).isPanelClosed, isTrue);

      await openPanel(tester);

      expect(panelOf(tester).isPanelOpen, isTrue);
      expect(find.text('Filter Notifikasi'), findsOneWidget);
    });

    testWidgets('has two fields of two checkboxes each, in Indonesian', (
      tester,
    ) async {
      await pumpPage(tester, state: inbox);
      await openPanel(tester);

      expect(find.text('Status Kirim'), findsOneWidget);
      expect(find.text('Terkirim'), findsOneWidget);
      expect(find.text('Belum terkirim'), findsOneWidget);
      expect(find.text('Status Baca'), findsOneWidget);
      expect(find.text('Sudah dibaca'), findsOneWidget);
      expect(find.text('Belum dibaca'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(4));
    });

    testWidgets('the boxes start as the defaults: sent only, read and unread', (
      tester,
    ) async {
      await pumpPage(tester, state: inbox);
      await openPanel(tester);

      expect(isTicked(tester, 'filter-sent-yes'), isTrue);
      expect(isTicked(tester, 'filter-sent-no'), isFalse);
      expect(isTicked(tester, 'filter-read-yes'), isTrue);
      expect(isTicked(tester, 'filter-read-no'), isTrue);
    });

    testWidgets('ticking boxes changes nothing until Terapkan', (tester) async {
      final bloc = await pumpPage(tester, state: inbox);
      await openPanel(tester);

      await tick(tester, 'filter-read-yes');
      await tick(tester, 'filter-sent-no');

      expect(isTicked(tester, 'filter-read-yes'), isFalse);
      expect(isTicked(tester, 'filter-sent-no'), isTrue);
      // Only the request made when the page opened.
      verify(() => bloc.add(any())).called(1);
    });

    testWidgets('Terapkan reloads the inbox with the filter, and closes', (
      tester,
    ) async {
      final bloc = await pumpPage(tester, state: inbox);
      await openPanel(tester);

      await tick(tester, 'filter-read-yes'); // leaves "unread" only
      await apply(tester);

      verify(() => bloc.add(request('1', '0'))).called(1);
      expect(panelOf(tester).isPanelClosed, isTrue);
    });

    group('the checkboxes become the backend\'s parameters', () {
      for (final (name, taps, isSent, isRead) in [
        ('sent only (the default)', <String>[], '1', ''),
        ('not-sent only', ['filter-sent-yes', 'filter-sent-no'], '0', ''),
        ('sent and not-sent', ['filter-sent-no'], '', ''),
        ('neither sent box', ['filter-sent-yes'], '', ''),
        ('read only', ['filter-read-no'], '1', '1'),
        ('unread only', ['filter-read-yes'], '1', '0'),
        ('neither read box', ['filter-read-yes', 'filter-read-no'], '1', ''),
      ]) {
        testWidgets('$name: IsSent "$isSent", IsRead "$isRead"', (
          tester,
        ) async {
          final bloc = await pumpPage(tester, state: inbox);
          await openPanel(tester);

          for (final key in taps) {
            await tick(tester, key);
          }
          await apply(tester);

          // Opening the page already asked once with the defaults, so a
          // filter equal to the defaults has been asked for twice by now.
          final isDefaultRequest = isSent == '1' && isRead == '';
          verify(
            () => bloc.add(request(isSent, isRead)),
          ).called(isDefaultRequest ? 2 : 1);
        });
      }
    });

    testWidgets('Atur Ulang puts the defaults back, applies them and closes', (
      tester,
    ) async {
      final bloc = await pumpPage(tester, state: inbox);
      await openPanel(tester);
      await tick(tester, 'filter-read-yes');
      await tick(tester, 'filter-sent-no');
      await apply(tester); // a changed filter, applied

      await openPanel(tester);
      await tester.tap(find.byKey(const Key('filter-reset')));
      await tester.pumpAndSettle();

      // The page-open request and the reset are both the defaults.
      verify(() => bloc.add(request('1', ''))).called(2);
      expect(panelOf(tester).isPanelClosed, isTrue);

      await openPanel(tester);
      expect(isTicked(tester, 'filter-sent-yes'), isTrue);
      expect(isTicked(tester, 'filter-sent-no'), isFalse);
      expect(isTicked(tester, 'filter-read-yes'), isTrue);
      expect(isTicked(tester, 'filter-read-no'), isTrue);
    });

    testWidgets('boxes ticked but never applied are discarded on close', (
      tester,
    ) async {
      await pumpPage(tester, state: inbox);
      await openPanel(tester);
      await tick(tester, 'filter-read-yes');
      expect(isTicked(tester, 'filter-read-yes'), isFalse);

      // Not awaited: the controller's future completes only as the closing
      // animation plays, which needs the pumps below.
      unawaited(panelOf(tester).close());
      await tester.pumpAndSettle();
      await openPanel(tester);

      expect(isTicked(tester, 'filter-read-yes'), isTrue);
    });

    testWidgets('the applied filter is what the boxes show next time', (
      tester,
    ) async {
      await pumpPage(tester, state: inbox);
      await openPanel(tester);
      await tick(tester, 'filter-read-yes');
      await apply(tester);

      await openPanel(tester);

      expect(isTicked(tester, 'filter-read-yes'), isFalse);
      expect(isTicked(tester, 'filter-read-no'), isTrue);
    });

    testWidgets('tapping the dimmed area closes the panel', (tester) async {
      await pumpPage(tester, state: inbox);
      await openPanel(tester);

      // Above the panel, over the dimmed list.
      await tester.tapAt(const Offset(400, 90));
      await tester.pumpAndSettle();

      expect(panelOf(tester).isPanelClosed, isTrue);
    });

    testWidgets('pull-to-refresh keeps the applied filter', (tester) async {
      final bloc = await pumpPage(tester, state: inbox);
      await openPanel(tester);
      await tick(tester, 'filter-read-yes');
      await apply(tester);

      await tester.drag(find.text('Service Reminder'), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Once for Terapkan, once for the pull — both with the filter.
      verify(() => bloc.add(request('1', '0'))).called(2);
    });

    testWidgets('the retry button keeps the applied filter', (tester) async {
      final bloc = await pumpPage(
        tester,
        state: const NotificationError('Gagal memuat'),
      );
      await openPanel(tester);
      await tick(tester, 'filter-read-no'); // leaves "read" only
      await apply(tester);

      await tester.tap(find.byKey(const Key('notification-retry')));
      await tester.pump();

      verify(() => bloc.add(request('1', '1'))).called(2);
    });

    group('the panel wraps the whole screen, app bar included', () {
      testWidgets('the Scaffold and its app bar are inside the panel', (
        tester,
      ) async {
        await pumpPage(tester, state: inbox);

        final panel = find.byType(SlidingUpPanel);
        expect(panel, findsOneWidget);
        expect(
          find.descendant(of: panel, matching: find.byType(Scaffold)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: panel, matching: find.byType(AppBar)),
          findsOneWidget,
        );
        // And the panel is the page's outermost widget, not inside a Scaffold.
        expect(
          find.ancestor(of: panel, matching: find.byType(Scaffold)),
          findsNothing,
        );
      });

      testWidgets('open, the backdrop catches taps on the app bar', (
        tester,
      ) async {
        await pumpPage(tester, state: inbox);
        await openPanel(tester);

        // The back button would pop the route (and, with no router in this
        // test, throw) if the tap got through. The dimmed backdrop above it
        // takes the tap instead and just closes the panel.
        await tester.tap(find.byIcon(Icons.arrow_back), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(panelOf(tester).isPanelClosed, isTrue);
        expect(find.byType(NotificationPage), findsOneWidget);
      });

      testWidgets('open, tapping the app bar title closes the panel', (
        tester,
      ) async {
        await pumpPage(tester, state: inbox);
        await openPanel(tester);

        await tester.tap(find.text('Kotak Masuk'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(panelOf(tester).isPanelClosed, isTrue);
      });

      testWidgets('closed, the app bar buttons work as usual', (tester) async {
        await pumpPage(tester, state: inbox);

        // The filter button still opens the panel: nothing covers the bar.
        await tester.tap(filterButton);
        await tester.pumpAndSettle();

        expect(panelOf(tester).isPanelOpen, isTrue);
      });

      testWidgets(
        'the list reaches the bottom edge: its last row is not hidden',
        (tester) async {
          // SlidingUpPanel sizes its `body` to the full screen. Inside the
          // Scaffold's body that made the list taller than the space under the
          // app bar, pushing the end of the list off the bottom of the screen.
          final many = [
            for (var i = 0; i < 20; i++)
              NotificationEntity(
                memberId: '0101202300000003',
                id: 'L$i',
                type: 'Service Reminder',
                message: 'Pesan $i',
                date: DateTime(2023, 12, 1),
                isSent: true,
                isRead: true,
                numberOfNotifications: 0,
                image: '',
                link: '',
              ),
          ];
          await pumpPage(tester, state: NotificationLoaded(many));

          await tester.dragUntilVisible(
            find.byKey(const Key('notification-L19')),
            find.byType(ListView),
            const Offset(0, -300),
          );
          await tester.pumpAndSettle();

          final screenHeight =
              tester.view.physicalSize.height / tester.view.devicePixelRatio;
          expect(
            tester.getBottomLeft(find.byKey(const Key('notification-L19'))).dy,
            lessThanOrEqualTo(screenHeight),
          );
        },
      );
    });

    testWidgets('opening the page asks with the defaults', (tester) async {
      final bloc = await pumpPage(tester, state: inbox);

      verify(() => bloc.add(request('1', ''))).called(1);
    });
  });

  group('empty', () {
    testWidgets('says there is nothing yet', (tester) async {
      await pumpPage(tester, state: const NotificationLoaded([]));

      expect(find.text('Belum ada notifikasi'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });
  });

  group('error', () {
    testWidgets(
      'shows the message in Indonesian, with a retry that asks again',
      (tester) async {
        final bloc = await pumpPage(
          tester,
          state: const NotificationError('No internet connection'),
        );

        expect(find.text('Tidak ada koneksi internet'), findsOneWidget);
        expect(find.text('No internet connection'), findsNothing);
        expect(find.text('Coba lagi'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
        verify(() => bloc.add(const NotificationsRequested())).called(1);

        await tester.tap(find.byKey(const Key('notification-retry')));
        await tester.pump();

        // Once on open, once for the retry.
        verify(() => bloc.add(const NotificationsRequested())).called(1);
      },
    );

    testWidgets('a message with no translation is shown as it came', (
      tester,
    ) async {
      await pumpPage(tester, state: const NotificationError('Gagal memuat'));

      expect(find.text('Gagal memuat'), findsOneWidget);
    });
  });

  group('pull to refresh', () {
    Future<void> pullDown(WidgetTester tester, Finder from) async {
      await tester.drag(from, const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    testWidgets('reloads the inbox', (tester) async {
      final bloc = await pumpPage(
        tester,
        state: NotificationLoaded([tUnread, tRead]),
      );

      await pullDown(tester, find.text('Booking Service Terkonfirmasi'));

      // Once on open, once for the pull.
      verify(() => bloc.add(const NotificationsRequested())).called(2);
    });

    testWidgets('works on a short list too', (tester) async {
      final bloc = await pumpPage(tester, state: NotificationLoaded([tRead]));

      await pullDown(tester, find.text('Service Reminder'));

      verify(() => bloc.add(const NotificationsRequested())).called(2);
    });

    testWidgets('works on an empty inbox too', (tester) async {
      final bloc = await pumpPage(tester, state: const NotificationLoaded([]));

      await pullDown(tester, find.text('Belum ada notifikasi'));

      verify(() => bloc.add(const NotificationsRequested())).called(2);
    });

    testWidgets('keeps the list on screen while it reloads, then swaps it', (
      tester,
    ) async {
      final states = StreamController<NotificationState>();
      addTearDown(states.close);
      await pumpPage(
        tester,
        state: NotificationLoaded([tRead]),
        thenEmits: states.stream,
      );
      expect(find.text('Service Reminder'), findsOneWidget);

      // Reloading: no spinner replaces the list...
      states.add(const NotificationLoading());
      await tester.pump();
      await tester.pump();
      expect(find.text('Service Reminder'), findsOneWidget);
      expect(spinner, findsNothing);

      // ...until the answer arrives.
      states.add(NotificationLoaded([tUnread]));
      await tester.pump();
      await tester.pump();
      expect(find.text('Booking Service Terkonfirmasi'), findsOneWidget);
      expect(find.text('Service Reminder'), findsNothing);
    });

    testWidgets('a failed reload shows the error', (tester) async {
      final states = StreamController<NotificationState>();
      addTearDown(states.close);
      await pumpPage(
        tester,
        state: NotificationLoaded([tRead]),
        thenEmits: states.stream,
      );

      states.add(const NotificationLoading());
      states.add(const NotificationError('Gagal memuat'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Gagal memuat'), findsOneWidget);
      expect(find.text('Service Reminder'), findsNothing);
    });
  });

  testWidgets('a first load does show the spinner, then the inbox', (
    tester,
  ) async {
    final states = StreamController<NotificationState>();
    addTearDown(states.close);
    await pumpPage(
      tester,
      state: const NotificationLoading(),
      thenEmits: states.stream,
    );
    expect(spinner, findsOneWidget);

    states.add(NotificationLoaded([tUnread]));
    await tester.pump();
    await tester.pump();

    expect(spinner, findsNothing);
    expect(find.text('Booking Service Terkonfirmasi'), findsOneWidget);
  });
}

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_bloc.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_event.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_state.dart';
import 'package:fix_up_moto/features/services/presentation/pages/services_page.dart';
import 'package:fix_up_moto/features/services/presentation/widgets/service_card.dart';

class MockServicesBloc extends MockBloc<ServicesEvent, ServicesState>
    implements ServicesBloc {}

ServiceEntity service({
  required String transNo,
  String bsName = 'FIXUP MOTO - KUTISARI',
  String transDate = '2026-10-05',
  String eName = 'NURUL FAHMI AZIS',
}) {
  return ServiceEntity(
    bsName: bsName,
    transNo: transNo,
    transDate: transDate,
    eName: eName,
    amountService: 60000,
    amountPart: 5000,
    detail: const [],
    detail2: const [],
  );
}

// Three past visits at different branches, by different mechanics.
final march = service(
  transNo: 'T-MARCH',
  bsName: 'FIXUP MOTO - KUTISARI',
  transDate: '2026-03-10',
  eName: 'NURUL FAHMI AZIS',
);
final june = service(
  transNo: 'T-JUNE',
  bsName: 'FIXUP MOTO - KEDUNG TARUKAN',
  transDate: '2026-06-20',
  eName: 'BUDI SANTOSO',
);
final october = service(
  transNo: 'T-OCTOBER',
  bsName: 'FIXUP MOTO - KUTISARI',
  transDate: '2026-10-05',
  eName: 'SITI RAHAYU',
);

void main() {
  late MockServicesBloc bloc;

  setUpAll(
    () => registerFallbackValue(const ServicesListRequested(plateNo: 'X')),
  );

  Future<void> pumpView(
    WidgetTester tester, {
    required ServicesState state,
    String query = '',
    DateTimeRange? dateRange,
    String plateNo = 'B 1234 XY',
  }) async {
    bloc = MockServicesBloc();
    whenListen(bloc, const Stream<ServicesState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<ServicesBloc>.value(
            value: bloc,
            child: ServicesHistoryView(
              plateNo: plateNo,
              query: query,
              dateRange: dateRange,
            ),
          ),
        ),
      ),
    );
  }

  DateTimeRange range(DateTime start, DateTime end) =>
      DateTimeRange(start: start, end: end);

  final cards = find.byType(ServiceCard);

  group('opening a visit', () {
    /// The detail page is a stand-in that records how it was reached.
    Future<({Object? extra, String? path})> openCard(
      WidgetTester tester, {
      required int index,
      String query = '',
    }) async {
      bloc = MockServicesBloc();
      whenListen(
        bloc,
        const Stream<ServicesState>.empty(),
        initialState: ServicesLoaded([march, june, october]),
      );
      Object? extra;
      String? path;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: BlocProvider<ServicesBloc>.value(
                value: bloc,
                child: ServicesHistoryView(plateNo: 'B 1234 XY', query: query),
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.serviceDetail,
            builder: (_, state) {
              extra = state.extra;
              path = state.uri.path;
              return const Scaffold(body: Text('detail-page'));
            },
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.tap(cards.at(index));
      await tester.pumpAndSettle();

      expect(find.text('detail-page'), findsOneWidget);
      return (extra: extra, path: path);
    }

    testWidgets('hands the visit itself over, with nothing looked up', (
      tester,
    ) async {
      final opened = await openCard(tester, index: 1);

      // The record already holds its details: it is passed whole.
      expect(opened.extra, june);
    });

    testWidgets('puts no transaction number in the path', (tester) async {
      final opened = await openCard(tester, index: 1);

      expect(opened.path, RouteNames.serviceDetail);
      expect(opened.path, isNot(contains('T-JUNE')));
    });

    testWidgets('opens the visit that was tapped, also in a searched list', (
      tester,
    ) async {
      // Only the October visit mechanic matches; it is the first card now.
      final opened = await openCard(tester, index: 0, query: 'siti');

      expect(opened.extra, october);
    });

    testWidgets('sends no request of its own to the bloc', (tester) async {
      await openCard(tester, index: 0);

      verifyNever(() => bloc.add(any()));
    });
  });

  group('retrying asks about the same bike', () {
    testWidgets('after a failure', (tester) async {
      await pumpView(
        tester,
        state: const ServicesError('Gagal memuat'),
        plateNo: 'D 5678 CD',
      );

      await tester.tap(find.text('Muat ulang'));

      verify(
        () => bloc.add(const ServicesListRequested(plateNo: 'D 5678 CD')),
      ).called(1);
    });

    testWidgets('from an empty history', (tester) async {
      await pumpView(
        tester,
        state: const ServicesLoaded([]),
        plateNo: 'D 5678 CD',
      );

      await tester.tap(find.text('Muat ulang'));

      verify(
        () => bloc.add(const ServicesListRequested(plateNo: 'D 5678 CD')),
      ).called(1);
    });
  });

  group('pulling down to refresh', () {
    late StreamController<ServicesState> answers;

    /// Opens the view with a bloc whose answers the test pushes into [answers].
    Future<void> pumpPullable(
      WidgetTester tester, {
      required ServicesState state,
      String query = '',
      DateTimeRange? dateRange,
    }) async {
      answers = StreamController<ServicesState>();
      addTearDown(() => unawaited(answers.close()));
      bloc = MockServicesBloc();
      whenListen(bloc, answers.stream, initialState: state);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<ServicesBloc>.value(
              value: bloc,
              child: ServicesHistoryView(
                plateNo: 'D 5678 CD',
                query: query,
                dateRange: dateRange,
              ),
            ),
          ),
        ),
      );
    }

    Future<void> pull(WidgetTester tester) async {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> push(WidgetTester tester, ServicesState state) async {
      answers.add(state);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    final indicator = find.byType(RefreshProgressIndicator);

    testWidgets('asks the bloc for the same bike again, without blanking it', (
      tester,
    ) async {
      await pumpPullable(tester, state: ServicesLoaded([march, june]));

      await pull(tester);

      verify(
        () => bloc.add(const ServicesRefreshRequested(plateNo: 'D 5678 CD')),
      ).called(1);
      // A refresh, not a plain request: that one would show the spinner first.
      verifyNever(() => bloc.add(any(that: isA<ServicesListRequested>())));
    });

    testWidgets('works when the few visits do not fill the screen', (
      tester,
    ) async {
      await pumpPullable(tester, state: ServicesLoaded([march]));

      await pull(tester);

      verify(
        () => bloc.add(const ServicesRefreshRequested(plateNo: 'D 5678 CD')),
      ).called(1);
    });

    testWidgets('works when the bike has no history yet', (tester) async {
      await pumpPullable(tester, state: const ServicesLoaded([]));

      await pull(tester);

      verify(
        () => bloc.add(const ServicesRefreshRequested(plateNo: 'D 5678 CD')),
      ).called(1);
    });

    testWidgets('works when the search leaves nothing', (tester) async {
      await pumpPullable(
        tester,
        state: ServicesLoaded([march, june]),
        query: 'tidak ada yang begini',
      );

      await pull(tester);

      verify(
        () => bloc.add(const ServicesRefreshRequested(plateNo: 'D 5678 CD')),
      ).called(1);
    });

    testWidgets('keeps the indicator turning until the answer is in', (
      tester,
    ) async {
      await pumpPullable(tester, state: ServicesLoaded([march, june]));

      await pull(tester);
      expect(indicator, findsOneWidget);

      // The old list is still shown, marked as refreshing: nothing is waiting
      // for the answer yet.
      await push(tester, ServicesLoaded([march, june], refreshing: true));
      expect(indicator, findsOneWidget);
      expect(cards, findsNWidgets(2));
      expect(find.text('Loading...'), findsNothing);

      await push(tester, ServicesLoaded([march, june, october]));
      await tester.pump(const Duration(seconds: 1));

      expect(indicator, findsNothing);
      expect(cards, findsNWidgets(3));
    });

    testWidgets('stops turning when the answer is the same records', (
      tester,
    ) async {
      // The case that would hang forever if the refreshed state equalled the
      // one before it: nothing new, yet the indicator must still end.
      await pumpPullable(tester, state: ServicesLoaded([march, june]));

      await pull(tester);
      await push(tester, ServicesLoaded([march, june], refreshing: true));
      await push(tester, ServicesLoaded([march, june]));
      await tester.pump(const Duration(seconds: 1));

      expect(indicator, findsNothing);
      expect(cards, findsNWidgets(2));
    });

    testWidgets('stops turning when the refresh fails', (tester) async {
      await pumpPullable(tester, state: ServicesLoaded([march, june]));

      await pull(tester);
      await push(tester, ServicesLoaded([march, june], refreshing: true));
      await push(tester, const ServicesError('Gagal memuat'));
      await tester.pump(const Duration(seconds: 1));

      expect(indicator, findsNothing);
      expect(find.text('Gagal memuat'), findsOneWidget);
    });

    testWidgets('keeps showing the list while it refreshes', (tester) async {
      await pumpPullable(
        tester,
        state: ServicesLoaded([march, june], refreshing: true),
      );

      expect(cards, findsNWidgets(2));
      expect(find.text('Loading...'), findsNothing);
    });

    testWidgets('is not offered while loading or after a failure', (
      tester,
    ) async {
      await pumpPullable(tester, state: const ServicesLoading());
      expect(find.byType(RefreshIndicator), findsNothing);

      await pumpPullable(tester, state: const ServicesError('Gagal memuat'));
      // The failure has its own "Muat ulang" button instead.
      expect(find.byType(RefreshIndicator), findsNothing);
      expect(find.text('Muat ulang'), findsOneWidget);
    });
  });

  group('what it shows', () {
    testWidgets('a spinner while the history is loading', (tester) async {
      await pumpView(tester, state: const ServicesLoading());

      expect(find.text('Loading...'), findsOneWidget);
      expect(cards, findsNothing);
    });

    testWidgets('the failure, with its message', (tester) async {
      await pumpView(tester, state: const ServicesError('Gagal memuat'));

      expect(find.text('Gagal memuat'), findsOneWidget);
    });

    testWidgets('says so when the bike has no history', (tester) async {
      await pumpView(tester, state: const ServicesLoaded([]));

      expect(find.text('Tidak ada riwayat service tersedia'), findsOneWidget);
    });

    testWidgets('every visit when nothing cuts the list', (tester) async {
      await pumpView(tester, state: ServicesLoaded([march, june, october]));

      expect(cards, findsNWidgets(3));
    });
  });

  group('the date range, cut on the device', () {
    testWidgets('no range shows past visits of any date', (tester) async {
      // The bug this guards: Riwayat was handed the upcoming-bookings range
      // (tomorrow, a month ahead), which no past visit falls inside, so the
      // list emptied even though the backend had sent every record.
      await pumpView(
        tester,
        state: ServicesLoaded([march, june, october]),
        dateRange: null,
      );

      expect(cards, findsNWidgets(3));
    });

    testWidgets('a range ahead of every visit leaves none', (tester) async {
      await pumpView(
        tester,
        state: ServicesLoaded([march, june, october]),
        dateRange: range(DateTime(2026, 12, 1), DateTime(2027, 1, 1)),
      );

      expect(cards, findsNothing);
      expect(
        find.text('Tidak ada riwayat yang cocok dengan pencarian atau tanggal'),
        findsOneWidget,
      );
    });

    testWidgets('keeps the visits inside it and drops the rest', (
      tester,
    ) async {
      await pumpView(
        tester,
        state: ServicesLoaded([march, june, october]),
        dateRange: range(DateTime(2026, 5, 1), DateTime(2026, 8, 31)),
      );

      expect(cards, findsOneWidget);
      expect(find.text('KEDUNG TARUKAN'), findsOneWidget);
    });

    testWidgets('both ends of the range are included', (tester) async {
      await pumpView(
        tester,
        state: ServicesLoaded([march, june, october]),
        dateRange: range(DateTime(2026, 3, 10), DateTime(2026, 10, 5)),
      );

      expect(cards, findsNWidgets(3));
    });

    testWidgets('a date it cannot read is not filtered out', (tester) async {
      await pumpView(
        tester,
        state: ServicesLoaded([
          service(transNo: 'T-ODD', transDate: 'kemarin'),
        ]),
        dateRange: range(DateTime(2026, 12, 1), DateTime(2027, 1, 1)),
      );

      expect(cards, findsOneWidget);
    });
  });

  group('the search', () {
    testWidgets('matches the branch, whatever the letter case', (tester) async {
      await pumpView(
        tester,
        state: ServicesLoaded([march, june, october]),
        query: 'kedung',
      );

      expect(cards, findsOneWidget);
    });

    testWidgets('matches the transaction number', (tester) async {
      await pumpView(
        tester,
        state: ServicesLoaded([march, june, october]),
        query: 't-march',
      );

      expect(cards, findsOneWidget);
    });

    testWidgets('matches the mechanic', (tester) async {
      await pumpView(
        tester,
        state: ServicesLoaded([march, june, october]),
        query: 'siti',
      );

      expect(cards, findsOneWidget);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await pumpView(
        tester,
        state: ServicesLoaded([march, june, october]),
        query: 'tidak ada yang begini',
      );

      expect(cards, findsNothing);
      expect(
        find.text('Tidak ada riwayat yang cocok dengan pencarian atau tanggal'),
        findsOneWidget,
      );
    });

    testWidgets('and the range cut together', (tester) async {
      await pumpView(
        tester,
        state: ServicesLoaded([march, june, october]),
        // Two visits at KUTISARI; the range keeps only the October one.
        query: 'kutisari',
        dateRange: range(DateTime(2026, 9, 1), DateTime(2026, 12, 31)),
      );

      expect(cards, findsOneWidget);
    });
  });
}

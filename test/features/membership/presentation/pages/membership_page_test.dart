import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/membership/presentation/pages/membership_page.dart';

class MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

const tStats = DashboardStatsEntity(
  status: 'AKTIF',
  memberId: 'M-001',
  memberName: 'Test Member',
  emailAddress: '-',
  phoneNo: '81234567890',
  active: true,
  qty: 4,
  point: 80,
  detail: [
    PointDetailEntity(
      transDate: '2026-01-02',
      pointId: 'A01',
      pointName: 'Service points',
      pointQty: 10,
    ),
  ],
  detail2: [
    VoucherDetailEntity(
      redeemDate: '2026-01-03',
      expirationDate: '2026-12-31',
      voucherNo: 'V-1',
      statusVoucher: 1,
      voucherId: 'B01',
      voucherName: 'Free oil change',
      statusVoucherMemo: 'AKTIF',
      voucherAmount: 50000,
    ),
  ],
);

/// Nothing in either section — far less than fills the screen.
const tEmptyStats = DashboardStatsEntity(
  status: 'AKTIF',
  memberId: 'M-001',
  memberName: 'Test Member',
  emailAddress: '-',
  phoneNo: '81234567890',
  active: true,
  qty: 0,
  point: 0,
  detail: [],
  detail2: [],
);

/// Many entries in both sections — far more than fit on screen.
final tLongStats = DashboardStatsEntity(
  status: 'AKTIF',
  memberId: 'M-001',
  memberName: 'Test Member',
  emailAddress: '-',
  phoneNo: '81234567890',
  active: true,
  qty: 4,
  point: 80,
  detail: [
    for (var i = 0; i < 30; i++)
      PointDetailEntity(
        transDate: '2026-01-02',
        pointId: 'A$i',
        pointName: 'Service points $i',
        pointQty: 10,
      ),
  ],
  detail2: [
    for (var i = 0; i < 30; i++)
      VoucherDetailEntity(
        redeemDate: '2026-01-03',
        expirationDate: '2026-12-31',
        voucherNo: 'V-$i',
        statusVoucher: 1,
        voucherId: 'B$i',
        voucherName: 'Voucher $i',
        statusVoucherMemo: 'AKTIF',
        voucherAmount: 50000,
      ),
  ],
);

Future<MockHomeBloc> pumpMembership(
  WidgetTester tester, {
  DashboardStatsEntity stats = tStats,
}) async {
  final bloc = MockHomeBloc();
  whenListen(
    bloc,
    const Stream<HomeState>.empty(),
    initialState: HomeLoaded(stats),
  );
  sl.registerFactory<HomeBloc>(() => bloc);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: refreshCubit,
        child: const MembershipPage(),
      ),
    ),
  );
  return bloc;
}

/// The app-wide "reload this" signal the page listens to; fresh per test.
late DataRefreshCubit refreshCubit;

void main() {
  setUp(() => refreshCubit = DataRefreshCubit());
  tearDown(() => sl.reset());

  /// The rounded Container, found from a widget inside it.
  Finder roundedBoxAround(Finder inside) => find.ancestor(
    of: inside,
    matching: find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration && decoration.borderRadius != null;
    }),
  );

  /// Bottom edge of the page body — what the navigation bar sits right under.
  double pageBottom(WidgetTester tester) =>
      tester.getBottomLeft(find.byType(Scaffold)).dy;

  testWidgets('point history and vouchers sit inside one rounded box', (
    tester,
  ) async {
    await pumpMembership(tester);

    final aroundHistory = roundedBoxAround(find.text('Point History'));
    final aroundVouchers = roundedBoxAround(find.text('Vouchers'));

    expect(aroundHistory, findsOneWidget);
    expect(aroundVouchers, findsOneWidget);
    // The same box, not two separate ones.
    expect(tester.widget(aroundHistory), same(tester.widget(aroundVouchers)));
  });

  testWidgets('the entries of both sections are inside the box', (
    tester,
  ) async {
    await pumpMembership(tester);

    final box = roundedBoxAround(find.text('Point History'));

    for (final text in ['Service points', 'Free oil change']) {
      expect(
        find.descendant(of: box, matching: find.text(text)),
        findsOneWidget,
        reason: '"$text" should be inside the box',
      );
    }
  });

  testWidgets('the loyalty points card stays outside the box', (tester) async {
    await pumpMembership(tester);

    final box = roundedBoxAround(find.text('Point History'));

    expect(
      find.descendant(of: box, matching: find.text('Point Anda')),
      findsNothing,
    );
    expect(find.text('Point Anda'), findsOneWidget);
  });

  group('the point card follows the sketch', () {
    final label = find.text('Point Anda');
    final qrIcon = find.byIcon(Icons.qr_code_2);
    final number = find.text('80'); // tStats.point
    final badge = find.byKey(const Key('member-badge'));

    testWidgets('has the label, the QR icon, the balance and the badge', (
      tester,
    ) async {
      await pumpMembership(tester);

      expect(label, findsOneWidget);
      expect(qrIcon, findsOneWidget);
      expect(number, findsOneWidget);
      expect(badge, findsOneWidget);
      expect(
        find.descendant(
          of: badge,
          matching: find.byIcon(Icons.card_membership),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the QR icon sits right after the label, on the same line', (
      tester,
    ) async {
      await pumpMembership(tester);

      expect(
        tester.getTopLeft(qrIcon).dx,
        greaterThan(tester.getTopRight(label).dx - 1),
      );
      expect(
        (tester.getCenter(qrIcon).dy - tester.getCenter(label).dy).abs(),
        lessThan(6),
      );
    });

    testWidgets('the balance is under the label, left-aligned with it', (
      tester,
    ) async {
      await pumpMembership(tester);

      expect(
        tester.getTopLeft(number).dy,
        greaterThan(tester.getBottomLeft(label).dy - 1),
      );
      expect(tester.getTopLeft(number).dx, tester.getTopLeft(label).dx);
    });

    testWidgets('the badge is on the right, a small square with rounded '
        'corners', (tester) async {
      await pumpMembership(tester);

      expect(
        tester.getTopLeft(badge).dx,
        greaterThan(tester.getTopRight(number).dx),
      );
      final size = tester.getSize(badge);
      expect(size.width, size.height);
      expect(size.width, 48);

      final decoration =
          (tester.widget<Container>(badge)).decoration! as BoxDecoration;
      expect(decoration.borderRadius, isNotNull);
    });

    testWidgets('the badge is a soft tint with no outline, so it stays an '
        'accent', (tester) async {
      await pumpMembership(tester);

      final decoration =
          (tester.widget<Container>(badge)).decoration! as BoxDecoration;
      expect(decoration.border, isNull);
      expect(decoration.color, isNotNull);
      expect(decoration.color!.a, lessThan(0.2));
    });

    testWidgets('the badge lines up with the label at the top', (tester) async {
      await pumpMembership(tester);

      expect(
        (tester.getTopLeft(badge).dy - tester.getTopLeft(label).dy).abs(),
        lessThan(8),
      );
    });

    testWidgets('the card is compact, not a tall block', (tester) async {
      await pumpMembership(tester);

      final card = find.ancestor(of: label, matching: find.byType(Card));
      final height = tester.getSize(card).height;

      // Was 180+. The content (label, balance) needs about 84 plus padding.
      expect(height, greaterThanOrEqualTo(110));
      expect(height, lessThanOrEqualTo(140));
    });

    testWidgets('the card is flat, matching the Profile tiles', (tester) async {
      await pumpMembership(tester);

      final card = tester.widget<Card>(
        find.ancestor(of: label, matching: find.byType(Card)),
      );
      expect(card.elevation, 0);
    });

    testWidgets('"pts" follows the balance on the same text baseline', (
      tester,
    ) async {
      await pumpMembership(tester);

      final pts = find.text('pts');
      expect(pts, findsOneWidget);
      expect(
        tester.getTopLeft(pts).dx,
        greaterThan(tester.getTopRight(number).dx - 1),
      );

      // getDistanceToBaseline can only be asked during layout; the dry
      // version answers the same question from outside it.
      double baseline(Finder text) {
        final box = tester.renderObject<RenderBox>(text);
        return tester.getTopLeft(text).dy +
            box.getDryBaseline(box.constraints, TextBaseline.alphabetic)!;
      }

      expect(baseline(pts), closeTo(baseline(number), 1));
    });

    testWidgets('the balance is the biggest text on the card', (tester) async {
      await pumpMembership(tester);

      double fontSize(Finder text) =>
          tester.widget<Text>(text).style!.fontSize!;
      expect(fontSize(number), 40);
      expect(fontSize(number), greaterThan(fontSize(label)));
      expect(fontSize(label), 12);
    });

    testWidgets('the old Loyalty Points wording and status line are gone', (
      tester,
    ) async {
      await pumpMembership(tester);

      expect(find.text('Loyalty Points'), findsNothing);
      // tStats.status; the voucher's own memo is part of a longer sentence.
      expect(find.text('AKTIF'), findsNothing);
    });

    testWidgets('a very large balance shrinks to fit instead of overflowing', (
      tester,
    ) async {
      await pumpMembership(
        tester,
        stats: const DashboardStatsEntity(
          status: 'AKTIF',
          memberId: 'M-001',
          memberName: 'Test Member',
          emailAddress: '-',
          phoneNo: '81234567890',
          active: true,
          qty: 4,
          point: 123456789012,
          detail: [],
          detail2: [],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('123456789012'), findsOneWidget);
    });

    testWidgets('the card grows at a large font size instead of clipping', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpMembership(tester);

      expect(tester.takeException(), isNull);
    });
  });

  group('reloads when the stats go out of date elsewhere', () {
    testWidgets('invalidate(stats) sends HomeStatsRequested again', (
      tester,
    ) async {
      final bloc = await pumpMembership(tester);

      refreshCubit.invalidate(DataKind.stats);
      await tester.pump();

      // Once when the page opened, once for the signal.
      verify(() => bloc.add(const HomeStatsRequested())).called(2);
    });

    testWidgets('invalidate(bookings) is none of its business', (tester) async {
      final bloc = await pumpMembership(tester);

      refreshCubit.invalidate(DataKind.bookings);
      await tester.pump();

      verify(() => bloc.add(const HomeStatsRequested())).called(1);
    });
  });

  group('pull to refresh', () {
    /// Pulls down from [from] and lets the indicator run.
    Future<void> pullDown(WidgetTester tester, Finder from) async {
      await tester.drag(from, const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    testWidgets('there is a single RefreshIndicator, around the whole page', (
      tester,
    ) async {
      await pumpMembership(tester);

      expect(find.byType(RefreshIndicator), findsOneWidget);
      // It is above both the balance card and the box, not inside the box.
      for (final text in ['Point Anda', 'Point History']) {
        expect(
          find.descendant(
            of: find.byType(RefreshIndicator),
            matching: find.text(text),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('pulling on the Point Anda card refreshes', (tester) async {
      final bloc = await pumpMembership(tester);

      await pullDown(tester, find.text('Point Anda'));

      // Once when the page opened, once for the pull.
      verify(() => bloc.add(const HomeStatsRequested())).called(2);
    });

    testWidgets('pulling inside the box refreshes when it has few entries', (
      tester,
    ) async {
      final bloc = await pumpMembership(tester);

      await pullDown(tester, find.text('Point History'));

      verify(() => bloc.add(const HomeStatsRequested())).called(2);
    });

    testWidgets('pulling inside the box refreshes when it has many entries', (
      tester,
    ) async {
      final bloc = await pumpMembership(tester, stats: tLongStats);

      await pullDown(tester, find.text('Point History'));

      verify(() => bloc.add(const HomeStatsRequested())).called(2);
    });

    testWidgets('pulling down mid-list scrolls back up instead of refreshing', (
      tester,
    ) async {
      final bloc = await pumpMembership(tester, stats: tLongStats);

      // Scroll the box's list down, away from its top...
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      // ...then pull back a little: that is scrolling, not a refresh request.
      await tester.drag(find.byType(ListView), const Offset(0, 100));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const HomeStatsRequested())).called(1);
    });
  });

  group('the box fills the rest of the page', () {
    testWidgets('with little content it still reaches the bottom', (
      tester,
    ) async {
      await pumpMembership(tester, stats: tEmptyStats);

      final box = roundedBoxAround(find.text('Point History'));

      // 20px of page padding below it, and nothing else — so it is as low as
      // the body goes, i.e. just above the navigation bar.
      expect(
        tester.getBottomLeft(box).dy,
        closeTo(pageBottom(tester) - 20, 0.5),
      );
    });

    testWidgets('with a few entries it reaches the bottom too', (tester) async {
      await pumpMembership(tester);

      final box = roundedBoxAround(find.text('Point History'));

      expect(
        tester.getBottomLeft(box).dy,
        closeTo(pageBottom(tester) - 20, 0.5),
      );
    });

    testWidgets('with many entries it stays on the page and scrolls inside', (
      tester,
    ) async {
      await pumpMembership(tester, stats: tLongStats);

      final box = roundedBoxAround(find.text('Point History'));

      // It does not grow past the bottom of the page...
      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomLeft(box).dy,
        closeTo(pageBottom(tester) - 20, 0.5),
      );

      // ...because the list scrolling is the box's own, not the whole page's.
      expect(
        find.descendant(of: box, matching: find.byType(ListView)),
        findsOneWidget,
      );

      // The last voucher is reachable by scrolling it. The box's list is the
      // page's only ListView (the page itself is a CustomScrollView), so it is
      // found directly: `box` is anchored on a heading that scrolls out of the
      // tree, which would stop it matching mid-drag.
      expect(find.text('Voucher 29'), findsNothing);
      await tester.dragUntilVisible(
        find.text('Voucher 29'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      expect(find.text('Voucher 29'), findsOneWidget);
    });
  });
}

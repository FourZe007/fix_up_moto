import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:fix_up_moto/core/constants/asset_constants.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/services/screen_brightness_booster.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/membership/domain/entities/reward_entity.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/redeem_bloc.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/redeem_event.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/redeem_state.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/rewards_bloc.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/rewards_event.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/rewards_state.dart';
import 'package:fix_up_moto/features/membership/presentation/pages/membership_page.dart';

class MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

class MockRewardsBloc extends MockBloc<RewardsEvent, RewardsState>
    implements RewardsBloc {}

class MockRedeemBloc extends MockBloc<RedeemEvent, RedeemState>
    implements RedeemBloc {}

/// The vouchers the API offers. With [tStats]' 80 points, the first is
/// available and the other two cost more than the balance.
const tRewards = [
  RewardEntity(pointId: 'C00', pointName: 'GRATIS CUCI MOTOR', pointQty: 50),
  RewardEntity(
    pointId: 'C01',
    pointName: 'DISKON JASA SERVICE Rp. 20.000,00',
    pointQty: 100,
  ),
  RewardEntity(pointId: 'C02', pointName: 'GRATIS GANTI OLI', pointQty: 250),
];

/// Far more vouchers than fit on screen, half affordable with [tStats]' 80
/// points and half not.
final tLongRewards = [
  for (var i = 0; i < 30; i++)
    RewardEntity(
      pointId: 'R$i',
      pointName: 'Reward $i',
      pointQty: i < 15 ? 10 : 500,
    ),
];

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

/// Counts brightness calls instead of touching the real screen.
class _FakeBrightness implements ScreenBrightnessBooster {
  int boosts = 0;
  int restores = 0;

  @override
  Future<void> boost() async => boosts++;

  @override
  Future<void> restore() async => restores++;
}

/// A canvas that only remembers the horizontal extent of every line drawn on it,
/// to tell a dashed line from a solid one without taking a screenshot.
class _SegmentRecorder implements Canvas {
  /// (start x, end x) of each `drawLine`.
  final List<(double, double)> segments = [];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      segments.add((p1.dx, p2.dx));

  // Nothing else is ever drawn by the painter under test.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// An asset bundle where only the logo fails to load (everything else, such as
/// the asset manifest Flutter needs to resolve images, comes from the real
/// one), to test the logo's fallback.
class _BrokenBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == AssetConstants.logo) {
      return Future<ByteData>.error(FlutterError('Unable to load asset: $key'));
    }
    return rootBundle.load(key);
  }
}

Future<MockHomeBloc> pumpMembership(
  WidgetTester tester, {
  DashboardStatsEntity stats = tStats,
  AssetBundle? bundle,
  ThemeData? theme,
}) async {
  final bloc = MockHomeBloc();
  whenListen(
    bloc,
    const Stream<HomeState>.empty(),
    initialState: HomeLoaded(stats),
  );
  sl.registerFactory<HomeBloc>(() => bloc);
  sl.registerFactory<RewardsBloc>(() => rewardsBloc);
  sl.registerFactory<RedeemBloc>(() => redeemBloc);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      // Via `builder`, not around `home`: the QR popup is a route pushed on the
      // Navigator, which sits outside `home`'s subtree, so a bundle wrapped
      // around `home` would never reach it.
      builder: (context, child) =>
          DefaultAssetBundle(bundle: bundle ?? rootBundle, child: child!),
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

/// The rewards bloc the page gets from `sl`; fresh per test, already loaded with
/// [tRewards] (the Voucher tab is the one the box opens on, and a spinner would
/// keep `pumpAndSettle` from ever settling). A test that needs another state
/// calls [givenRewards] before pumping.
late MockRewardsBloc rewardsBloc;

void givenRewards(RewardsState state) => whenListen(
  rewardsBloc,
  const Stream<RewardsState>.empty(),
  initialState: state,
);

/// A screen tall enough to build every voucher card. The cards are tall (details
/// above, Klaim below) and the list only builds what fits, so on the default
/// 600px test screen a test that looks for the third card would not find it.
void useTallScreen(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 2000);
  addTearDown(tester.view.reset);
}

/// The redeem bloc the page gets from `sl`; fresh per test, idle. A test that
/// needs another state, or to push states while the page is up, calls
/// [givenRedeem] before pumping.
late MockRedeemBloc redeemBloc;

void givenRedeem(RedeemState state, {Stream<RedeemState>? thenEmits}) =>
    whenListen(
      redeemBloc,
      thenEmits ?? const Stream<RedeemState>.empty(),
      initialState: state,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    refreshCubit = DataRefreshCubit();
    rewardsBloc = MockRewardsBloc();
    givenRewards(const RewardsLoaded(tRewards));
    redeemBloc = MockRedeemBloc();
    givenRedeem(const RedeemInitial());
  });
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

    final aroundHistory = roundedBoxAround(find.text('Riwayat'));
    final aroundVouchers = roundedBoxAround(find.text('Voucher'));

    expect(aroundHistory, findsOneWidget);
    expect(aroundVouchers, findsOneWidget);
    // The same box, not two separate ones.
    expect(tester.widget(aroundHistory), same(tester.widget(aroundVouchers)));
  });

  group('the point history / vouchers tabs', () {
    final historyTab = find.byKey(const Key('tab-history'));
    final vouchersTab = find.byKey(const Key('tab-vouchers'));
    // The selected tab's fill: the same peach the point card is tinted with.
    const selectedTabColour = Color(0xFFFFCDAC);

    Future<void> open(WidgetTester tester, Finder tab) async {
      await tester.tap(tab);
      await tester.pumpAndSettle(); // let the cross-fade finish
    }

    /// Filled peach when selected, see-through (outlined) when not.
    bool isSelected(WidgetTester tester, Finder tab) {
      final material = tester.widget<Material>(
        find.descendant(of: tab, matching: find.byType(Material)).first,
      );
      return material.color == selectedTabColour;
    }

    testWidgets('there are exactly two tabs, and the box opens on Voucher', (
      tester,
    ) async {
      await pumpMembership(tester);

      expect(historyTab, findsOneWidget);
      expect(vouchersTab, findsOneWidget);
      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.text('Voucher'), findsOneWidget);
      // No third tab: only the two pills have a tab- key.
      expect(find.byKey(const Key('tab-rewards')), findsNothing);
      expect(find.text('Tukar Point'), findsNothing);
      expect(isSelected(tester, vouchersTab), isTrue);
      expect(isSelected(tester, historyTab), isFalse);
    });

    testWidgets('only the open tab shows its entries', (tester) async {
      await pumpMembership(tester);

      expect(find.text('Gratis Cuci Motor'), findsOneWidget);
      expect(find.text('Service points'), findsNothing);
    });

    testWidgets('tapping Riwayat swaps the list, and Voucher swaps it back', (
      tester,
    ) async {
      await pumpMembership(tester);

      await open(tester, historyTab);
      expect(find.text('Service points'), findsOneWidget);
      expect(find.text('Gratis Cuci Motor'), findsNothing);
      expect(isSelected(tester, historyTab), isTrue);
      expect(isSelected(tester, vouchersTab), isFalse);

      await open(tester, vouchersTab);
      expect(find.text('Gratis Cuci Motor'), findsOneWidget);
      expect(find.text('Service points'), findsNothing);
      expect(isSelected(tester, vouchersTab), isTrue);
    });

    testWidgets('the entries are inside the box, as rounded cards', (
      tester,
    ) async {
      await pumpMembership(tester);
      final box = roundedBoxAround(historyTab);

      for (final tab in [historyTab, vouchersTab]) {
        await open(tester, tab);
        final cards = find.descendant(of: box, matching: find.byType(Card));
        expect(cards, findsWidgets);

        final card = tester.widget<Card>(cards.first);
        expect((card.shape! as RoundedRectangleBorder).borderRadius, isNotNull);
      }
    });

    testWidgets('each tab has its own empty message', (tester) async {
      givenRewards(const RewardsLoaded([]));
      await pumpMembership(tester, stats: tEmptyStats);

      // The box opens on Voucher.
      expect(find.text('Tidak ada voucher tersedia'), findsOneWidget);
      expect(find.text('Tidak ada riwayat point'), findsNothing);

      await open(tester, historyTab);
      expect(find.text('Tidak ada riwayat point'), findsOneWidget);
      expect(find.text('Tidak ada voucher tersedia'), findsNothing);
    });

    testWidgets('the tabs share the width equally, side by side', (
      tester,
    ) async {
      await pumpMembership(tester);

      final history = tester.getRect(historyTab);
      final vouchers = tester.getRect(vouchersTab);
      expect(history.width, closeTo(vouchers.width, 0.5));
      expect(history.top, vouchers.top);
      // Voucher first, Riwayat to its right.
      expect(history.left, greaterThan(vouchers.right));
    });

    testWidgets('on a narrow 360dp phone every label still fits its tab', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      await pumpMembership(tester);

      expect(tester.takeException(), isNull);
      for (final (tab, label) in [
        (historyTab, 'Riwayat'),
        (vouchersTab, 'Voucher'),
      ]) {
        // getBottomRight/getTopLeft apply the FittedBox's scale, so these are
        // where the label is actually painted, not its unscaled layout size.
        final text = find.text(label);
        expect(
          tester.getTopLeft(text).dx,
          greaterThanOrEqualTo(tester.getTopLeft(tab).dx),
          reason: '$label starts inside its tab',
        );
        expect(
          tester.getBottomRight(text).dx,
          lessThanOrEqualTo(tester.getBottomRight(tab).dx),
          reason: '$label ends inside its tab',
        );
      }
    });

    testWidgets('the tabs stay put while the history list scrolls', (
      tester,
    ) async {
      await pumpMembership(tester, stats: tLongStats);
      await open(tester, historyTab);
      final before = tester.getTopLeft(historyTab);

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Service points 0'), findsNothing); // scrolled away
      expect(tester.getTopLeft(historyTab), before);
    });

    testWidgets('the tabs stay put while the voucher list scrolls', (
      tester,
    ) async {
      givenRewards(RewardsLoaded(tLongRewards));
      await pumpMembership(tester);
      final before = tester.getTopLeft(vouchersTab);

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Voucher Tersedia'), findsNothing); // scrolled away
      expect(tester.getTopLeft(vouchersTab), before);
    });

    testWidgets('the tab and its list sit above the cards, inside the box', (
      tester,
    ) async {
      await pumpMembership(tester);

      // Tabs first, then the cards under them.
      expect(
        tester.getBottomLeft(historyTab).dy,
        lessThanOrEqualTo(
          tester
              .getTopLeft(
                // The first card *in the box* — the balance card is a Card too,
                // but it sits above the tabs.
                find
                    .descendant(
                      of: roundedBoxAround(historyTab),
                      matching: find.byType(Card),
                    )
                    .first,
              )
              .dy,
        ),
      );
    });
  });

  testWidgets('the loyalty points card stays outside the box', (tester) async {
    await pumpMembership(tester);

    final box = roundedBoxAround(find.text('Riwayat'));

    expect(
      find.descendant(of: box, matching: find.text('Point Saya')),
      findsNothing,
    );
    expect(find.text('Point Saya'), findsOneWidget);
  });

  group('the point card follows the sketch', () {
    final label = find.text('Point Saya');
    final number = find.text('80'); // tStats.point
    final qrButton = find.byKey(const Key('member-qr-button'));

    testWidgets('has the label, the balance and the QR button', (tester) async {
      await pumpMembership(tester);

      expect(label, findsOneWidget);
      expect(number, findsOneWidget);
      expect(qrButton, findsOneWidget);
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

    testWidgets('the QR button is on the right of the balance', (tester) async {
      await pumpMembership(tester);

      expect(
        tester.getTopLeft(qrButton).dx,
        greaterThan(tester.getTopRight(number).dx),
      );
    });

    testWidgets('the QR button shows a QR icon and has a tooltip', (
      tester,
    ) async {
      await pumpMembership(tester);

      expect(
        find.descendant(
          of: qrButton,
          matching: find.byIcon(Icons.qr_code_rounded),
        ),
        findsOneWidget,
      );
      expect(tester.widget<IconButton>(qrButton).tooltip, isNotEmpty);
    });

    testWidgets('the QR button is disabled without a member ID, so an empty '
        'string is never encoded', (tester) async {
      await pumpMembership(
        tester,
        stats: const DashboardStatsEntity(
          status: 'AKTIF',
          memberId: '  ',
          memberName: 'Test Member',
          emailAddress: '-',
          phoneNo: '81234567890',
          active: true,
          qty: 0,
          point: 0,
          detail: [],
          detail2: [],
        ),
      );

      expect(tester.widget<IconButton>(qrButton).onPressed, isNull);
    });

    testWidgets('the QR button sits within the card, beside the text', (
      tester,
    ) async {
      await pumpMembership(tester);

      final card = find.ancestor(of: label, matching: find.byType(Card));
      final cardBox = tester.getRect(card);
      expect(cardBox.contains(tester.getRect(qrButton).topLeft), isTrue);
      expect(cardBox.contains(tester.getRect(qrButton).bottomRight), isTrue);
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
      expect(fontSize(number), 52);
      expect(fontSize(number), greaterThan(fontSize(label)));
      expect(fontSize(label), 12);
    });

    testWidgets('the number is tucked up under the label without negative '
        'spacing (which makes the whole page crash)', (tester) async {
      await pumpMembership(tester);

      // Building at all proves the Column's spacing is valid; the gap between
      // the label and the digits should also be small.
      expect(tester.takeException(), isNull);
      final gap = tester.getTopLeft(number).dy - tester.getBottomLeft(label).dy;
      expect(gap, lessThan(10));
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

  group('the member QR popup', () {
    final qrButton = find.byKey(const Key('member-qr-button'));
    final qrImage = find.byType(QrImageView);
    final logo = find.byKey(const Key('member-qr-logo'));
    late _FakeBrightness brightness;

    setUp(() {
      brightness = _FakeBrightness();
      sl.registerSingleton<ScreenBrightnessBooster>(brightness);
    });

    Future<void> openPopup(
      WidgetTester tester, {
      DashboardStatsEntity stats = tStats,
      AssetBundle? bundle,
    }) async {
      await pumpMembership(tester, stats: stats, bundle: bundle);
      await tester.tap(qrButton);
      await tester.pumpAndSettle();
    }

    /// Closes the popup the way a user does: tapping the dimmed area around it.
    Future<void> dismissPopup(WidgetTester tester) async {
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }

    /// The pixels a [QrPainter] draws for [data], styled like the popup's QR.
    Future<List<int>> pixelsOf(WidgetTester tester, QrPainter painter) async {
      final bytes = await tester.runAsync(() => painter.toImageData(200));
      return bytes!.buffer.asUint8List();
    }

    QrPainter painterFor(String data) => QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      // QrImageView draws gapless by default; QrPainter on its own does not.
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );

    QrPainter shownPainter(WidgetTester tester) => tester
        .widgetList<CustomPaint>(
          find.descendant(of: qrImage, matching: find.byType(CustomPaint)),
        )
        .map((paint) => paint.painter)
        .whereType<QrPainter>()
        .single;

    testWidgets('is closed until the button is pressed', (tester) async {
      await pumpMembership(tester);

      expect(qrImage, findsNothing);
      expect(brightness.boosts, 0);
    });

    testWidgets('pressing the button opens the popup with the QR, the name '
        'and the member ID', (tester) async {
      await openPopup(tester);

      expect(qrImage, findsOneWidget);
      expect(find.text('Test Member'), findsOneWidget);
      expect(find.text('M-001'), findsOneWidget);
      expect(
        find.text('Tunjukkan kode ini di bengkel terdekat'),
        findsOneWidget,
      );
    });

    testWidgets('the QR holds the member ID and nothing else', (tester) async {
      await openPopup(tester);

      final shown = await pixelsOf(tester, shownPainter(tester));

      expect(shown, await pixelsOf(tester, painterFor('M-001')));
      // ...and it is not just any QR: another payload draws different pixels.
      expect(shown, isNot(await pixelsOf(tester, painterFor('M-002'))));
    });

    testWidgets('the QR is dark on white, whatever the theme', (tester) async {
      await openPopup(tester);

      final view = tester.widget<QrImageView>(qrImage);
      expect(view.backgroundColor, Colors.white);
      expect(view.eyeStyle.color, Colors.black);
      expect(view.dataModuleStyle.color, Colors.black);
    });

    testWidgets('the screen is brightened while the popup is open', (
      tester,
    ) async {
      await openPopup(tester);

      expect(brightness.boosts, 1);
      expect(brightness.restores, 0);
    });

    testWidgets('the brightness is restored when the popup is closed', (
      tester,
    ) async {
      await openPopup(tester);
      await dismissPopup(tester);

      expect(qrImage, findsNothing);
      expect(brightness.boosts, 1);
      expect(brightness.restores, 1);
    });

    testWidgets('it is a centred popup, not a sheet from the bottom', (
      tester,
    ) async {
      await openPopup(tester);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      final screen = tester.getRect(find.byType(Scaffold).first);
      // Dialog itself spans the whole screen (it centres its content); the
      // visible card is the Material inside it.
      final box = tester.getRect(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect((box.center.dx - screen.center.dx).abs(), lessThan(1));
      expect(box.bottom, lessThan(screen.bottom));
      expect(box.top, greaterThan(screen.top));
    });

    testWidgets('the X button closes it and restores the brightness', (
      tester,
    ) async {
      await openPopup(tester);
      await tester.tap(find.byKey(const Key('member-qr-close')));
      await tester.pumpAndSettle();

      expect(qrImage, findsNothing);
      expect(brightness.restores, 1);
    });

    testWidgets('the brightness is restored when closed by a pop from code', (
      tester,
    ) async {
      await openPopup(tester);
      Navigator.of(tester.element(qrImage)).pop();
      await tester.pumpAndSettle();

      expect(brightness.restores, 1);
    });

    testWidgets('opening it twice brightens and restores twice', (
      tester,
    ) async {
      await openPopup(tester);
      await dismissPopup(tester);
      await tester.tap(qrButton);
      await tester.pumpAndSettle();
      await dismissPopup(tester);

      expect(brightness.boosts, 2);
      expect(brightness.restores, 2);
    });

    group('the logo in its header', () {
      /// The asset behind the logo's Image, unwrapping the ResizeImage that
      /// `cacheWidth` adds.
      String assetShown(WidgetTester tester) {
        var provider = tester.widget<Image>(logo).image;
        if (provider is ResizeImage) provider = provider.imageProvider;
        return (provider as AssetImage).assetName;
      }

      testWidgets('is the FixUp Moto logo from AssetConstants', (tester) async {
        await openPopup(tester);

        expect(assetShown(tester), AssetConstants.logo);
        expect(AssetConstants.logo, endsWith('fixupmoto_logo.jpg'));
      });

      testWidgets('is a real image that is bundled with the app, not the '
          '69-byte placeholder', (tester) async {
        final data = await tester.runAsync(
          () => rootBundle.load(AssetConstants.logo),
        );

        // A missing registration would throw above; a stand-in file would be
        // tiny. The real logo is ~71 KB.
        expect(data!.lengthInBytes, greaterThan(10000));
      });

      testWidgets('is decoded at the size it is shown, not at 1600 x 1600', (
        tester,
      ) async {
        await openPopup(tester);

        final image = tester.widget<Image>(logo);
        expect(image.image, isA<ResizeImage>());
        // 48 logical px x the test device's pixel ratio.
        final dpr = tester.view.devicePixelRatio;
        expect((image.image as ResizeImage).width, (48 * dpr).round());
      });

      testWidgets('fills its square without stretching', (tester) async {
        await openPopup(tester);

        expect(tester.widget<Image>(logo).fit, BoxFit.cover);
      });

      testWidgets('is labelled for screen readers', (tester) async {
        await openPopup(tester);

        expect(tester.widget<Image>(logo).semanticLabel, 'FixUp Moto');
      });

      testWidgets('falls back to the member icon if the asset cannot load', (
        tester,
      ) async {
        await openPopup(tester, bundle: _BrokenBundle());
        // Let the failed load report back (it runs in real time, outside the
        // test's fake clock), then rebuild with the error.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        expect(find.byIcon(Icons.card_membership), findsOneWidget);
        // The QR itself is unaffected.
        expect(qrImage, findsOneWidget);
      });
    });
  });

  group('the point card satin finish', () {
    final label = find.text('Point Saya');

    /// The card's own Container: the nearest one with a gradient.
    Finder card() => find.ancestor(
      of: label,
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).gradient != null,
      ),
    );

    LinearGradient baseOf(WidgetTester tester) =>
        (tester.widget<Container>(card()).decoration! as BoxDecoration)
                .gradient!
            as LinearGradient;

    /// The glossy layer: the DecoratedBox inside the card. (`.first` is the one
    /// the card's own Container builds for the base gradient.)
    LinearGradient sheenOf(WidgetTester tester) {
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: card(), matching: find.byType(DecoratedBox)).at(1),
      );
      return (box.decoration as BoxDecoration).gradient! as LinearGradient;
    }

    double contrast(Color a, Color b) {
      final l1 = a.computeLuminance();
      final l2 = b.computeLuminance();
      final hi = l1 > l2 ? l1 : l2;
      final lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    testWidgets('the base is a soft cream → peach tint of the brand orange', (
      tester,
    ) async {
      await pumpMembership(tester);

      final g = baseOf(tester);
      expect(g.colors, hasLength(3));
      expect(g.stops, hasLength(3));
      // Runs along the card's diagonal. (Which stop is lightest is a styling
      // choice and deliberately not pinned down.)
      expect(g.begin, Alignment.topLeft);
      expect(g.end, Alignment.bottomRight);
      // Every stop stays warm (red ≥ green ≥ blue) — a tint, not another hue —
      // and pale enough to read as a surface, not as a second orange.
      for (final c in g.colors) {
        expect(c.r, greaterThanOrEqualTo(c.g));
        expect(c.g, greaterThanOrEqualTo(c.b));
        expect(c.computeLuminance(), greaterThan(0.6));
      }
    });

    testWidgets('two glossy white bands slant across the card', (tester) async {
      await pumpMembership(tester);

      final g = sheenOf(tester);
      expect(g.colors.length, g.stops!.length);
      // Only the alpha changes (pure white), so the fades never go grey.
      for (final c in g.colors) {
        expect([c.r, c.g, c.b], [1.0, 1.0, 1.0]);
      }
      // Each band fades in from clear and back out to clear...
      final bands = <int>[
        for (var i = 1; i < g.colors.length - 1; i++)
          if (g.colors[i].a > g.colors[i - 1].a &&
              g.colors[i].a > g.colors[i + 1].a)
            i,
      ];
      expect(bands, hasLength(2));
      for (final i in bands) {
        expect(g.colors[i - 1].a, 0);
        expect(g.colors[i + 1].a, 0);
        // ...and is a sheen, not a white-out: visible but translucent.
        expect(g.colors[i].a, inInclusiveRange(0.2, 0.7));
      }
      // Stops climb, so the gradient is valid and the bands don't overlap.
      for (var i = 0; i < g.stops!.length - 1; i++) {
        expect(g.stops![i + 1], greaterThan(g.stops![i]));
      }
    });

    testWidgets('the text is the brand dark red in light and dark', (
      tester,
    ) async {
      await pumpMembership(tester);

      for (final text in [label, find.text('80'), find.text('pts')]) {
        expect(tester.widget<Text>(text).style!.color, AppColors.primaryDark);
      }
    });

    testWidgets('the text is readable on the darkest part of the card', (
      tester,
    ) async {
      await pumpMembership(tester);

      // The gloss bands only lighten the base, so the base's deepest colour is
      // the worst case. 4.5:1 is the bar for small text like the label.
      final deepest = baseOf(tester).colors.last;
      expect(contrast(AppColors.primaryDark, deepest), greaterThan(4.5));
    });

    testWidgets('the card is still clipped to rounded corners by its Card', (
      tester,
    ) async {
      await pumpMembership(tester);

      // The satin is painted by plain boxes, so the surrounding Card (rounded
      // by the app theme) is what keeps it from showing square corners.
      expect(
        find.ancestor(of: card(), matching: find.byType(Card)),
        findsOneWidget,
      );
    });
  });

  group('the Voucher tab (vouchers from the API)', () {
    final historyTab = find.byKey(const Key('tab-history'));
    final vouchersTab = find.byKey(const Key('tab-vouchers'));
    final availableHeader = find.byKey(
      const Key('vouchers-available-header'),
    );
    final unavailableHeader = find.byKey(
      const Key('vouchers-unavailable-header'),
    );

    Future<void> open(WidgetTester tester, Finder tab) async {
      await tester.tap(tab);
      await tester.pumpAndSettle();
    }

    /// The card that holds [title].
    Finder cardWith(String title) => find.ancestor(
      of: find.text(title),
      matching: find.byType(Card),
    );

    group('loading it', () {
      testWidgets('the box opens on Voucher, which asks for the list', (
        tester,
      ) async {
        givenRewards(const RewardsInitial());
        await pumpMembership(tester);

        verify(() => rewardsBloc.add(const RewardsRequested())).called(1);
      });

      testWidgets('an already loaded list is not requested again', (
        tester,
      ) async {
        await pumpMembership(tester); // RewardsLoaded

        verifyNever(() => rewardsBloc.add(const RewardsRequested()));
      });

      testWidgets('a request already in flight is not doubled', (tester) async {
        givenRewards(const RewardsLoading());
        await pumpMembership(tester);

        verifyNever(() => rewardsBloc.add(const RewardsRequested()));
      });

      testWidgets('flipping between the tabs never requests it again', (
        tester,
      ) async {
        await pumpMembership(tester);

        await open(tester, historyTab);
        await open(tester, vouchersTab);
        await open(tester, historyTab);
        await open(tester, vouchersTab);

        verifyNever(() => rewardsBloc.add(const RewardsRequested()));
      });

      testWidgets('shows a spinner inside the box while it loads', (
        tester,
      ) async {
        givenRewards(const RewardsLoading());
        await pumpMembership(tester);

        final box = roundedBoxAround(vouchersTab);
        expect(
          find.descendant(
            of: box,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(availableHeader, findsNothing);
      });

      testWidgets('shows the failure message, and Retry requests again', (
        tester,
      ) async {
        givenRewards(const RewardsError('No internet connection'));
        await pumpMembership(tester);

        expect(find.text('No internet connection'), findsOneWidget);
        expect(availableHeader, findsNothing);
        verifyNever(() => rewardsBloc.add(const RewardsRequested()));

        await tester.tap(find.byKey(const Key('vouchers-retry')));
        await tester.pump();

        verify(() => rewardsBloc.add(const RewardsRequested())).called(1);
      });
    });

    group('available and unavailable', () {
      testWidgets('both sections are there, each under its own header', (
        tester,
      ) async {
        await pumpMembership(tester);

        expect(find.text('Voucher Tersedia'), findsOneWidget);
        expect(find.text('Voucher Tidak Tersedia'), findsOneWidget);
      });

      testWidgets('what the balance covers is available, the rest is not', (
        tester,
      ) async {
        // tStats has 80 points: 50 is covered, 100 and 250 are not.
        useTallScreen(tester);
        await pumpMembership(tester);

        final top = tester.getTopLeft;
        expect(top(availableHeader).dy, lessThan(top(unavailableHeader).dy));

        expect(find.text('Gratis Cuci Motor'), findsOneWidget);
        expect(find.text('50 pts'), findsOneWidget);
        expect(
          top(find.text('Gratis Cuci Motor')).dy,
          allOf(
            greaterThan(top(availableHeader).dy),
            lessThan(top(unavailableHeader).dy),
          ),
        );

        for (final name in [
          'Diskon Jasa Service Rp. 20.000,00',
          'Gratis Ganti Oli',
        ]) {
          expect(
            top(find.text(name)).dy,
            greaterThan(top(unavailableHeader).dy),
            reason: '$name costs more than the 80 points',
          );
        }
        expect(find.text('100 pts'), findsOneWidget);
        expect(find.text('250 pts'), findsOneWidget);
      });

      testWidgets('a voucher costing exactly the balance is available', (
        tester,
      ) async {
        givenRewards(
          const RewardsLoaded([
            RewardEntity(pointId: 'X', pointName: 'EXACT', pointQty: 80),
            RewardEntity(pointId: 'Y', pointName: 'ONE MORE', pointQty: 81),
          ]),
        );
        await pumpMembership(tester);

        final top = tester.getTopLeft;
        expect(
          top(find.text('Exact')).dy,
          lessThan(top(unavailableHeader).dy),
        );
        expect(
          top(find.text('One More')).dy,
          greaterThan(top(unavailableHeader).dy),
        );
      });

      testWidgets('each section keeps the order the API gave', (tester) async {
        useTallScreen(tester); // all four cards must be built
        givenRewards(
          const RewardsLoaded([
            RewardEntity(pointId: '1', pointName: 'Low B', pointQty: 20),
            RewardEntity(pointId: '2', pointName: 'High Z', pointQty: 900),
            RewardEntity(pointId: '3', pointName: 'Low A', pointQty: 10),
            RewardEntity(pointId: '4', pointName: 'High Y', pointQty: 800),
          ]),
        );
        await pumpMembership(tester);

        final top = tester.getTopLeft;
        expect(
          top(find.text('Low B')).dy,
          lessThan(top(find.text('Low A')).dy),
        );
        expect(
          top(find.text('High Z')).dy,
          lessThan(top(find.text('High Y')).dy),
        );
      });

      testWidgets('unavailable vouchers are dimmed, available ones are not', (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpMembership(tester);

        double opacityOf(String title) {
          final dimmed = find.ancestor(
            of: cardWith(title),
            matching: find.byType(Opacity),
          );
          return dimmed.evaluate().isEmpty
              ? 1.0
              : tester.widget<Opacity>(dimmed.first).opacity;
        }

        expect(opacityOf('Gratis Cuci Motor'), 1.0);
        expect(opacityOf('Gratis Ganti Oli'), lessThan(1.0));
        expect(opacityOf('Diskon Jasa Service Rp. 20.000,00'), lessThan(1.0));
      });

      testWidgets('the cards are rounded and sit inside the box', (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpMembership(tester);
        final box = roundedBoxAround(vouchersTab);

        expect(
          find.descendant(of: box, matching: find.byType(Card)),
          findsNWidgets(3),
        );
        for (final title in ['Gratis Cuci Motor', 'Gratis Ganti Oli']) {
          final card = tester.widget<Card>(cardWith(title));
          expect(
            (card.shape! as RoundedRectangleBorder).borderRadius,
            isNotNull,
          );
        }
      });

      testWidgets('nothing affordable: available says so, all are unavailable', (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpMembership(tester, stats: tEmptyStats); // 0 points

        expect(
          find.text('Point Anda belum cukup untuk voucher mana pun'),
          findsOneWidget,
        );
        expect(find.text('Semua voucher dapat Anda tukarkan'), findsNothing);
        // Still listed, below the unavailable header.
        expect(
          tester.getTopLeft(find.text('Gratis Cuci Motor')).dy,
          greaterThan(tester.getTopLeft(unavailableHeader).dy),
        );
      });

      testWidgets('everything affordable: unavailable says so', (tester) async {
        givenRewards(
          const RewardsLoaded([
            RewardEntity(pointId: 'A', pointName: 'CHEAP', pointQty: 5),
          ]),
        );
        await pumpMembership(tester);

        expect(find.text('Semua voucher dapat Anda tukarkan'), findsOneWidget);
        expect(
          find.text('Point Anda belum cukup untuk voucher mana pun'),
          findsNothing,
        );
        expect(find.text('Cheap'), findsOneWidget);
      });

      testWidgets('an empty API answer is one plain empty message', (
        tester,
      ) async {
        givenRewards(const RewardsLoaded([]));
        await pumpMembership(tester);

        expect(find.text('Tidak ada voucher tersedia'), findsOneWidget);
        expect(availableHeader, findsNothing);
        expect(unavailableHeader, findsNothing);
      });

      testWidgets('the member\'s own Detail2 vouchers are not listed here', (
        tester,
      ) async {
        await pumpMembership(tester);

        expect(find.text('Free oil change'), findsNothing);
      });
    });

    group('the card layout', () {
      // C00 is the available one in tRewards: 'GRATIS CUCI MOTOR' (shown as
      // 'Gratis Cuci Motor'), 50 pts.
      Finder card(String id) => find.byKey(Key('voucher-card-$id'));
      Finder details(String id) => find.byKey(Key('voucher-details-$id'));
      Finder icon(String id) => find.byKey(Key('voucher-icon-$id'));
      Finder divider(String id) => find.byKey(Key('voucher-divider-$id'));
      Finder klaim(String id) => find.byKey(Key('klaim-$id'));

      testWidgets('the details are on the left, the icon on the right', (
        tester,
      ) async {
        await pumpMembership(tester);

        expect(
          find.descendant(
            of: details('C00'),
            matching: find.text('Gratis Cuci Motor'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: details('C00'), matching: find.text('50 pts')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: icon('C00'),
            matching: find.byIcon(Icons.card_giftcard),
          ),
          findsOneWidget,
        );

        // Side by side: the details end before the icon begins...
        expect(
          tester.getTopRight(details('C00')).dx,
          lessThan(tester.getTopLeft(icon('C00')).dx),
        );
        // ...on the same row, the icon centred against the details.
        expect(
          tester.getCenter(icon('C00')).dy,
          closeTo(tester.getCenter(details('C00')).dy, 1),
        );
      });

      testWidgets('the name is shown with only its first letters uppercase', (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpMembership(tester);

        // The backend sends them in capitals; the cards tidy them.
        expect(find.text('Gratis Cuci Motor'), findsOneWidget);
        expect(find.text('GRATIS CUCI MOTOR'), findsNothing);
        // "Rp." and the amount inside a name are kept as they were.
        expect(find.text('Diskon Jasa Service Rp. 20.000,00'), findsOneWidget);
        expect(find.text('DISKON JASA SERVICE Rp. 20.000,00'), findsNothing);
      });

      testWidgets('the icon sits at the card\'s right edge, inside its padding', (
        tester,
      ) async {
        await pumpMembership(tester);

        expect(
          tester.getTopRight(icon('C00')).dx,
          closeTo(tester.getTopRight(card('C00')).dx - 16, 0.5),
        );
        expect(
          tester.getTopLeft(details('C00')).dx,
          closeTo(tester.getTopLeft(card('C00')).dx + 16, 0.5),
        );
      });

      testWidgets('the icon has a rounded box of its own', (tester) async {
        await pumpMembership(tester);

        final box = tester.widget<Container>(icon('C00'));
        final decoration = box.decoration! as BoxDecoration;
        expect(decoration.borderRadius, isNotNull);
        expect(tester.getSize(icon('C00')), const Size(56, 56));
      });

      testWidgets('a dashed line crosses the whole card under the details', (
        tester,
      ) async {
        await pumpMembership(tester);

        expect(divider('C00'), findsOneWidget);
        // Edge to edge of the card...
        expect(
          tester.getTopLeft(divider('C00')).dx,
          closeTo(tester.getTopLeft(card('C00')).dx, 0.5),
        );
        expect(
          tester.getTopRight(divider('C00')).dx,
          closeTo(tester.getTopRight(card('C00')).dx, 0.5),
        );
        // ...below both the details and the icon.
        final top = tester.getTopLeft(divider('C00')).dy;
        expect(top, greaterThanOrEqualTo(tester.getBottomLeft(details('C00')).dy));
        expect(top, greaterThanOrEqualTo(tester.getBottomLeft(icon('C00')).dy));
      });

      testWidgets('the line really is dashed, not solid', (tester) async {
        await pumpMembership(tester);

        final paint = tester.widget<CustomPaint>(
          find.descendant(of: divider('C00'), matching: find.byType(CustomPaint)),
        );
        expect(paint.painter, isNotNull);
        // A solid line would be one drawLine; dashes are many, with gaps.
        final recorder = _SegmentRecorder();
        paint.painter!.paint(recorder, const Size(100, 1.5));
        expect(recorder.segments.length, greaterThan(5));
        for (var i = 1; i < recorder.segments.length; i++) {
          expect(
            recorder.segments[i].$1,
            greaterThan(recorder.segments[i - 1].$2),
            reason: 'a gap between dash ${i - 1} and $i',
          );
        }
      });

      testWidgets('Klaim is in its own part below the line, not beside the text', (
        tester,
      ) async {
        await pumpMembership(tester);

        final line = tester.getBottomLeft(divider('C00')).dy;
        expect(tester.getTopLeft(klaim('C00')).dy, greaterThanOrEqualTo(line));
        expect(
          tester.getTopLeft(klaim('C00')).dy,
          greaterThan(tester.getBottomLeft(icon('C00')).dy),
        );
        expect(
          tester.getBottomLeft(klaim('C00')).dy,
          lessThanOrEqualTo(tester.getBottomLeft(card('C00')).dy),
        );
      });

      testWidgets('Klaim is pushed to the right and centred in the bottom part', (
        tester,
      ) async {
        await pumpMembership(tester);

        // Right: its edge is the card's, less the same 16 as the top part.
        expect(
          tester.getTopRight(klaim('C00')).dx,
          closeTo(tester.getTopRight(card('C00')).dx - 16, 0.5),
        );
        // Centre: as much room above it (under the line) as below it.
        final above =
            tester.getTopLeft(klaim('C00')).dy -
            tester.getBottomLeft(divider('C00')).dy;
        final below =
            tester.getBottomLeft(card('C00')).dy -
            tester.getBottomLeft(klaim('C00')).dy;
        expect(above, closeTo(below, 0.5));
      });

      testWidgets('a long name wraps beside the icon and never pushes it off', (
        tester,
      ) async {
        const name =
            'DISKON JASA SERVICE BERKALA DAN GANTI OLI MESIN SEPEDA MOTOR '
            'MATIC SEMUA TIPE Rp. 150.000,00';
        givenRewards(
          const RewardsLoaded([
            RewardEntity(pointId: 'LG', pointName: name, pointQty: 10),
          ]),
        );
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 900);
        addTearDown(tester.view.reset);
        await pumpMembership(tester);

        expect(tester.takeException(), isNull);
        // Shown tidied, not as the backend shouts it.
        expect(
          find.text(
            'Diskon Jasa Service Berkala Dan Ganti Oli Mesin Sepeda Motor '
            'Matic Semua Tipe Rp. 150.000,00',
          ),
          findsOneWidget,
        );
        expect(
          tester.getTopRight(icon('LG')).dx,
          closeTo(tester.getTopRight(card('LG')).dx - 16, 0.5),
        );
        expect(
          tester.getTopRight(details('LG')).dx,
          lessThan(tester.getTopLeft(icon('LG')).dx),
        );
        // Taller than a one-line name, and the Klaim is still under all of it.
        expect(tester.getSize(details('LG')).height, greaterThan(60));
        expect(
          tester.getTopLeft(klaim('LG')).dy,
          greaterThan(tester.getBottomLeft(details('LG')).dy),
        );
      });

      testWidgets('the text stays dark on the light card in dark mode', (
        tester,
      ) async {
        await pumpMembership(tester, theme: ThemeData.dark());

        Color colourOf(String text) {
          final finder = find.text(text);
          final style = DefaultTextStyle.of(tester.element(finder)).style.merge(
            tester.widget<Text>(finder).style,
          );
          return style.color!;
        }

        // The card is light grey even in dark mode; white text would vanish.
        expect(colourOf('Gratis Cuci Motor').computeLuminance(), lessThan(0.4));
        expect(colourOf('50 pts').computeLuminance(), lessThan(0.4));
      });
    });

    group('scrolling', () {
      testWidgets('both sections are one scrolling list, top to bottom', (
        tester,
      ) async {
        givenRewards(RewardsLoaded(tLongRewards));
        await pumpMembership(tester);
        final box = roundedBoxAround(vouchersTab);

        // One list holds the available header, and the unavailable one is
        // reachable by scrolling that same list.
        expect(
          find.descendant(of: box, matching: find.byType(ListView)),
          findsOneWidget,
        );
        expect(availableHeader, findsOneWidget);
        expect(unavailableHeader, findsNothing); // below the fold

        await tester.dragUntilVisible(
          unavailableHeader,
          find.byType(ListView),
          const Offset(0, -300),
        );
        expect(unavailableHeader, findsOneWidget);
        expect(availableHeader, findsNothing); // scrolled away
      });

      testWidgets('the very last voucher is reachable', (tester) async {
        givenRewards(RewardsLoaded(tLongRewards));
        await pumpMembership(tester);

        expect(find.text('Reward 29'), findsNothing);
        await tester.dragUntilVisible(
          find.text('Reward 29'),
          find.byType(ListView),
          const Offset(0, -300),
        );
        expect(find.text('Reward 29'), findsOneWidget);
      });

      testWidgets('a short list does not need to scroll but still can be pulled', (
        tester,
      ) async {
        await pumpMembership(tester);

        expect(tester.takeException(), isNull);
        expect(find.byType(ListView), findsOneWidget);
      });
    });
  });

  group('the Klaim button', () {
    // tStats has 80 points: C00 (50) is available, C01 (100) and C02 (250) are
    // not.
    Finder klaim(String pointId) => find.byKey(Key('klaim-$pointId'));

    bool isOn(WidgetTester tester, String pointId) =>
        tester.widget<ElevatedButton>(klaim(pointId)).onPressed != null;

    setUpAll(() {
      registerFallbackValue(
        const RedeemRequested(pointId: '', voucherName: ''),
      );
    });

    Future<void> tapKlaim(WidgetTester tester, String pointId) async {
      await tester.tap(klaim(pointId));
      await tester.pumpAndSettle();
    }

    group('on the cards', () {
      testWidgets('every voucher has one, available or not', (tester) async {
        useTallScreen(tester);
        await pumpMembership(tester);

        expect(find.text('Klaim'), findsNWidgets(3));
        for (final id in ['C00', 'C01', 'C02']) {
          expect(klaim(id), findsOneWidget, reason: '$id has a Klaim button');
        }
      });

      testWidgets('it is on for an available voucher, off for the others', (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpMembership(tester);

        expect(isOn(tester, 'C00'), isTrue);
        expect(isOn(tester, 'C01'), isFalse);
        expect(isOn(tester, 'C02'), isFalse);
      });

      testWidgets('a voucher costing exactly the balance can be claimed', (
        tester,
      ) async {
        givenRewards(
          const RewardsLoaded([
            RewardEntity(pointId: 'EX', pointName: 'EXACT', pointQty: 80),
            RewardEntity(pointId: 'ON', pointName: 'ONE MORE', pointQty: 81),
          ]),
        );
        useTallScreen(tester);
        await pumpMembership(tester);

        expect(isOn(tester, 'EX'), isTrue);
        expect(isOn(tester, 'ON'), isFalse);
      });

      testWidgets('tapping an off one does nothing at all', (tester) async {
        await pumpMembership(tester);

        await tester.tap(klaim('C01'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        verifyNever(() => redeemBloc.add(any()));
      });

      testWidgets('it fits beside the name on a narrow 360dp phone', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 800);
        addTearDown(tester.view.reset);
        await pumpMembership(tester);

        expect(tester.takeException(), isNull);
        expect(
          tester.getBottomRight(klaim('C00')).dx,
          lessThanOrEqualTo(360),
        );
      });
    });

    group('claiming', () {
      testWidgets('asks first, naming the voucher, its cost and what is left', (
        tester,
      ) async {
        await pumpMembership(tester);

        await tapKlaim(tester, 'C00');

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.textContaining('Gratis Cuci Motor'), findsWidgets);
        // Tidied here too, so the dialog never contradicts the card.
        expect(find.textContaining('GRATIS CUCI MOTOR'), findsNothing);
        expect(find.textContaining('50 pts'), findsWidgets);
        expect(find.textContaining('Sisa point Anda: 30 pts'), findsOneWidget);
        // Nothing has been sent just by asking.
        verifyNever(() => redeemBloc.add(any()));
      });

      testWidgets('Batal closes it and sends nothing', (tester) async {
        await pumpMembership(tester);
        await tapKlaim(tester, 'C00');

        await tester.tap(find.byKey(const Key('klaim-cancel')));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        verifyNever(() => redeemBloc.add(any()));
      });

      testWidgets('Ya, Klaim sends that one voucher\'s claim, once', (
        tester,
      ) async {
        await pumpMembership(tester);
        await tapKlaim(tester, 'C00');

        await tester.tap(find.byKey(const Key('klaim-confirm')));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        verify(
          () => redeemBloc.add(
            const RedeemRequested(
              pointId: 'C00',
              voucherName: 'GRATIS CUCI MOTOR',
            ),
          ),
        ).called(1);
      });

      testWidgets('while one is on its way every Klaim is off, one spins', (
        tester,
      ) async {
        givenRedeem(const RedeemInProgress('C00'));
        useTallScreen(tester);
        await pumpMembership(tester);
        await tester.pump(); // not settled: the spinner never stops

        for (final id in ['C00', 'C01', 'C02']) {
          expect(isOn(tester, id), isFalse, reason: '$id is off during a claim');
        }
        // The spinner is on the claimed card only; the others keep their label.
        expect(
          find.descendant(
            of: klaim('C00'),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: klaim('C00'), matching: find.text('Klaim')),
          findsNothing,
        );
        expect(
          find.descendant(of: klaim('C01'), matching: find.text('Klaim')),
          findsOneWidget,
        );
      });
    });

    group('the outcome', () {
      /// Pumps the page with a stream the test can push redeem states into.
      Future<(MockHomeBloc, StreamController<RedeemState>)> pumpWithRedeemStream(
        WidgetTester tester,
      ) async {
        final controller = StreamController<RedeemState>();
        addTearDown(controller.close);
        givenRedeem(const RedeemInitial(), thenEmits: controller.stream);
        final home = await pumpMembership(tester);
        return (home, controller);
      }

      testWidgets('success says so, naming the voucher, and reloads the points', (
        tester,
      ) async {
        final (home, redeem) = await pumpWithRedeemStream(tester);

        redeem.add(
          const RedeemSuccess(
            voucherName: 'GRATIS CUCI MOTOR',
            message: 'Berhasil',
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.text('Voucher "Gratis Cuci Motor" berhasil diklaim'),
          findsOneWidget,
        );
        // Once when the page opened, once because the points changed.
        verify(() => home.add(const HomeStatsRequested())).called(2);
      });

      testWidgets('a refusal shows the server\'s words and keeps the points', (
        tester,
      ) async {
        final (home, redeem) = await pumpWithRedeemStream(tester);

        redeem.add(const RedeemFailure('Point tidak cukup'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Point tidak cukup'), findsOneWidget);
        // Nothing was spent, so no reload beyond the one on open.
        verify(() => home.add(const HomeStatsRequested())).called(1);
      });

      testWidgets('a claim that finishes while Riwayat is showing is still reported', (
        tester,
      ) async {
        final (home, redeem) = await pumpWithRedeemStream(tester);
        await tester.tap(find.byKey(const Key('tab-history')));
        await tester.pumpAndSettle();
        expect(find.text('Service points'), findsOneWidget); // on Riwayat now

        redeem.add(
          const RedeemSuccess(voucherName: 'GRATIS CUCI MOTOR', message: 'ok'),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.text('Voucher "Gratis Cuci Motor" berhasil diklaim'),
          findsOneWidget,
        );
        verify(() => home.add(const HomeStatsRequested())).called(2);
      });

      testWidgets('merely idle or in flight shows nothing', (tester) async {
        final (_, redeem) = await pumpWithRedeemStream(tester);

        redeem.add(const RedeemInProgress('C00'));
        await tester.pump();
        await tester.pump();

        expect(find.byType(SnackBar), findsNothing);
      });
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
      for (final text in ['Point Saya', 'Riwayat']) {
        expect(
          find.descendant(
            of: find.byType(RefreshIndicator),
            matching: find.text(text),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('pulling on the Point Saya card refreshes', (tester) async {
      final bloc = await pumpMembership(tester);

      await pullDown(tester, find.text('Point Saya'));

      // Once when the page opened, once for the pull.
      verify(() => bloc.add(const HomeStatsRequested())).called(2);
    });

    testWidgets('pulling inside the box refreshes when it has few entries', (
      tester,
    ) async {
      final bloc = await pumpMembership(tester);

      await pullDown(tester, find.text('Riwayat'));

      verify(() => bloc.add(const HomeStatsRequested())).called(2);
    });

    testWidgets('pulling inside the box refreshes when it has many entries', (
      tester,
    ) async {
      final bloc = await pumpMembership(tester, stats: tLongStats);

      await pullDown(tester, find.text('Riwayat'));

      verify(() => bloc.add(const HomeStatsRequested())).called(2);
    });

    testWidgets('pulling down mid-list scrolls back up instead of refreshing', (
      tester,
    ) async {
      // The box opens on Voucher, so this is the voucher list that scrolls.
      givenRewards(RewardsLoaded(tLongRewards));
      final bloc = await pumpMembership(tester);

      // Scroll the box's list down, away from its top...
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      // ...then pull back a little: that is scrolling, not a refresh request.
      await tester.drag(find.byType(ListView), const Offset(0, 100));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const HomeStatsRequested())).called(1);
    });

    /// Like [pullDown], but never waits for the screen to settle: with the
    /// vouchers still loading a spinner runs forever, so it never would.
    Future<void> pullDownWithoutSettling(WidgetTester tester) async {
      await tester.drag(find.text('Point Saya'), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('also reloads the vouchers once they have loaded', (
      tester,
    ) async {
      await pumpMembership(tester); // RewardsLoaded

      await pullDown(tester, find.text('Point Saya'));

      verify(() => rewardsBloc.add(const RewardsRequested())).called(1);
    });

    testWidgets('does not pile a second request on vouchers not yet asked for', (
      tester,
    ) async {
      givenRewards(const RewardsInitial());
      await pumpMembership(tester);

      await pullDownWithoutSettling(tester);

      // Only the box's own first request when it opened — none from the pull.
      verify(() => rewardsBloc.add(const RewardsRequested())).called(1);
    });

    testWidgets('does not pile a second request on one still in flight', (
      tester,
    ) async {
      givenRewards(const RewardsLoading());
      await pumpMembership(tester);

      await pullDownWithoutSettling(tester);

      verifyNever(() => rewardsBloc.add(const RewardsRequested()));
    });
  });

  group('the box fills the rest of the page', () {
    testWidgets('with little content it still reaches the bottom', (
      tester,
    ) async {
      await pumpMembership(tester, stats: tEmptyStats);

      final box = roundedBoxAround(find.text('Riwayat'));

      // 20px of page padding below it, and nothing else — so it is as low as
      // the body goes, i.e. just above the navigation bar.
      expect(
        tester.getBottomLeft(box).dy,
        closeTo(pageBottom(tester) - 20, 0.5),
      );
    });

    testWidgets('with a few entries it reaches the bottom too', (tester) async {
      await pumpMembership(tester);

      final box = roundedBoxAround(find.text('Riwayat'));

      expect(
        tester.getBottomLeft(box).dy,
        closeTo(pageBottom(tester) - 20, 0.5),
      );
    });

    testWidgets('with many entries it stays on the page and scrolls inside', (
      tester,
    ) async {
      givenRewards(RewardsLoaded(tLongRewards));
      await pumpMembership(tester, stats: tLongStats);

      final box = roundedBoxAround(find.text('Riwayat'));

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

      // The last voucher (the box opens on Voucher) is reachable by scrolling
      // it. The box's list is the page's only ListView (the page itself is a
      // CustomScrollView), so it is found directly.
      expect(find.text('Reward 29'), findsNothing);
      await tester.dragUntilVisible(
        find.text('Reward 29'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      expect(find.text('Reward 29'), findsOneWidget);

      // The same goes for the history on the other tab.
      await tester.tap(find.byKey(const Key('tab-history')));
      await tester.pumpAndSettle();
      expect(find.text('Service points 29'), findsNothing);
      await tester.dragUntilVisible(
        find.text('Service points 29'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      expect(find.text('Service points 29'), findsOneWidget);
    });
  });
}

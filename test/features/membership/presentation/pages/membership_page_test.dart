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

/// Counts brightness calls instead of touching the real screen.
class _FakeBrightness implements ScreenBrightnessBooster {
  int boosts = 0;
  int restores = 0;

  @override
  Future<void> boost() async => boosts++;

  @override
  Future<void> restore() async => restores++;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    final aroundHistory = roundedBoxAround(find.text('Riwayat Point'));
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

    testWidgets('both tabs are there, history is open first', (tester) async {
      await pumpMembership(tester);

      expect(historyTab, findsOneWidget);
      expect(vouchersTab, findsOneWidget);
      expect(isSelected(tester, historyTab), isTrue);
      expect(isSelected(tester, vouchersTab), isFalse);
    });

    testWidgets('only the open tab shows its entries', (tester) async {
      await pumpMembership(tester);

      expect(find.text('Service points'), findsOneWidget);
      expect(find.text('Free oil change'), findsNothing);
    });

    testWidgets('tapping Vouchers swaps the list, and History swaps it back', (
      tester,
    ) async {
      await pumpMembership(tester);

      await open(tester, vouchersTab);
      expect(find.text('Free oil change'), findsOneWidget);
      expect(find.text('Service points'), findsNothing);
      expect(isSelected(tester, vouchersTab), isTrue);
      expect(isSelected(tester, historyTab), isFalse);

      await open(tester, historyTab);
      expect(find.text('Service points'), findsOneWidget);
      expect(find.text('Free oil change'), findsNothing);
      expect(isSelected(tester, historyTab), isTrue);
    });

    testWidgets('the entries are inside the box, as rounded cards', (
      tester,
    ) async {
      await pumpMembership(tester);
      final box = roundedBoxAround(historyTab);

      for (final tab in [historyTab, vouchersTab]) {
        await open(tester, tab);
        final entry = find.byType(ListTile);
        expect(find.descendant(of: box, matching: entry), findsOneWidget);

        final card = tester.widget<Card>(
          find.ancestor(of: entry, matching: find.byType(Card)),
        );
        expect((card.shape! as RoundedRectangleBorder).borderRadius, isNotNull);
      }
    });

    testWidgets('each tab has its own empty message', (tester) async {
      await pumpMembership(tester, stats: tEmptyStats);

      expect(find.text('Tidak ada riwayat point'), findsOneWidget);
      expect(find.text('Tidak ada voucher tersedia'), findsNothing);

      await open(tester, vouchersTab);
      expect(find.text('Tidak ada voucher tersedia'), findsOneWidget);
      expect(find.text('Tidak ada riwayat point'), findsNothing);
    });

    testWidgets('the tabs share the width equally, side by side', (
      tester,
    ) async {
      await pumpMembership(tester);

      final history = tester.getRect(historyTab);
      final vouchers = tester.getRect(vouchersTab);
      expect(history.width, closeTo(vouchers.width, 0.5));
      expect(history.top, vouchers.top);
      expect(vouchers.left, greaterThan(history.right));
    });

    testWidgets('the tabs stay put while the list scrolls', (tester) async {
      await pumpMembership(tester, stats: tLongStats);
      final before = tester.getTopLeft(historyTab);

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Service points 0'), findsNothing); // scrolled away
      expect(tester.getTopLeft(historyTab), before);
    });

    testWidgets('the tab and its list sit above the cards, inside the box', (
      tester,
    ) async {
      await pumpMembership(tester);

      // Tabs first, then the cards under them.
      expect(
        tester.getBottomLeft(historyTab).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(ListTile)).dy),
      );
    });
  });

  testWidgets('the loyalty points card stays outside the box', (tester) async {
    await pumpMembership(tester);

    final box = roundedBoxAround(find.text('Riwayat Point'));

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
      for (final text in ['Point Saya', 'Riwayat Point']) {
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

      await pullDown(tester, find.text('Riwayat Point'));

      verify(() => bloc.add(const HomeStatsRequested())).called(2);
    });

    testWidgets('pulling inside the box refreshes when it has many entries', (
      tester,
    ) async {
      final bloc = await pumpMembership(tester, stats: tLongStats);

      await pullDown(tester, find.text('Riwayat Point'));

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

      final box = roundedBoxAround(find.text('Riwayat Point'));

      // 20px of page padding below it, and nothing else — so it is as low as
      // the body goes, i.e. just above the navigation bar.
      expect(
        tester.getBottomLeft(box).dy,
        closeTo(pageBottom(tester) - 20, 0.5),
      );
    });

    testWidgets('with a few entries it reaches the bottom too', (tester) async {
      await pumpMembership(tester);

      final box = roundedBoxAround(find.text('Riwayat Point'));

      expect(
        tester.getBottomLeft(box).dy,
        closeTo(pageBottom(tester) - 20, 0.5),
      );
    });

    testWidgets('with many entries it stays on the page and scrolls inside', (
      tester,
    ) async {
      await pumpMembership(tester, stats: tLongStats);

      final box = roundedBoxAround(find.text('Riwayat Point'));

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

      // The last voucher (on the Vouchers tab) is reachable by scrolling it.
      // The box's list is the page's only ListView (the page itself is a
      // CustomScrollView), so it is found directly.
      await tester.tap(find.byKey(const Key('tab-vouchers')));
      await tester.pumpAndSettle();
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

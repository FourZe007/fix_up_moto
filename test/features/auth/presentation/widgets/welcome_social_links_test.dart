import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/welcome_social_links.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Made-up addresses: the real ones are not set yet.
const instagram = SocialLink(
  id: 'instagram',
  name: 'Instagram',
  icon: FontAwesomeIcons.instagram,
  url: 'https://www.instagram.com/example_account/',
);
const tiktok = SocialLink(
  id: 'tiktok',
  name: 'TikTok',
  icon: FontAwesomeIcons.tiktok,
  url: 'https://www.tiktok.com/@example_account',
);
const unsetInstagram = SocialLink(
  id: 'instagram',
  name: 'Instagram',
  icon: FontAwesomeIcons.instagram,
  url: '',
);

/// A phone-sized screen, [width] x [height] logical pixels at a pixel ratio of 3.
void usePhone(WidgetTester tester, {double width = 360, double height = 800}) {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> pumpLinks(
  WidgetTester tester, {
  List<SocialLink> links = const [instagram, tiktok],
  bool showUnset = false,
}) {
  usePhone(tester);
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: WelcomeSocialLinks(links: links, showUnset: showUnset),
        ),
      ),
    ),
  );
}

/// Stands in for the url_launcher plugin: answers every launch with [opens] (or
/// fails it, when [throws]) and records the calls it received.
List<MethodCall> mockLauncher({required bool opens, bool throws = false}) {
  final calls = <MethodCall>[];
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async {
    calls.add(call);
    if (throws) throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
    return opens;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return calls;
}

void main() {
  final instagramButton = find.byKey(const Key('welcome-social-instagram'));
  final tiktokButton = find.byKey(const Key('welcome-social-tiktok'));
  final label = find.text('Ikuti kami');

  test(
    'the page links are Instagram then TikTok, as the footer shows them',
    () {
      expect(WelcomeSocialLinks.defaultLinks.map((l) => l.id), [
        'instagram',
        'tiktok',
      ]);
      expect(WelcomeSocialLinks.defaultLinks.map((l) => l.name), [
        'Instagram',
        'TikTok',
      ]);
    },
  );

  test('an address of blanks counts as not set', () {
    expect(
      const SocialLink(
        id: 'x',
        name: 'X',
        icon: FontAwesomeIcons.instagram,
        url: '   ',
      ).isSet,
      isFalse,
    );
    expect(instagram.isSet, isTrue);
  });

  group('the footer', () {
    testWidgets('says "Ikuti kami" over an Instagram and a TikTok icon', (
      tester,
    ) async {
      await pumpLinks(tester);

      expect(label, findsOneWidget);
      // byIcon only takes Material's IconData, not Font Awesome's; a FaIcon
      // reports the plain IconData inside its glyph.
      Finder glyph(FaIconData icon) =>
          find.byWidgetPredicate((w) => w is FaIcon && w.icon == icon.data);
      expect(
        find.descendant(
          of: instagramButton,
          matching: glyph(FontAwesomeIcons.instagram),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tiktokButton,
          matching: glyph(FontAwesomeIcons.tiktok),
        ),
        findsOneWidget,
      );
      // Instagram first.
      expect(
        tester.getCenter(instagramButton).dx,
        lessThan(tester.getCenter(tiktokButton).dx),
      );
    });

    testWidgets('centres the label and the icons, as one group, on the '
        'page\'s axis', (tester) async {
      await pumpLinks(tester);

      final axis = tester.getCenter(find.byType(Scaffold)).dx;
      final text = tester.getRect(label);
      final ig = tester.getRect(instagramButton);
      final tt = tester.getRect(tiktokButton);

      // One row: the label first, then the two icons, all on one line.
      expect(text.right, lessThan(ig.left));
      expect(ig.right, lessThan(tt.left));

      // It is the group — from the label's left edge to the last icon's right
      // edge — that is centred, so it lines up with "Get started" and "Masuk".
      expect(text.expandToInclude(tt).center.dx, closeTo(axis, 0.5));
    });

    testWidgets('keeps the icons a matching pair, snug around their glyphs', (
      tester,
    ) async {
      await pumpLinks(tester);

      final ig = tester.getRect(instagramButton);
      final tt = tester.getRect(tiktokButton);

      // The same size, on the same line.
      expect(ig.size, tt.size);
      expect(ig.top, tt.top);
      // Snug around the glyph: the default 48 x 48 button was far wider than
      // the 20 px icon and left the two glyphs ~30 px apart.
      expect(ig.width, lessThanOrEqualTo(28));
      Rect glyph(Finder button) => tester.getRect(
        find.descendant(of: button, matching: find.byType(FaIcon)),
      );
      final glyphGap = glyph(tiktokButton).left - glyph(instagramButton).right;
      expect(glyphGap, lessThan(24));
    });

    testWidgets('centres the group too, when only one icon is set', (
      tester,
    ) async {
      await pumpLinks(tester, links: [unsetInstagram, tiktok]);

      final axis = tester.getCenter(find.byType(Scaffold)).dx;
      final group = tester
          .getRect(label)
          .expandToInclude(tester.getRect(tiktokButton));
      expect(group.center.dx, closeTo(axis, 0.5));
    });

    testWidgets('names each icon for screen readers', (tester) async {
      await pumpLinks(tester);

      expect(find.byTooltip('Instagram'), findsOneWidget);
      expect(find.byTooltip('TikTok'), findsOneWidget);
    });

    testWidgets('keeps the icons small and grey, still visible on the page', (
      tester,
    ) async {
      await pumpLinks(tester);

      final button = tester.widget<IconButton>(instagramButton);
      expect(button.color, AppColors.grey600);
      expect(tester.widget<FaIcon>(find.byType(FaIcon).first).size, 20);
      // Graphics need 3:1 against what they sit on.
      expect(
        contrast(AppColors.grey600, AppColors.backgroundLight),
        greaterThanOrEqualTo(3),
      );
    });

    testWidgets('wraps instead of overflowing on a narrow screen with large '
        'text', (tester) async {
      usePhone(tester, width: 240, height: 480);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: WelcomeSocialLinks(links: [instagram, tiktok])),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(instagramButton, findsOneWidget);
      expect(tiktokButton, findsOneWidget);
    });
  });

  group('opening a link', () {
    testWidgets('Instagram opens its page outside the app', (tester) async {
      final calls = mockLauncher(opens: true);
      await pumpLinks(tester);

      await tester.tap(instagramButton);
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'launch');
      final arguments = calls.single.arguments as Map;
      expect(arguments['url'], instagram.url);
      // Handed to the Instagram app (or the browser), not an in-app web view.
      expect(arguments['useWebView'], isFalse);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('TikTok opens its own page, not Instagram\'s', (tester) async {
      final calls = mockLauncher(opens: true);
      await pumpLinks(tester);

      await tester.tap(tiktokButton);
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect((calls.single.arguments as Map)['url'], tiktok.url);
    });

    testWidgets('says so when nothing can open it', (tester) async {
      mockLauncher(opens: false);
      await pumpLinks(tester);

      await tester.tap(instagramButton);
      await tester.pumpAndSettle();

      expect(find.text('Instagram tidak dapat dibuka'), findsOneWidget);
    });

    testWidgets('says so, instead of crashing, when the launch fails', (
      tester,
    ) async {
      mockLauncher(opens: true, throws: true);
      await pumpLinks(tester);

      await tester.tap(tiktokButton);
      await tester.pumpAndSettle();

      expect(find.text('TikTok tidak dapat dibuka'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('a link that is not set yet', () {
    testWidgets('is hidden when showUnset is off (a release build)', (
      tester,
    ) async {
      await pumpLinks(tester, links: [unsetInstagram, tiktok]);

      expect(instagramButton, findsNothing);
      expect(tiktokButton, findsOneWidget);
      expect(label, findsOneWidget, reason: 'one is still left to show');
    });

    testWidgets('leaves out the whole footer, label included, when none is '
        'set', (tester) async {
      await pumpLinks(tester, links: [unsetInstagram]);

      expect(label, findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('shows as a placeholder in debug and profile builds, and '
        'says so when tapped', (tester) async {
      final calls = mockLauncher(opens: true);
      await pumpLinks(tester, links: [unsetInstagram], showUnset: true);

      expect(instagramButton, findsOneWidget);
      await tester.tap(instagramButton);
      await tester.pumpAndSettle();

      expect(find.text('Link Instagram belum diatur'), findsOneWidget);
      expect(calls, isEmpty, reason: 'nothing to launch');
    });
  });
}

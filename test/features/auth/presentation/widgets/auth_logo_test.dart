import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/constants/asset_constants.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_logo.dart';

/// An asset bundle where only the logo fails to load (the rest, such as the
/// asset manifest Flutter needs to resolve images, comes from the real one), to
/// test the fallback.
class _BrokenBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == AssetConstants.logoRedText) {
      return Future<ByteData>.error(FlutterError('Unable to load asset: $key'));
    }
    return rootBundle.load(key);
  }
}

/// [AuthLogo] in a page with 24 px of padding, at the start edge unless
/// [center] is set. [width] is left out to use the logo's own default.
Future<void> pumpLogo(
  WidgetTester tester, {
  double? width,
  bool center = false,
  AssetBundle? bundle,
  bool disableAnimations = false,
}) {
  final logo = width == null ? const AuthLogo() : AuthLogo(width: width);

  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          devicePixelRatio: 3,
          disableAnimations: disableAnimations,
        ),
        child: DefaultAssetBundle(
          bundle: bundle ?? rootBundle,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              // Full width, so the Column has room to place the logo in it.
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: center
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [logo],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The real PNG's pixel size and the rectangle its visible (non-transparent)
/// pixels span, read from the bundled file itself.
Future<({Size size, Rect ink, bool cornerIsTransparent})> measureLogo(
  WidgetTester tester,
) async {
  final data = await rootBundle.load(AssetConstants.logoRedText);
  return (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    final bytes = (await image.toByteData())!;

    var left = image.width, top = image.height, right = 0, bottom = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final alpha = bytes.getUint8((y * image.width + x) * 4 + 3);
        if (alpha > 8) {
          if (x < left) left = x;
          if (x >= right) right = x + 1;
          if (y < top) top = y;
          if (y >= bottom) bottom = y + 1;
        }
      }
    }
    return (
      size: Size(image.width.toDouble(), image.height.toDouble()),
      ink: Rect.fromLTRB(
        left.toDouble(),
        top.toDouble(),
        right.toDouble(),
        bottom.toDouble(),
      ),
      cornerIsTransparent: bytes.getUint8(3) == 0,
    );
  }))!;
}

void main() {
  final image = find.byKey(const Key('auth-logo-image'));
  final box = find.byKey(const Key('auth-logo-box'));

  testWidgets('shows the transparent red-text logo from AssetConstants', (
    tester,
  ) async {
    await pumpLogo(tester);
    await tester.pumpAndSettle();

    // Unwrap the ResizeImage that cacheWidth adds.
    var provider = tester.widget<Image>(image).image;
    if (provider is ResizeImage) provider = provider.imageProvider;

    expect((provider as AssetImage).assetName, AssetConstants.logoRedText);
    expect(
      AssetConstants.logoRedText,
      endsWith('fixupmoto_logo_colored_text.png'),
    );
  });

  testWidgets('is labelled for screen readers', (tester) async {
    await pumpLogo(tester);
    await tester.pumpAndSettle();

    expect(tester.widget<Image>(image).semanticLabel, 'FixUp Moto');
  });

  testWidgets('decodes at the size it is drawn, not whatever the file is', (
    tester,
  ) async {
    await pumpLogo(tester);
    await tester.pumpAndSettle();

    final provider = tester.widget<Image>(image).image as ResizeImage;
    // The 500 px canvas is drawn 180 logical px wide: 180 * 3 (pixel ratio).
    expect(provider.width, 540);
  });

  group('the file itself', () {
    testWidgets('is a transparent 500x500 canvas, as the crop assumes', (
      tester,
    ) async {
      final logo = await measureLogo(tester);

      expect(logo.size, const Size(500, 500));
      expect(logo.cornerIsTransparent, isTrue);
    });
  });

  // The default is the size it was first used at; the others include the large
  // one the welcome screen draws it at.
  for (final width in [144.0, 200.0, 260.0]) {
    group('drawn $width px wide', () {
      testWidgets('is a 2:1 window, not the whole square', (tester) async {
        await pumpLogo(tester, width: width);
        await tester.pumpAndSettle();

        expect(tester.getSize(box), Size(width, width / 2));
      });

      testWidgets('contains all of the lettering, without cutting it off', (
        tester,
      ) async {
        final logo = await measureLogo(tester);
        await pumpLogo(tester, width: width);
        await tester.pumpAndSettle();

        // Where the lettering lands on screen: the canvas rect, scaled.
        final canvas = tester.getRect(image);
        final scale = canvas.width / logo.size.width;
        final lettering = Rect.fromLTRB(
          canvas.left + logo.ink.left * scale,
          canvas.top + logo.ink.top * scale,
          canvas.left + logo.ink.right * scale,
          canvas.top + logo.ink.bottom * scale,
        );
        final window = tester.getRect(box);

        expect(
          window.contains(lettering.topLeft) &&
              window.contains(lettering.bottomRight),
          isTrue,
          reason: 'lettering $lettering must fit in the window $window',
        );
      });

      testWidgets('does not leave much spare room around the lettering', (
        tester,
      ) async {
        final logo = await measureLogo(tester);
        await pumpLogo(tester, width: width);
        await tester.pumpAndSettle();

        final canvas = tester.getRect(image);
        final scale = canvas.width / logo.size.width;
        final window = tester.getRect(box);
        // A few source pixels of margin, at this scale: under 3% of the width.
        final spare = width * 0.03;

        expect(
          canvas.left + logo.ink.left * scale - window.left,
          lessThan(spare),
        );
        expect(
          window.right - (canvas.left + logo.ink.right * scale),
          lessThan(spare),
        );
        expect(canvas.top + logo.ink.top * scale - window.top, lessThan(spare));
        expect(
          window.bottom - (canvas.top + logo.ink.bottom * scale),
          lessThan(spare),
        );
      });

      testWidgets('is decoded no larger than it is drawn', (tester) async {
        await pumpLogo(tester, width: width);
        await tester.pumpAndSettle();

        final provider = tester.widget<Image>(image).image as ResizeImage;
        // The canvas is drawn width / 0.8 wide, at a pixel ratio of 3.
        expect(provider.width, (width / 0.8 * 3).round());
      });
    });
  }

  group('placement', () {
    testWidgets('takes the width it is given and sits where its parent puts '
        'it: at the start edge', (tester) async {
      await pumpLogo(tester, width: 200);
      await tester.pumpAndSettle();

      // 24 px of page padding, then the logo itself.
      expect(tester.getTopLeft(box).dx, 24);
      expect(tester.getSize(box).width, 200);
    });

    testWidgets('or in the middle', (tester) async {
      await pumpLogo(tester, width: 200, center: true);
      await tester.pumpAndSettle();

      expect(
        tester.getCenter(box).dx,
        tester.getSize(find.byType(Scaffold)).width / 2,
      );
    });
  });

  testWidgets('has no box, fill or glow behind the lettering', (tester) async {
    await pumpLogo(tester);
    await tester.pumpAndSettle();

    for (final type in [ClipRRect, DecoratedBox, ColoredBox, PhysicalModel]) {
      expect(
        find.descendant(of: find.byType(AuthLogo), matching: find.byType(type)),
        findsNothing,
        reason: '$type would draw something behind the transparent logo',
      );
    }
  });

  testWidgets('fades in once on first show', (tester) async {
    await pumpLogo(tester);

    double opacity() => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byType(AuthLogo),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;

    expect(opacity(), 0);

    await tester.pump(const Duration(milliseconds: 200));
    expect(opacity(), allOf(greaterThan(0), lessThan(1)));

    await tester.pumpAndSettle();
    expect(opacity(), 1);
  });

  testWidgets('does not animate when the OS asks for no animations', (
    tester,
  ) async {
    await pumpLogo(tester, disableAnimations: true);
    await tester.pump();

    final opacity = tester
        .widget<Opacity>(
          find.descendant(
            of: find.byType(AuthLogo),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    expect(opacity, 1);
  });

  testWidgets('falls back to red FIXUP MOTO text if the asset cannot load', (
    tester,
  ) async {
    await pumpLogo(tester, bundle: _BrokenBundle());
    // Let the failed load report back (it runs in real time, outside the
    // test's fake clock), then rebuild with the error.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text('FIXUP MOTO'));
    expect(text.style?.color, const Color(0xFFFE0000));
    // The logo keeps its size, so the page layout does not jump.
    expect(tester.getSize(box), const Size(144, 72));
  });
}

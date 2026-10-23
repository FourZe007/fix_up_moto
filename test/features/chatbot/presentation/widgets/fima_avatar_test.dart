import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/constants/asset_constants.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/fima_avatar.dart';

Future<void> pumpAvatar(
  WidgetTester tester, {
  double? size,
  double pixelRatio = 3,
}) async {
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: size == null ? const FimaAvatar() : FimaAvatar(size: size),
      ),
    ),
  );
}

void main() {
  final image = find.descendant(
    of: find.byType(FimaAvatar),
    matching: find.byType(Image),
  );

  /// The asset behind the (possibly resized) image provider.
  AssetImage assetOf(WidgetTester tester) {
    final provider = tester.widget<Image>(image).image;
    return (provider is ResizeImage ? provider.imageProvider : provider)
        as AssetImage;
  }

  group('her portrait', () {
    testWidgets('is Fima\'s picture, not an icon', (tester) async {
      await pumpAvatar(tester);

      expect(assetOf(tester).assetName, AssetConstants.fimaAvatar);
      expect(find.byType(Icon), findsNothing);
      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
    });

    testWidgets('is cut to a circle, on a soft tint of the brand colour', (
      tester,
    ) async {
      await pumpAvatar(tester);

      expect(
        find.descendant(
          of: find.byType(FimaAvatar),
          matching: find.byType(ClipOval),
        ),
        findsOneWidget,
      );
      final backdrop = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(FimaAvatar),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = backdrop.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, AppColors.primary.withValues(alpha: 0.12));
    });

    for (final (label, size) in [
      ('a bubble\'s default', null),
      ('the app bar\'s', 36.0),
      ('the greeting\'s', 72.0),
    ]) {
      testWidgets('takes $label size', (tester) async {
        await pumpAvatar(tester, size: size);

        final expected = size ?? 32.0;
        expect(tester.getSize(find.byType(FimaAvatar)), Size(expected, expected));
      });
    }

    testWidgets('is zoomed in, so her face is not lost at the small size', (
      tester,
    ) async {
      await pumpAvatar(tester, size: 32);

      // Drawn larger than the circle that clips it.
      expect(tester.getSize(image).width, greaterThan(32));
      expect(tester.takeException(), isNull);
    });

    testWidgets('is decoded at the size it is drawn at, for the screen\'s '
        'pixel ratio', (tester) async {
      await pumpAvatar(tester, size: 32, pixelRatio: 3);
      final drawn = tester.getSize(image).width;

      final provider = tester.widget<Image>(image).image as ResizeImage;
      expect(provider.width, (drawn * 3).round());

      await pumpAvatar(tester, size: 32, pixelRatio: 2);
      final sharper = tester.widget<Image>(image).image as ResizeImage;
      expect(sharper.width, (drawn * 2).round());
    });

    testWidgets('is silent for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAvatar(tester);

      // No label of its own: her name sits beside her in the app bar and the
      // greeting, and an announcement on every bubble would only be noise.
      expect(
        find.descendant(
          of: find.byType(FimaAvatar),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
      expect(tester.widget<Image>(image).excludeFromSemantics, isTrue);
      handle.dispose();
    });
  });

  group('the picture file', () {
    test('is bundled with the app', () async {
      final bytes = await rootBundle.load(AssetConstants.fimaAvatar);

      expect(bytes.lengthInBytes, greaterThan(0));
    });

    test('is small enough to ship', () async {
      final bytes = await rootBundle.load(AssetConstants.fimaAvatar);

      // It is only ever drawn at 72 px or less.
      expect(bytes.lengthInBytes, lessThan(200 * 1024));
    });
  });
}

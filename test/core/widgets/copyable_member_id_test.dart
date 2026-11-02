import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/copyable_member_id.dart';

const _id = '0101202400000014';

/// Stands in for the platform clipboard: records every `setData` call.
List<String> mockClipboard() {
  final copied = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      copied.add((call.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return copied;
}

Future<void> pump(
  WidgetTester tester, {
  String memberId = _id,
  CopyableMemberIdStyle style = CopyableMemberIdStyle.pill,
  bool showSnackBar = true,
  double? width,
}) async {
  Widget child = CopyableMemberId(
    key: const Key('id'),
    memberId: memberId,
    style: style,
    showSnackBar: showSnackBar,
  );
  if (width != null) {
    // Left-aligned, like the Profile header's column.
    child = Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(width: width, child: child),
    );
  }
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  final id = find.byKey(const Key('id'));
  final copyIcon = find.byIcon(Icons.content_copy);
  final checkIcon = find.byIcon(Icons.check);
  final snackbar = find.text('ID Member disalin');

  group('the pill', () {
    testWidgets('shows an ID tag, the number and a copy icon', (tester) async {
      await pump(tester);

      expect(find.text('ID'), findsOneWidget);
      expect(find.text(_id), findsOneWidget);
      expect(copyIcon, findsOneWidget);
      expect(checkIcon, findsNothing);
    });

    testWidgets('is a peach pill, like the row tiles on the same page', (
      tester,
    ) async {
      await pump(tester);

      final material = tester.widget<Material>(
        find.descendant(of: id, matching: find.byType(Material)).first,
      );
      expect(material.color, AppColors.peachMist);
      expect(material.shape, isA<StadiumBorder>());
    });

    testWidgets('tapping it copies the ID', (tester) async {
      final copied = mockClipboard();
      await pump(tester);

      await tester.tap(id);
      await tester.pump();

      expect(copied, [_id]);
    });

    testWidgets('tapping the number copies it too, not only the icon', (
      tester,
    ) async {
      final copied = mockClipboard();
      await pump(tester);

      await tester.tap(find.text(_id));
      await tester.pump();

      expect(copied, [_id]);
    });

    testWidgets('turns the icon into a green check and shows a snackbar', (
      tester,
    ) async {
      mockClipboard();
      await pump(tester);

      await tester.tap(id);
      await tester.pump();

      expect(checkIcon, findsOneWidget);
      expect(copyIcon, findsNothing);
      expect(tester.widget<Icon>(checkIcon).color, AppColors.success);
      expect(snackbar, findsOneWidget);
    });

    testWidgets('goes back to the copy icon after two seconds', (tester) async {
      mockClipboard();
      await pump(tester);

      await tester.tap(id);
      await tester.pump();
      await tester.pump(
        CopyableMemberId.copiedFor - const Duration(seconds: 1),
      );
      expect(checkIcon, findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(copyIcon, findsOneWidget);
      expect(checkIcon, findsNothing);
    });

    testWidgets('a second tap restarts the countdown and does not stack '
        'snackbars', (tester) async {
      final copied = mockClipboard();
      await pump(tester);

      await tester.tap(id);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.tap(id);
      await tester.pump();
      // 1.5 s after the first tap would have reset it, had it not restarted.
      await tester.pump(const Duration(milliseconds: 1000));

      expect(copied, [_id, _id]);
      expect(checkIcon, findsOneWidget);
      expect(snackbar, findsOneWidget);

      // Two seconds after the second tap, not the first.
      await tester.pump(const Duration(seconds: 1));
      expect(copyIcon, findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('copies and shows the ID trimmed', (tester) async {
      final copied = mockClipboard();
      await pump(tester, memberId: '  $_id ');

      expect(find.text(_id), findsOneWidget);
      await tester.tap(id);
      await tester.pump();

      expect(copied, [_id]);
    });

    testWidgets('is read as one button that says what it copies', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);

      expect(
        tester.getSemantics(id),
        matchesSemantics(
          label: 'Salin ID Member $_id',
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('has a tooltip', (tester) async {
      await pump(tester);

      expect(find.byTooltip('Salin ID Member'), findsOneWidget);
    });

    testWidgets('scales down instead of overflowing in a narrow space', (
      tester,
    ) async {
      await pump(tester, width: 120);

      expect(tester.takeException(), isNull);
      expect(tester.getSize(id).width, lessThanOrEqualTo(120));
      // Still all there, just smaller.
      expect(find.text(_id), findsOneWidget);
    });

    testWidgets('can be torn down while the check is showing', (tester) async {
      mockClipboard();
      await pump(tester);

      await tester.tap(id);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());

      // A timer left running would fail the test on its own.
      expect(tester.takeException(), isNull);
    });
  });

  group('the plain style', () {
    testWidgets('shows the number and the icon, with no ID tag', (
      tester,
    ) async {
      await pump(tester, style: CopyableMemberIdStyle.plain);

      expect(find.text(_id), findsOneWidget);
      expect(find.text('ID'), findsNothing);
      expect(copyIcon, findsOneWidget);
    });

    testWidgets('has no pill of its own', (tester) async {
      await pump(tester, style: CopyableMemberIdStyle.plain);

      final material = tester.widget<Material>(
        find.descendant(of: id, matching: find.byType(Material)).first,
      );
      expect(material.type, MaterialType.transparency);
    });

    testWidgets('copies, and turns into a check, without a snackbar when it '
        'is switched off', (tester) async {
      final copied = mockClipboard();
      await pump(
        tester,
        style: CopyableMemberIdStyle.plain,
        showSnackBar: false,
      );

      await tester.tap(id);
      await tester.pump();

      expect(copied, [_id]);
      expect(checkIcon, findsOneWidget);
      expect(snackbar, findsNothing);
    });
  });
}

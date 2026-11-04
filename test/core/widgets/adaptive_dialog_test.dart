import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/widgets/adaptive_dialog.dart';

/// Opens an [AdaptiveAlertDialog] on a theme that reports [platform], the way
/// the app does (through `showAdaptiveDialog`), and records what it returns.
class DialogOutcome {
  String? result = 'not closed yet';
}

Future<DialogOutcome> openDialog(
  WidgetTester tester,
  TargetPlatform platform, {
  bool destructive = false,
  bool isDefault = false,
}) async {
  final opened = DialogOutcome();

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                opened.result = await showAdaptiveDialog<String>(
                  context: context,
                  builder: (dialogContext) => AdaptiveAlertDialog(
                    title: const Text('Hapus?'),
                    content: const Text('Tindakan ini tidak dapat dibatalkan.'),
                    actions: [
                      AdaptiveDialogAction(
                        key: const Key('no'),
                        onPressed: () => Navigator.pop(dialogContext, 'no'),
                        child: const Text('Batal'),
                      ),
                      AdaptiveDialogAction(
                        key: const Key('yes'),
                        isDestructive: destructive,
                        isDefault: isDefault,
                        onPressed: () => Navigator.pop(dialogContext, 'yes'),
                        child: const Text('Ya'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  group('on Android', () {
    testWidgets('is the ordinary Material dialog with ordinary buttons', (
      tester,
    ) async {
      await openDialog(tester, TargetPlatform.android);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.text('Hapus?'), findsOneWidget);
      expect(find.text('Tindakan ini tidak dapat dibatalkan.'), findsOneWidget);

      final yes = tester.widget<TextButton>(
        find.descendant(
          of: find.byKey(const Key('yes')),
          matching: find.byType(TextButton),
        ),
      );
      // Nothing is added to the button, so it looks as it always did.
      expect(yes.style, isNull);
    });

    testWidgets('a destructive action is not coloured, as before', (
      tester,
    ) async {
      await openDialog(tester, TargetPlatform.android, destructive: true);

      final yes = tester.widget<TextButton>(
        find.descendant(
          of: find.byKey(const Key('yes')),
          matching: find.byType(TextButton),
        ),
      );
      expect(yes.style, isNull);
    });

    testWidgets('a button can be found and tapped by its key', (tester) async {
      final opened = await openDialog(tester, TargetPlatform.android);

      await tester.tap(find.byKey(const Key('yes')));
      await tester.pumpAndSettle();

      expect(opened.result, 'yes');
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('on iOS', () {
    testWidgets('is the iOS alert with iOS buttons', (tester) async {
      await openDialog(tester, TargetPlatform.iOS);

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(CupertinoDialogAction), findsNWidgets(2));
      expect(find.text('Hapus?'), findsOneWidget);
    });

    testWidgets('marks the destructive and the default action', (tester) async {
      await openDialog(
        tester,
        TargetPlatform.iOS,
        destructive: true,
        isDefault: true,
      );

      final yes = tester.widget<CupertinoDialogAction>(
        find.descendant(
          of: find.byKey(const Key('yes')),
          matching: find.byType(CupertinoDialogAction),
        ),
      );
      expect(yes.isDestructiveAction, isTrue);
      expect(yes.isDefaultAction, isTrue);

      final no = tester.widget<CupertinoDialogAction>(
        find.descendant(
          of: find.byKey(const Key('no')),
          matching: find.byType(CupertinoDialogAction),
        ),
      );
      expect(no.isDestructiveAction, isFalse);
      expect(no.isDefaultAction, isFalse);
    });

    testWidgets('a button can be found and tapped by its key', (tester) async {
      final opened = await openDialog(tester, TargetPlatform.iOS);

      await tester.tap(find.byKey(const Key('no')));
      await tester.pumpAndSettle();

      expect(opened.result, 'no');
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });
  });
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/widgets/app_spinner.dart';
import 'package:fix_up_moto/features/feeds/domain/entities/feed_entity.dart';
import 'package:fix_up_moto/features/feeds/presentation/bloc/feeds_bloc.dart';
import 'package:fix_up_moto/features/feeds/presentation/bloc/feeds_event.dart';
import 'package:fix_up_moto/features/feeds/presentation/bloc/feeds_state.dart';
import 'package:fix_up_moto/features/feeds/presentation/pages/feeds_page.dart';

class MockFeedsBloc extends MockBloc<FeedsEvent, FeedsState>
    implements FeedsBloc {}

/// A post that is not a video, so nothing starts a real video player.
const post = FeedEntity(
  id: '1',
  caption: 'Servis rutin motor kamu',
  mediaType: 'IMAGE',
  mediaUrl: 'https://cdn.example.com/photo.jpg',
  permalink: 'https://www.instagram.com/reel/ABC123/',
  timestamp: '2026-01-01T00:00:00+0000',
);

/// The two ways MainShell can lay the Feed out above a 100-tall tab bar, on an
/// 800-tall screen.
///
/// **Before:** the page ends where the bar begins, so it is 700 tall and has no
/// bottom padding (Android, and every other tab).
/// **Under the bar (iOS):** the page runs to the bottom edge, so it is 800 tall,
/// and is told the bar's 100 as its bottom padding.
///
/// The Feed has to look the same in both, apart from the video behind the bar.
enum Layout {
  endsAboveBar(height: 700, bottomPadding: 0),
  runsUnderBar(height: 800, bottomPadding: 100);

  final double height;
  final double bottomPadding;
  const Layout({required this.height, required this.bottomPadding});
}

/// The Feed showing [state] in [layout]; the page is 400 wide.
Future<void> pumpFeeds(
  WidgetTester tester,
  MockFeedsBloc bloc,
  FeedsState state,
  Layout layout,
) async {
  tester.view.physicalSize = Size(400, layout.height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  whenListen(bloc, const Stream<FeedsState>.empty(), initialState: state);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(padding: EdgeInsets.only(bottom: layout.bottomPadding)),
        child: child!,
      ),
      home: const FeedsPage(),
    ),
  );
  await tester.pump();
}

void main() {
  late MockFeedsBloc bloc;

  setUp(() {
    bloc = MockFeedsBloc();
    sl.registerFactory<FeedsBloc>(() => bloc);
  });
  tearDown(() => sl.reset());

  group('the centred messages sit where they did above the bar', () {
    final cases = <(String, Finder, FeedsState)>[
      ('loading spinner', find.byType(AppSpinner), const FeedsLoading()),
      ('empty message', find.text('No posts yet'), const FeedsLoaded([])),
      ('error message', find.text('boom'), const FeedsError('boom')),
    ];

    for (final (name, finder, state) in cases) {
      testWidgets('the $name', (tester) async {
        await pumpFeeds(tester, bloc, state, Layout.endsAboveBar);
        final before = tester.getCenter(finder);

        await pumpFeeds(tester, bloc, state, Layout.runsUnderBar);

        expect(tester.getCenter(finder), before);
      });
    }

    testWidgets('the end-of-feed card', (tester) async {
      const state = FeedsLoaded([post]);
      final card = find.text("You're all caught up");

      Future<Offset> cardCentre(Layout layout) async {
        await pumpFeeds(tester, bloc, state, layout);
        await tester.fling(find.byType(PageView), const Offset(0, -500), 3000);
        await tester.pumpAndSettle();
        return tester.getCenter(card);
      }

      final before = await cardCentre(Layout.endsAboveBar);

      expect(await cardCentre(Layout.runsUnderBar), before);
    });
  });

  group('a reel\'s caption and buttons', () {
    final shareButton = find.widgetWithIcon(IconButton, Icons.share);
    final caption = find.text('Servis rutin motor kamu');

    testWidgets('sit where they did when the page ended above the bar', (
      tester,
    ) async {
      const state = FeedsLoaded([post]);

      await pumpFeeds(tester, bloc, state, Layout.endsAboveBar);
      final captionBefore = tester.getRect(caption);
      final shareBefore = tester.getRect(shareButton);

      await pumpFeeds(tester, bloc, state, Layout.runsUnderBar);

      expect(tester.getRect(caption), captionBefore);
      expect(tester.getRect(shareButton), shareBefore);
    });

    testWidgets('stay clear of the bar they now run under', (tester) async {
      await pumpFeeds(
        tester,
        bloc,
        const FeedsLoaded([post]),
        Layout.runsUnderBar,
      );

      // The bar covers the bottom 100 of the 800.
      expect(tester.getRect(shareButton).bottom, lessThanOrEqualTo(700));
      expect(tester.getRect(caption).bottom, lessThanOrEqualTo(700));
    });
  });
}

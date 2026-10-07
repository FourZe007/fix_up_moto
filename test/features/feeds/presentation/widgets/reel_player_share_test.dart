import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/services/share_service.dart';
import 'package:fix_up_moto/features/feeds/domain/entities/feed_entity.dart';
import 'package:fix_up_moto/features/feeds/presentation/widgets/reel_player.dart';

/// Records what would have been shared instead of opening a real share sheet.
class _FakeShareService implements ShareService {
  final List<String> shared = [];
  final List<Rect?> origins = [];
  bool succeeds = true;

  @override
  Future<bool> shareText(String text, {Rect? sharePositionOrigin}) async {
    shared.add(text);
    origins.add(sharePositionOrigin);
    return succeeds;
  }
}

FeedEntity post({
  String caption = 'Servis rutin motor kamu',
  String permalink = 'https://www.instagram.com/reel/ABC123/',
}) => FeedEntity(
  id: '1',
  caption: caption,
  // Not a video, so nothing tries to start a real VideoPlayerController.
  mediaType: 'IMAGE',
  mediaUrl: 'https://cdn.example.com/photo.jpg?sig=expiring',
  permalink: permalink,
  timestamp: '2026-01-01T00:00:00+0000',
);

Future<void> pumpReel(WidgetTester tester, FeedEntity feed) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReelPlayer(post: feed, isActive: false)),
      ),
    );

void main() {
  late _FakeShareService share;

  setUp(() {
    share = _FakeShareService();
    sl.registerSingleton<ShareService>(share);
  });
  tearDown(() => sl.reset());

  final shareButton = find.widgetWithIcon(IconButton, Icons.share);

  testWidgets('the share button is on the reel', (tester) async {
    await pumpReel(tester, post());

    expect(shareButton, findsOneWidget);
  });

  testWidgets('tapping it shares just the Instagram link, not the caption', (
    tester,
  ) async {
    await pumpReel(tester, post());

    await tester.tap(shareButton);
    await tester.pump();

    expect(share.shared, ['https://www.instagram.com/reel/ABC123/']);
  });

  testWidgets('it never shares the expiring media file URL', (tester) async {
    await pumpReel(tester, post());

    await tester.tap(shareButton);
    await tester.pump();

    expect(share.shared.single, isNot(contains('cdn.example.com')));
  });

  testWidgets('it anchors the share popover to the button (for iPads)', (
    tester,
  ) async {
    await pumpReel(tester, post());

    await tester.tap(shareButton);
    await tester.pump();

    final origin = share.origins.single!;
    expect(origin, tester.getRect(shareButton));
  });

  testWidgets('a reel without a link opens nothing, even with a caption', (
    tester,
  ) async {
    await pumpReel(tester, post(permalink: ''));

    await tester.tap(shareButton);
    await tester.pump();

    expect(share.shared, isEmpty);
  });

  testWidgets('when sharing cannot open, the user is told instead of nothing '
      'happening', (tester) async {
    share.succeeds = false;
    await pumpReel(tester, post());

    await tester.tap(shareButton);
    await tester.pump();

    expect(find.text('Unable to open sharing'), findsOneWidget);
  });

  testWidgets('when sharing works there is no error message', (tester) async {
    await pumpReel(tester, post());

    await tester.tap(shareButton);
    await tester.pump();

    expect(find.text('Unable to open sharing'), findsNothing);
  });
}

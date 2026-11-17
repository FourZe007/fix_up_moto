import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/widgets/app_spinner.dart';
import 'package:fix_up_moto/features/feeds/domain/entities/feed_entity.dart';
import 'package:fix_up_moto/features/feeds/presentation/widgets/reel_player.dart';

/// A VIDEO that Instagram sent without a file link (no thumbnail either, so
/// the test never reaches for the network).
const videoWithoutFile = FeedEntity(
  id: '1',
  caption: 'Servis rutin motor kamu',
  mediaType: 'VIDEO',
  permalink: 'https://www.instagram.com/reel/ABC123/',
  timestamp: '2026-11-13T10:51:59+0000',
);

void main() {
  test('a video without a file link is not playable', () {
    expect(videoWithoutFile.isVideo, isTrue);
    expect(videoWithoutFile.isPlayable, isFalse);
  });

  testWidgets('it does not try to play it, even while it is the active reel', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReelPlayer(post: videoWithoutFile, isActive: true),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(AppSpinner), findsNothing); // nothing is loading
    expect(find.byIcon(Icons.error_outline), findsNothing); // nor failed
  });

  testWidgets('there is no mute button, but open and share are still there', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReelPlayer(post: videoWithoutFile, isActive: true),
        ),
      ),
    );

    expect(find.byIcon(Icons.volume_off), findsNothing);
    expect(find.byIcon(Icons.volume_up), findsNothing);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.byIcon(Icons.share), findsOneWidget);
    expect(find.text('Servis rutin motor kamu'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/feeds/domain/entities/feed_entity.dart';
import 'package:fix_up_moto/features/feeds/presentation/utils/reel_share_text.dart';

FeedEntity post({
  String caption = 'Servis rutin motor kamu',
  String permalink = 'https://www.instagram.com/reel/ABC123/',
  String mediaUrl = 'https://cdn.example.com/video.mp4?sig=expiring',
}) => FeedEntity(
  id: '1',
  caption: caption,
  mediaType: 'VIDEO',
  mediaUrl: mediaUrl,
  permalink: permalink,
  timestamp: '2026-01-01T00:00:00+0000',
);

void main() {
  test('is just the Instagram link', () {
    expect(reelShareText(post()), 'https://www.instagram.com/reel/ABC123/');
  });

  test('leaves the caption out, whatever it says', () {
    expect(
      reelShareText(post(caption: 'Servis rutin')),
      isNot(contains('Servis')),
    );
    expect(
      reelShareText(post(caption: 'a' * 5000)),
      'https://www.instagram.com/reel/ABC123/',
    );
    expect(
      reelShareText(post(caption: '')),
      reelShareText(post(caption: 'anything')),
    );
  });

  test('shares the permalink, never the expiring media file URL', () {
    final text = reelShareText(post());

    expect(text, contains('instagram.com/reel/ABC123'));
    expect(text, isNot(contains('cdn.example.com')));
    expect(text, isNot(contains('sig=')));
  });

  test('has no line break or extra text around the link', () {
    final text = reelShareText(post());

    expect(text, isNot(contains('\n')));
    expect(Uri.parse(text).hasScheme, isTrue);
  });

  test('trims stray whitespace around the link', () {
    expect(
      reelShareText(post(permalink: '  https://x.id/p \n')),
      'https://x.id/p',
    );
  });

  test('is empty when the post has no link, so nothing is shared', () {
    expect(reelShareText(post(permalink: '')), isEmpty);
    expect(reelShareText(post(permalink: '   ')), isEmpty);
  });
}

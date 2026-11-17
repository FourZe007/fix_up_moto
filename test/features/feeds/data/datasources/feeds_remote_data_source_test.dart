import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/feed_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/features/feeds/data/datasources/feeds_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

Map<String, dynamic> rawPost(String id, {bool withMediaUrl = true}) => {
  'id': id,
  'caption': 'caption $id',
  'mediaType': 'VIDEO',
  if (withMediaUrl) 'mediaUrl': 'https://cdn.example.com/$id.mp4',
  'thumbnailUrl': 'https://cdn.example.com/$id.jpg',
  'permalink': 'https://www.instagram.com/reel/$id/',
  'timestamp': '2026-11-13T10:51:59+0000',
};

void main() {
  late MockDio dio;
  late FeedsRemoteDataSource dataSource;

  /// Answers the feed call with [data] exactly as given, whatever its shape.
  void respondWithRaw(dynamic data) {
    when(() => dio.get<dynamic>(FeedConstants.instagramFeedUrl)).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: FeedConstants.instagramFeedUrl),
        data: data,
      ),
    );
  }

  void respondWith(List<dynamic> posts) => respondWithRaw({'posts': posts});

  setUp(() {
    dio = MockDio();
    dataSource = FeedsRemoteDataSourceImpl(dio);
  });

  test('maps every returned post', () async {
    respondWith([rawPost('a'), rawPost('b')]);

    final feeds = await dataSource.getFeeds();

    expect(feeds.map((f) => f.id), ['a', 'b']);
  });

  test('keeps a post Instagram sent without a mediaUrl, as null', () async {
    // The real feed's newest reel arrived like this and used to crash the
    // whole parse with "type 'Null' is not a subtype of type 'String'".
    respondWith([rawPost('a', withMediaUrl: false), rawPost('b')]);

    final feeds = await dataSource.getFeeds();

    expect(feeds.map((f) => f.id), ['a', 'b']);
    expect(feeds.first.mediaUrl, isNull);
    expect(feeds.first.thumbnailUrl, isNotNull);
    expect(feeds.last.mediaUrl, 'https://cdn.example.com/b.mp4');
  });

  test('skips only a post that is missing a required field, not the whole '
      'feed', () async {
    final broken = rawPost('broken')..remove('permalink');
    respondWith([rawPost('a'), broken, rawPost('c')]);

    final feeds = await dataSource.getFeeds();

    expect(feeds.map((f) => f.id), ['a', 'c']);
  });

  test('a post with no caption is kept, with an empty one', () async {
    final noCaption = rawPost('a')..remove('caption');
    final nullCaption = rawPost('b')..['caption'] = null;
    respondWith([noCaption, nullCaption]);

    final feeds = await dataSource.getFeeds();

    expect(feeds.map((f) => f.id), ['a', 'b']);
    expect(feeds.map((f) => f.caption), ['', '']);
  });

  group('a response that is not the expected { posts: [...] }', () {
    // Each of these used to throw a TypeError that nothing caught, so the Feed
    // tab would have spun forever instead of showing its error and Retry.
    final shapes = <String, dynamic>{
      'an HTML error page': '<html><body>502 Bad Gateway</body></html>',
      'an empty body': null,
      'an object without posts': {'message': 'Failed to load feed'},
      'posts that is not a list': {'posts': 'nope'},
      'a bare list': [<String, dynamic>{}],
    };

    for (final MapEntry(key: name, value: body) in shapes.entries) {
      test('$name becomes a ServerException', () async {
        respondWithRaw(body);

        await expectLater(
          dataSource.getFeeds(),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              'Failed to load feed',
            ),
          ),
        );
      });
    }

    test('an empty posts list is fine, and gives an empty feed', () async {
      respondWith([]);

      expect(await dataSource.getFeeds(), isEmpty);
    });
  });
}

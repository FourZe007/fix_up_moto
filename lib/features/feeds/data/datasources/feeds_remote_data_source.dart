import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/feed_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/features/feeds/data/models/feed_model.dart';

abstract class FeedsRemoteDataSource {
  Future<List<FeedModel>> getFeeds();
}

class FeedsRemoteDataSourceImpl implements FeedsRemoteDataSource {
  final Dio _dio;
  FeedsRemoteDataSourceImpl(this._dio);

  @override
  Future<List<FeedModel>> getFeeds() async {
    try {
      // Absolute URL — bypasses DioClient's SAMP baseUrl, since this hits an
      // entirely separate backend (see FeedConstants).
      final response = await _dio.get(FeedConstants.instagramFeedUrl);
      // Check the envelope before trusting it. A proxy that answers with an
      // error page or without `posts` would otherwise throw a TypeError, which
      // is not a DioException and would escape every catch, leaving the page
      // spinning forever. As a ServerException it reaches the user as the
      // normal error message with a Retry button.
      final data = response.data;
      final posts = data is Map ? data['posts'] : null;
      if (posts is! List) {
        throw const ServerException(message: 'Failed to load feed');
      }

      final models = <FeedModel>[];
      for (final post in posts) {
        try {
          models.add(FeedModel.fromJson(post as Map<String, dynamic>));
        } on TypeError {
          // One post missing a required field must not blank the whole feed
          // (a TypeError is not a DioException, so it would otherwise escape
          // every catch and leave the page spinning forever). Skip just that
          // post and keep the rest.
          continue;
        }
      }
      return models;
    } on DioException catch (e) {
      throw ServerException(
        message: e.response?.data is Map
            ? (e.response?.data['message'] as String? ?? 'Failed to load feed')
            : 'Failed to load feed',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

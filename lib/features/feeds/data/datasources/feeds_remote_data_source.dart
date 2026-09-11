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
      final posts = response.data['posts'] as List;
      return posts
          .map((post) => FeedModel.fromJson(post as Map<String, dynamic>))
          .toList();
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

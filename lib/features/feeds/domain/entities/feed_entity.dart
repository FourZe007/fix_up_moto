import 'package:equatable/equatable.dart';

/// A single Instagram post, fetched via the feed proxy.
class FeedEntity extends Equatable {
  final String id;
  final String caption;

  /// e.g. "VIDEO", "IMAGE", "CAROUSEL_ALBUM".
  final String mediaType;

  /// Direct URL to the video/image file.
  final String mediaUrl;

  /// Only present for VIDEO/CAROUSEL_ALBUM items.
  final String? thumbnailUrl;

  /// Link to the original post on instagram.com.
  final String permalink;

  final String timestamp;

  const FeedEntity({
    required this.id,
    required this.caption,
    required this.mediaType,
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.permalink,
    required this.timestamp,
  });

  bool get isVideo => mediaType == 'VIDEO';

  @override
  List<Object?> get props => [
        id, caption, mediaType, mediaUrl, thumbnailUrl, permalink, timestamp,
      ];
}

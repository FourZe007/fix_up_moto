import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/features/feeds/domain/entities/feed_entity.dart';

part 'feed_model.g.dart';

/// JSON model for a single post returned by the feed proxy's
/// `{ "posts": [...] }` response. Keys already match the proxy's own
/// camelCase reshaping of Meta's response, so no [JsonKey] renames are needed.
@JsonSerializable()
class FeedModel {
  final String id;

  /// Instagram leaves the caption out of a post that has none. The proxy
  /// already fills in '', but the app does not rely on that: a missing or null
  /// caption becomes '' here instead of failing the whole post.
  @JsonKey(defaultValue: '')
  final String caption;
  final String mediaType;
  final String? mediaUrl; // Instagram omits it for some posts
  final String? thumbnailUrl;
  final String permalink;
  final String timestamp;

  const FeedModel({
    required this.id,
    required this.caption,
    required this.mediaType,
    this.mediaUrl,
    this.thumbnailUrl,
    required this.permalink,
    required this.timestamp,
  });

  factory FeedModel.fromJson(Map<String, dynamic> json) =>
      _$FeedModelFromJson(json);

  Map<String, dynamic> toJson() => _$FeedModelToJson(this);

  FeedEntity toEntity() => FeedEntity(
    id: id,
    caption: caption,
    mediaType: mediaType,
    mediaUrl: mediaUrl,
    thumbnailUrl: thumbnailUrl,
    permalink: permalink,
    timestamp: timestamp,
  );
}

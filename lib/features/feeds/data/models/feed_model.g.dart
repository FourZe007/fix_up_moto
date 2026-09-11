// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FeedModel _$FeedModelFromJson(Map<String, dynamic> json) => FeedModel(
  id: json['id'] as String,
  caption: json['caption'] as String,
  mediaType: json['mediaType'] as String,
  mediaUrl: json['mediaUrl'] as String,
  thumbnailUrl: json['thumbnailUrl'] as String?,
  permalink: json['permalink'] as String,
  timestamp: json['timestamp'] as String,
);

Map<String, dynamic> _$FeedModelToJson(FeedModel instance) => <String, dynamic>{
  'id': instance.id,
  'caption': instance.caption,
  'mediaType': instance.mediaType,
  'mediaUrl': instance.mediaUrl,
  'thumbnailUrl': instance.thumbnailUrl,
  'permalink': instance.permalink,
  'timestamp': instance.timestamp,
};

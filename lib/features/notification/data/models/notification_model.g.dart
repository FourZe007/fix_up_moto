// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationModel _$NotificationModelFromJson(Map<String, dynamic> json) =>
    NotificationModel(
      memberId: json['MemberID'] as String? ?? '',
      notificationId: json['NotificationID'] as String? ?? '',
      notificationType: json['NotificationType'] as String? ?? '',
      notification: json['Notification'] as String? ?? '',
      sysDate: json['SysDate'] as String? ?? '',
      isSent: _flagFromJson(json['IsSent']),
      isRead: _flagFromJson(json['IsRead']),
      numberOfNotifications: _intFromJson(json['Q']),
      image: json['Base64Image'] as String? ?? '',
      link: json['UrlLink'] as String? ?? '',
    );

Map<String, dynamic> _$NotificationModelToJson(NotificationModel instance) =>
    <String, dynamic>{
      'MemberID': instance.memberId,
      'NotificationID': instance.notificationId,
      'NotificationType': instance.notificationType,
      'Notification': instance.notification,
      'SysDate': instance.sysDate,
      'IsSent': instance.isSent,
      'IsRead': instance.isRead,
      'Q': instance.numberOfNotifications,
      'Base64Image': instance.image,
      'UrlLink': instance.link,
    };

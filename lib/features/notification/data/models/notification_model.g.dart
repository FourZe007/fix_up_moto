// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationModel _$NotificationModelFromJson(Map<String, dynamic> json) =>
    NotificationModel(
      notificationId: json['NotificationID'] as String? ?? '',
      notificationType: json['NotificationType'] as String? ?? '',
      notification: json['Notification'] as String? ?? '',
      sysDate: json['SysDate'] as String? ?? '',
      isSent: _flagFromJson(json['IsSent']),
      isRead: _flagFromJson(json['IsRead']),
    );

Map<String, dynamic> _$NotificationModelToJson(NotificationModel instance) =>
    <String, dynamic>{
      'NotificationID': instance.notificationId,
      'NotificationType': instance.notificationType,
      'Notification': instance.notification,
      'SysDate': instance.sysDate,
      'IsSent': instance.isSent,
      'IsRead': instance.isRead,
    };

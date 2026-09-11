import 'package:equatable/equatable.dart';

/// A single service transaction/history record for a motorcycle.
class ServiceEntity extends Equatable {
  /// Branch/workshop name where the service was performed.
  final String bsName;

  /// Transaction number — the natural unique identifier for this record.
  final String transNo;

  final String transDate;

  /// Mechanic/employee name who performed the service.
  final String eName;

  final double amountService;
  final double amountPart;

  /// Service line items performed in this transaction.
  final List<ServiceLineDetailEntity> detail;

  /// Parts/units used in this transaction.
  final List<ServicePartDetailEntity> detail2;

  const ServiceEntity({
    required this.bsName,
    required this.transNo,
    required this.transDate,
    required this.eName,
    required this.amountService,
    required this.amountPart,
    required this.detail,
    required this.detail2,
  });

  @override
  List<Object?> get props => [
        bsName, transNo, transDate, eName,
        amountService, amountPart, detail, detail2,
      ];
}

/// A single performed service line item.
class ServiceLineDetailEntity extends Equatable {
  final String serviceId;
  final String serviceName;
  final String serviceNote;

  const ServiceLineDetailEntity({
    required this.serviceId,
    required this.serviceName,
    required this.serviceNote,
  });

  @override
  List<Object?> get props => [serviceId, serviceName, serviceNote];
}

/// A single part/unit used in the service.
class ServicePartDetailEntity extends Equatable {
  final String unitId;
  final String itemName;
  final int qty;

  const ServicePartDetailEntity({
    required this.unitId,
    required this.itemName,
    required this.qty,
  });

  @override
  List<Object?> get props => [unitId, itemName, qty];
}

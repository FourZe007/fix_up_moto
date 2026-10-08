import 'package:equatable/equatable.dart';

/// A reward the member can get in exchange for points (`Master`,
/// `Jenis: "POINTID"`).
///
/// This is the catalogue of what is on offer, not a voucher the member already
/// owns — those are [VoucherDetailEntity] in the dashboard stats.
class RewardEntity extends Equatable {
  /// Reward identifier, e.g. "C01".
  final String pointId;

  /// Human-readable reward name, e.g. "DISKON JASA SERVICE Rp. 20.000,00".
  final String pointName;

  /// How many points the reward costs.
  final int pointQty;

  const RewardEntity({
    required this.pointId,
    required this.pointName,
    required this.pointQty,
  });

  @override
  List<Object> get props => [pointId, pointName, pointQty];
}

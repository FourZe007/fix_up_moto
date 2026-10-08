import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/network/result_message_model.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/membership/data/models/reward_model.dart';

abstract class RewardsRemoteDataSource {
  Future<List<RewardModel>> getRewards();

  /// Spends the member's points on the voucher [pointId] (a `RewardModel.pointId`).
  Future<ResultMessageModel> redeemReward({
    required String memberId,
    required String pointId,
  });
}

class RewardsRemoteDataSourceImpl implements RewardsRemoteDataSource {
  final Dio _dio;
  RewardsRemoteDataSourceImpl(this._dio);

  @override
  Future<List<RewardModel>> getRewards() async {
    try {
      final response = await _dio.post(
        ApiConstants.master,
        data: {'Jenis': 'POINTID'},
      );
      return SampEnvelope.rows(response).map(RewardModel.fromJson).toList();
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  @override
  Future<ResultMessageModel> redeemReward({
    required String memberId,
    required String pointId,
  }) async {
    try {
      // A write, so it goes to Modify (like registering a bike), not Master.
      final response = await _dio.post(
        ApiConstants.modify,
        data: {
          'Mode': ModifyMode.create.wireValue,
          'TransID': 'REDEEMPOINT',
          'Data': {'MemberID': memberId, 'PointID': pointId},
        },
      );

      return ResultMessageModel.fromJson(SampEnvelope.first(response));
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }
}

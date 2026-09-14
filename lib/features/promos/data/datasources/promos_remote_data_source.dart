import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/promos/data/models/promo_image_model.dart';

abstract class PromosRemoteDataSource {
  Future<List<PromoImageModel>> getPromoImages();
}

class PromosRemoteDataSourceImpl implements PromosRemoteDataSource {
  final Dio _dio;
  PromosRemoteDataSourceImpl(this._dio);

  @override
  Future<List<PromoImageModel>> getPromoImages() async {
    try {
      final response = await _dio.post(
        ApiConstants.promoImages,
        data: {'Jenis': 'IMAGEFORAPPS'},
      );
      return SampEnvelope.rows(response).map(PromoImageModel.fromJson).toList();
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }
}

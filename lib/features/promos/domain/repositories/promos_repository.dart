import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/promos/domain/entities/promo_image_entity.dart';

abstract class PromosRepository {
  Future<Either<Failure, List<PromoImageEntity>>> getPromoImages();
}

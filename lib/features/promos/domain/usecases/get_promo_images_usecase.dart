import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/promos/domain/entities/promo_image_entity.dart';
import 'package:fix_up_moto/features/promos/domain/repositories/promos_repository.dart';

class GetPromoImagesUseCase extends NoParamsUseCase<List<PromoImageEntity>> {
  final PromosRepository repository;
  GetPromoImagesUseCase(this.repository);

  @override
  Future<Either<Failure, List<PromoImageEntity>>> call() {
    return repository.getPromoImages();
  }
}

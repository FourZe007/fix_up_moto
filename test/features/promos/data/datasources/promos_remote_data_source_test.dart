import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/features/promos/data/datasources/promos_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late PromosRemoteDataSource dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = PromosRemoteDataSourceImpl(dio);
  });

  test('requests IMAGEFORAPPS and maps every returned banner', () async {
    when(
      () => dio.post<dynamic>(
        ApiConstants.promoImages,
        data: any<dynamic>(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: ApiConstants.promoImages),
        data: {
          'Msg': 'Sukses',
          'Code': '100',
          'Data': [
            {'Line': 1, 'Base64Image': 'AQID'},
            {'Line': 2, 'Base64Image': 'BAUG'},
          ],
        },
      ),
    );

    final images = await dataSource.getPromoImages();

    expect(images, hasLength(2));
    expect(images[0].line, 1);
    expect(images[0].toEntity().imageBytes, orderedEquals([1, 2, 3]));
    expect(images[1].line, 2);
    expect(images[1].toEntity().imageBytes, orderedEquals([4, 5, 6]));
    verify(
      () => dio.post<dynamic>(
        ApiConstants.promoImages,
        data: {'Jenis': 'IMAGEFORAPPS'},
      ),
    ).called(1);
  });
}

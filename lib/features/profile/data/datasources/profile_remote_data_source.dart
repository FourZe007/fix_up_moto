import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/features/auth/data/models/user_model.dart';
import 'package:fix_up_moto/features/profile/data/models/motorcycle_model.dart';

abstract class ProfileRemoteDataSource {
  Future<UserModel> getProfile();
  Future<UserModel> updateProfile({required String name, String? phone});
  Future<List<MotorcycleModel>> getMotorcycles(
    String memberId,
    String memberName,
    String plateNo,
    String phoneNo,
    String status, {
    String type = 'membership',
  });
  Future<MotorcycleModel> addMotorcycle({
    required String brand,
    required String model,
    required int year,
    required String plateNumber,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio _dio;
  ProfileRemoteDataSourceImpl(this._dio);

  @override
  Future<UserModel> getProfile() async {
    try {
      final response = await _dio.get(ApiConstants.profile);
      return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(
        message: e.response?.data?['message'] as String? ?? 'Server error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<UserModel> updateProfile({required String name, String? phone}) async {
    try {
      // Build request body imperatively so optional `phone` can be omitted
      // cleanly without null-aware map literal syntax.
      final body = <String, dynamic>{'name': name};
      if (phone != null) body['phone'] = phone;

      final response = await _dio.patch(ApiConstants.profile, data: body);
      return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(
        message: e.response?.data?['message'] as String? ?? 'Server error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<List<MotorcycleModel>> getMotorcycles(
    String memberId,
    String memberName,
    String plateNo,
    String phoneNo,
    String status, {
    String type = 'membership',
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.motorcycles,
        data: {
          'Jenis': type.toUpperCase(),
          'MemberID': memberId,
          'MemberName': memberName,
          'PlateNo': plateNo,
          'PhoneNo': phoneNo,
          'Status': status,
        },
      );

      final list = response.data['data'] as List<dynamic>;
      return list
          .map((e) => MotorcycleModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
        message: e.response?.data?['message'] as String? ?? 'Server error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<MotorcycleModel> addMotorcycle({
    required String brand,
    required String model,
    required int year,
    required String plateNumber,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.motorcycles,
        data: {
          'brand': brand,
          'model': model,
          'year': year,
          'plate_number': plateNumber,
        },
      );
      return MotorcycleModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ServerException(
        message: e.response?.data?['message'] as String? ?? 'Server error',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

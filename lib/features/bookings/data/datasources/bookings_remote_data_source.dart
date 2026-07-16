import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/features/bookings/data/models/booking_model.dart';

abstract class BookingsRemoteDataSource {
  Future<List<BookingModel>> getBookings();
  Future<BookingModel> createBooking({
    required String serviceId,
    required DateTime scheduledAt,
    String? notes,
  });
  Future<void> cancelBooking(String id);
}

class BookingsRemoteDataSourceImpl implements BookingsRemoteDataSource {
  final Dio _dio;
  BookingsRemoteDataSourceImpl(this._dio);

  @override
  Future<List<BookingModel>> getBookings() async {
    try {
      final response = await _dio.get(ApiConstants.bookings);
      final list = response.data['data'] as List<dynamic>;
      return list.map((e) => BookingModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ServerException(
        message: e.response?.data?['message'] as String? ?? 'Server error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<BookingModel> createBooking({
    required String serviceId,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    try {
      // Build the request body as a mutable map so optional fields can be
      // added imperatively — avoids null-aware map literal syntax issues.
      final body = <String, dynamic>{
        'service_id': serviceId,
        // Send as ISO-8601 UTC string — server stores in UTC
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      };
      if (notes != null) body['notes'] = notes;

      final response = await _dio.post(
        ApiConstants.bookings,
        data: body,
      );
      return BookingModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ServerException(
        message: e.response?.data?['message'] as String? ?? 'Server error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<void> cancelBooking(String id) async {
    try {
      await _dio.delete('${ApiConstants.cancelBooking}/$id');
    } on DioException catch (e) {
      throw ServerException(
        message: e.response?.data?['message'] as String? ?? 'Server error',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

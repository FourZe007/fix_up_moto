import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/bookings/data/models/booking_model.dart';

abstract class BookingsRemoteDataSource {
  Future<List<BookingModel>> getBookings(String memberId);
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
  Future<List<BookingModel>> getBookings(String memberId) async {
    try {
      final response = await _dio.post(
        ApiConstants.browseTrans,
        data: {
          'Jenis': 'SERVICEBOOKINGHISTORYBYMEMBER',
          'MemberID': memberId,
          'BeginDate': '',
          'EndDate': '',
        },
      );
      return SampEnvelope.rows(response).map(BookingModel.fromJson).toList();
    } on DioException catch (e) {
      SampEnvelope.error(e);
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
        'ServiceID': serviceId,
        // Send as ISO-8601 UTC string — server stores in UTC
        'ScheduledAt': scheduledAt.toUtc().toIso8601String(),
      };
      if (notes != null) body['Notes'] = notes;

      // Creating is a separate endpoint from browsing under the SAMP
      // convention — both are POST, so the path is what distinguishes them.
      final response = await _dio.post(ApiConstants.createBooking, data: body);
      return BookingModel.fromJson(SampEnvelope.first(response));
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  @override
  Future<void> cancelBooking(String id) async {
    try {
      await _dio.post(ApiConstants.cancelBooking, data: {'BookingID': id});
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }
}

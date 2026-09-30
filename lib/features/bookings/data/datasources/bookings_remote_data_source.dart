import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/bookings/data/models/booking_model.dart';

abstract class BookingsRemoteDataSource {
  Future<List<BookingModel>> getBookings(String memberId);
  Future<BookingModel> createBooking({
    required String serviceId,
    required DateTime scheduledAt,
    required String branch,
    required String shop,
    required String plateNo,
    required String unitId,
    required String uName,
    required String uPhoneNo,
    String? notes,
    required String memberId,
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
    required String branch,
    required String shop,
    required String plateNo,
    required String unitId,
    required String uName,
    required String uPhoneNo,
    String? notes,
    required String memberId,
  }) async {
    try {
      // Build the nested Data map as a mutable map so Notes can be set
      // imperatively below — was previously set as a top-level 'Notes' key
      // on body instead of inside Data, so the real value never actually
      // reached the request.
      final data = <String, dynamic>{
        'BookDate': DateTimeFormatter.fromUtcToDate(scheduledAt),
        'BookTime': DateTimeFormatter.fromUtcToTime(scheduledAt),
        'Branch': branch,
        'Shop': shop,
        'UName': uName,
        'UPhoneNo': uPhoneNo,
        'UPlateNo': plateNo,
        'UnitID': unitId,
        'Notes': notes ?? '',
        'MemberID': memberId,
      };

      final body = <String, dynamic>{
        'Mode': '1',
        'TransID': 'RSV',
        'Data': data,
      };

      // Creating is a separate endpoint from browsing under the SAMP
      // convention — both are POST, so the path is what distinguishes them.
      final response = await _dio.post(ApiConstants.modify, data: body);
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

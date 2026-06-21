import 'package:dio/dio.dart';

String apiErrorMessage(
  Object error, {
  String fallback = 'Something went wrong',
}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Network timeout. Please try again.';
    }
    if (error.response == null) {
      return 'Could not reach the server. Check your connection.';
    }
  }
  return fallback;
}

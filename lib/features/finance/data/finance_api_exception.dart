import 'package:dio/dio.dart';

class FinanceApiException implements Exception {
  const FinanceApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<T> mapFinanceApiErrors<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (error) {
    throw FinanceApiException(_messageFor(error));
  }
}

String _messageFor(DioException error) {
  final details = '${error.message ?? ''} ${error.error ?? ''}';
  if (details.toLowerCase().contains('handshake')) {
    return 'Cannot complete the secure connection to the Momentum API. If you are using ngrok, pass the full https ngrok forwarding URL as API_BASE_URL. If you are connecting directly to local Docker, use http://localhost:8080 for simulator/web or http://<Mac-IP>:8080 for a physical phone.';
  }

  if (error.type == DioExceptionType.connectionError) {
    return 'Cannot reach the Momentum API. Make sure the backend is running and API_BASE_URL points to the full backend URL. Use https for ngrok, and http for direct local Docker.';
  }

  if (error.response != null) {
    return 'Momentum API returned ${error.response!.statusCode}: ${error.response!.data}';
  }

  return 'Momentum API request failed. ${error.message ?? ''}'.trim();
}

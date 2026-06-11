import 'package:http/http.dart' as http;

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? 'http://localhost:8080';

  final http.Client _client;
  final String _baseUrl;

  Future<String> checkHealth() async {
    final uri = Uri.parse('$_baseUrl/health');
    final response = await _client.get(uri);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body;
    }

    throw Exception('Backend returned ${response.statusCode}');
  }
}

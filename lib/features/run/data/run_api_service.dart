import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../models/create_run_request.dart';
import '../models/run_response.dart';

class RunApiService {
  RunApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? AppConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<RunResponse> createRun(CreateRunRequest request) async {
    final uri = Uri.parse('$_baseUrl/api/runs');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return RunResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw Exception(_buildErrorMessage(response));
  }

  Future<List<RunResponse>> getRuns() async {
    final uri = Uri.parse('$_baseUrl/api/runs');
    final response = await _client.get(uri);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final runsJson = jsonDecode(response.body) as List<dynamic>;
      return runsJson
          .map((run) => RunResponse.fromJson(run as Map<String, dynamic>))
          .toList();
    }

    throw Exception(_buildErrorMessage(response, action: 'Load runs'));
  }

  Future<RunResponse> getRunById(int id) async {
    final uri = Uri.parse('$_baseUrl/api/runs/$id');
    final response = await _client.get(uri);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return RunResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw Exception(_buildErrorMessage(response, action: 'Load run'));
  }

  Future<void> deleteRun(int id) async {
    final uri = Uri.parse('$_baseUrl/api/runs/$id');
    final response = await _client.delete(uri);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception(_buildErrorMessage(response, action: 'Delete run'));
  }

  String _buildErrorMessage(
    http.Response response, {
    String action = 'Run save',
  }) {
    if (response.body.trim().isEmpty) {
      return '$action failed with status ${response.statusCode}.';
    }

    return '$action failed with status ${response.statusCode}: ${response.body}';
  }
}

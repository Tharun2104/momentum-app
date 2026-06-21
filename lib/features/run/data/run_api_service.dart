import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/token_storage.dart';
import '../models/create_run_request.dart';
import '../models/run_response.dart';

class RunApiService {
  RunApiService({
    http.Client? client,
    String? baseUrl,
    TokenStorage? tokenStorage,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? AppConfig.baseUrl,
       _tokenStorage = tokenStorage ?? TokenStorage();

  final http.Client _client;
  final String _baseUrl;
  final TokenStorage _tokenStorage;

  Future<RunResponse> createRun(CreateRunRequest request) async {
    final uri = Uri.parse('$_baseUrl/api/runs');
    final response = await _client.post(
      uri,
      headers: await _headers(),
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
    final response = await _client.get(uri, headers: await _headers());

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
    final response = await _client.get(uri, headers: await _headers());

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return RunResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw Exception(_buildErrorMessage(response, action: 'Load run'));
  }

  Future<void> deleteRun(int id) async {
    final uri = Uri.parse('$_baseUrl/api/runs/$id');
    final response = await _client.delete(uri, headers: await _headers());

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception(_buildErrorMessage(response, action: 'Delete run'));
  }

  Future<Map<String, String>> _headers() async {
    final token = await _tokenStorage.readToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
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

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:momentum_app/features/auth/data/token_storage.dart';
import 'package:momentum_app/features/run/data/run_api_service.dart';

void main() {
  test('getRuns attaches saved bearer token', () async {
    final service = RunApiService(
      baseUrl: 'http://example.com',
      tokenStorage: _FakeTokenStorage('saved-token'),
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer saved-token');
        return http.Response('[]', 200);
      }),
    );

    final runs = await service.getRuns();

    expect(runs, isEmpty);
  });
}

class _FakeTokenStorage extends TokenStorage {
  _FakeTokenStorage(this._token);

  final String? _token;

  @override
  Future<String?> readToken() async => _token;
}

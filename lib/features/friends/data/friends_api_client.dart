import 'package:dio/dio.dart';

import '../domain/friend_request.dart';
import '../domain/friend_user.dart';

class FriendsApiClient {
  FriendsApiClient(this._dio);

  final Dio _dio;

  Future<FriendUser> searchUser(String email) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/users/search',
      queryParameters: {'email': email},
    );
    return FriendUser.fromJson(response.data!);
  }

  Future<FriendRequest> sendRequest(int receiverUserId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/friends/request',
      data: {'receiverUserId': receiverUserId},
    );
    return FriendRequest.fromJson(response.data!);
  }

  Future<List<FriendRequest>> getIncomingRequests() async {
    final response = await _dio.get<List<dynamic>>(
      '/api/friends/requests/incoming',
    );
    return response.data!
        .map((json) => FriendRequest.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendRequest>> getOutgoingRequests() async {
    final response = await _dio.get<List<dynamic>>(
      '/api/friends/requests/outgoing',
    );
    return response.data!
        .map((json) => FriendRequest.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<FriendRequest> acceptRequest(int requestId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/friends/requests/$requestId/accept',
    );
    return FriendRequest.fromJson(response.data!);
  }

  Future<FriendRequest> rejectRequest(int requestId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/friends/requests/$requestId/reject',
    );
    return FriendRequest.fromJson(response.data!);
  }

  Future<List<FriendUser>> getFriends() async {
    final response = await _dio.get<List<dynamic>>('/api/friends');
    return response.data!
        .map((json) => FriendUser.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

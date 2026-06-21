import '../domain/friend_request.dart';
import '../domain/friend_user.dart';
import 'friends_api_client.dart';

abstract class FriendsRepository {
  Future<FriendUser> searchUser(String email);
  Future<FriendRequest> sendRequest(int receiverUserId);
  Future<List<FriendRequest>> getIncomingRequests();
  Future<List<FriendRequest>> getOutgoingRequests();
  Future<FriendRequest> acceptRequest(int requestId);
  Future<FriendRequest> rejectRequest(int requestId);
  Future<List<FriendUser>> getFriends();
}

class DioFriendsRepository implements FriendsRepository {
  DioFriendsRepository(this._client);

  final FriendsApiClient _client;

  @override
  Future<FriendUser> searchUser(String email) => _client.searchUser(email);

  @override
  Future<FriendRequest> sendRequest(int receiverUserId) =>
      _client.sendRequest(receiverUserId);

  @override
  Future<List<FriendRequest>> getIncomingRequests() =>
      _client.getIncomingRequests();

  @override
  Future<List<FriendRequest>> getOutgoingRequests() =>
      _client.getOutgoingRequests();

  @override
  Future<FriendRequest> acceptRequest(int requestId) =>
      _client.acceptRequest(requestId);

  @override
  Future<FriendRequest> rejectRequest(int requestId) =>
      _client.rejectRequest(requestId);

  @override
  Future<List<FriendUser>> getFriends() => _client.getFriends();
}

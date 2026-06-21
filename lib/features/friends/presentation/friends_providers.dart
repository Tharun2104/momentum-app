import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../data/friends_api_client.dart';
import '../data/friends_repository.dart';
import '../domain/friend_request.dart';
import '../domain/friend_user.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return DioFriendsRepository(FriendsApiClient(ref.watch(dioProvider)));
});

final friendsProvider = FutureProvider<List<FriendUser>>((ref) {
  return ref.watch(friendsRepositoryProvider).getFriends();
});

final incomingFriendRequestsProvider = FutureProvider<List<FriendRequest>>((
  ref,
) {
  return ref.watch(friendsRepositoryProvider).getIncomingRequests();
});

final outgoingFriendRequestsProvider = FutureProvider<List<FriendRequest>>((
  ref,
) {
  return ref.watch(friendsRepositoryProvider).getOutgoingRequests();
});

void refreshFriends(WidgetRef ref) {
  ref.invalidate(friendsProvider);
  ref.invalidate(incomingFriendRequestsProvider);
  ref.invalidate(outgoingFriendRequestsProvider);
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:momentum_app/features/friends/data/friends_repository.dart';
import 'package:momentum_app/features/friends/domain/friend_request.dart';
import 'package:momentum_app/features/friends/domain/friend_user.dart';
import 'package:momentum_app/features/friends/presentation/friends_providers.dart';
import 'package:momentum_app/features/friends/presentation/friends_screen.dart';
import 'package:momentum_app/features/friends/presentation/incoming_requests_screen.dart';
import 'package:momentum_app/features/friends/presentation/search_user_screen.dart';

void main() {
  testWidgets('friends screen shows empty state', (tester) async {
    await tester.pumpWidget(
      _testApp(
        repository: _FakeFriendsRepository(),
        child: const FriendsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No friends yet'), findsOneWidget);
    expect(find.text('Search users'), findsOneWidget);
  });

  testWidgets('search screen finds a user and sends request', (tester) async {
    final repository = _FakeFriendsRepository(searchResult: _userTwo);

    await tester.pumpWidget(
      _testApp(repository: repository, child: const SearchUserScreen()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'user2@example.com');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('User Two'), findsOneWidget);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(repository.sentRequestUserIds, [2]);
    expect(find.text('Friend request sent to User Two.'), findsWidgets);
  });

  testWidgets('incoming requests screen accepts and rejects requests', (
    tester,
  ) async {
    final repository = _FakeFriendsRepository(
      incomingRequests: [_request(id: 10), _request(id: 11)],
    );

    await tester.pumpWidget(
      _testApp(repository: repository, child: const IncomingRequestsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('User One'), findsNWidgets(2));

    await tester.tap(find.text('Accept').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject').first);
    await tester.pumpAndSettle();

    expect(repository.acceptedRequestIds, [10]);
    expect(repository.rejectedRequestIds, [11]);
  });

  testWidgets('friends screen can remove an existing friend', (tester) async {
    final repository = _FakeFriendsRepository(friends: [_userTwo]);

    await tester.pumpWidget(
      _testApp(repository: repository, child: const FriendsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove friend'));
    await tester.pumpAndSettle();

    expect(repository.deletedFriendUserIds, [2]);
  });
}

Widget _testApp({
  required FriendsRepository repository,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [friendsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(home: child),
  );
}

class _FakeFriendsRepository implements FriendsRepository {
  _FakeFriendsRepository({
    this.searchResult,
    List<FriendUser>? friends,
    List<FriendRequest>? incomingRequests,
  }) : friends = friends ?? [],
       incomingRequests = incomingRequests ?? [];

  final FriendUser? searchResult;
  final List<FriendUser> friends;
  final List<FriendRequest> incomingRequests;
  final List<int> sentRequestUserIds = [];
  final List<int> acceptedRequestIds = [];
  final List<int> rejectedRequestIds = [];
  final List<int> deletedFriendUserIds = [];

  @override
  Future<FriendRequest> acceptRequest(int requestId) async {
    acceptedRequestIds.add(requestId);
    incomingRequests.removeWhere((request) => request.id == requestId);
    return _request(id: requestId, status: FriendRequestStatus.accepted);
  }

  @override
  Future<List<FriendUser>> getFriends() async => friends;

  @override
  Future<void> deleteFriend(int friendUserId) async {
    deletedFriendUserIds.add(friendUserId);
    friends.removeWhere((friend) => friend.id == friendUserId);
  }

  @override
  Future<List<FriendRequest>> getIncomingRequests() async => incomingRequests;

  @override
  Future<List<FriendRequest>> getOutgoingRequests() async => [];

  @override
  Future<FriendRequest> rejectRequest(int requestId) async {
    rejectedRequestIds.add(requestId);
    incomingRequests.removeWhere((request) => request.id == requestId);
    return _request(id: requestId, status: FriendRequestStatus.rejected);
  }

  @override
  Future<FriendRequest> sendRequest(int receiverUserId) async {
    sentRequestUserIds.add(receiverUserId);
    return _request(receiver: _userTwo);
  }

  @override
  Future<FriendUser> searchUser(String email) async {
    final result = searchResult;
    if (result == null) {
      throw Exception('Not found');
    }
    return result;
  }
}

const _userOne = FriendUser(
  id: 1,
  name: 'User One',
  email: 'user1@example.com',
);

const _userTwo = FriendUser(
  id: 2,
  name: 'User Two',
  email: 'user2@example.com',
);

FriendRequest _request({
  int id = 1,
  FriendUser sender = _userOne,
  FriendUser receiver = _userTwo,
  FriendRequestStatus status = FriendRequestStatus.pending,
}) {
  final now = DateTime.parse('2026-06-21T12:00:00Z');
  return FriendRequest(
    id: id,
    sender: sender,
    receiver: receiver,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

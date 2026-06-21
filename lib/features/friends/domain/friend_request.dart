import 'friend_user.dart';

enum FriendRequestStatus { pending, accepted, rejected }

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final FriendUser sender;
  final FriendUser receiver;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as int,
      sender: FriendUser.fromJson(json['sender'] as Map<String, dynamic>),
      receiver: FriendUser.fromJson(json['receiver'] as Map<String, dynamic>),
      status: _statusFromJson(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static FriendRequestStatus _statusFromJson(String value) {
    return switch (value) {
      'PENDING' => FriendRequestStatus.pending,
      'ACCEPTED' => FriendRequestStatus.accepted,
      'REJECTED' => FriendRequestStatus.rejected,
      _ => throw ArgumentError('Unknown friend request status: $value'),
    };
  }
}

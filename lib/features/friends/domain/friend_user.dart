class FriendUser {
  const FriendUser({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }
}

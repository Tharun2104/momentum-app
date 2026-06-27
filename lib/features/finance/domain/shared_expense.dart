import 'expense_category.dart';

class SharedExpense {
  const SharedExpense({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.category,
    required this.expenseDate,
    required this.paidByUserId,
    required this.paidByName,
    required this.friendUserId,
    required this.friendName,
    required this.currentUserShareAmount,
    required this.currentUserPaidAmount,
    required this.currentUserNetAmount,
    required this.otherUserName,
    required this.displayText,
    this.participants = const [],
    this.originalExpenseId,
  });

  final int id;
  final String title;
  final double totalAmount;
  final ExpenseCategory category;
  final DateTime expenseDate;
  final int paidByUserId;
  final String paidByName;
  final int friendUserId;
  final String friendName;
  final double currentUserShareAmount;
  final double currentUserPaidAmount;
  final double currentUserNetAmount;
  final String otherUserName;
  final String displayText;
  final List<SharedExpenseParticipant> participants;
  final int? originalExpenseId;

  factory SharedExpense.fromJson(Map<String, dynamic> json) {
    return SharedExpense(
      id: json['id'] as int,
      title: json['title'] as String,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      category: ExpenseCategory.fromApi(json['category'] as String),
      expenseDate: DateTime.parse(json['expenseDate'] as String),
      paidByUserId: json['paidByUserId'] as int,
      paidByName: json['paidByName'] as String,
      friendUserId: json['friendUserId'] as int,
      friendName: json['friendName'] as String,
      currentUserShareAmount: (json['currentUserShareAmount'] as num)
          .toDouble(),
      currentUserPaidAmount: (json['currentUserPaidAmount'] as num).toDouble(),
      currentUserNetAmount: (json['currentUserNetAmount'] as num).toDouble(),
      otherUserName: json['otherUserName'] as String,
      displayText: json['displayText'] as String,
      participants: (json['participants'] as List<dynamic>? ?? [])
          .map(
            (participant) => SharedExpenseParticipant.fromJson(
              participant as Map<String, dynamic>,
            ),
          )
          .toList(),
      originalExpenseId: json['originalExpenseId'] as int?,
    );
  }
}

class SharedExpenseParticipant {
  const SharedExpenseParticipant({
    required this.id,
    required this.user,
    required this.shareAmount,
    required this.paidAmount,
    required this.netAmount,
  });

  final int id;
  final SharedExpenseUser user;
  final double shareAmount;
  final double paidAmount;
  final double netAmount;

  factory SharedExpenseParticipant.fromJson(Map<String, dynamic> json) {
    return SharedExpenseParticipant(
      id: json['id'] as int,
      user: SharedExpenseUser.fromJson(json['user'] as Map<String, dynamic>),
      shareAmount: (json['shareAmount'] as num).toDouble(),
      paidAmount: (json['paidAmount'] as num).toDouble(),
      netAmount: (json['netAmount'] as num).toDouble(),
    );
  }
}

class SharedExpenseUser {
  const SharedExpenseUser({
    required this.id,
    required this.name,
    required this.email,
  });

  final int id;
  final String name;
  final String email;

  factory SharedExpenseUser.fromJson(Map<String, dynamic> json) {
    return SharedExpenseUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }
}

class SplitsSummary {
  const SplitsSummary({
    required this.netBalance,
    required this.totalOwedToYou,
    required this.totalYouOwe,
  });

  final double netBalance;
  final double totalOwedToYou;
  final double totalYouOwe;

  factory SplitsSummary.fromJson(Map<String, dynamic> json) {
    return SplitsSummary(
      netBalance: (json['netBalance'] as num).toDouble(),
      totalOwedToYou: (json['totalOwedToYou'] as num).toDouble(),
      totalYouOwe: (json['totalYouOwe'] as num).toDouble(),
    );
  }
}

class FriendBalance {
  const FriendBalance({
    required this.friendUserId,
    required this.friendName,
    required this.netBalance,
    required this.displayText,
  });

  final int friendUserId;
  final String friendName;
  final double netBalance;
  final String displayText;

  factory FriendBalance.fromJson(Map<String, dynamic> json) {
    return FriendBalance(
      friendUserId: json['friendUserId'] as int,
      friendName: json['friendName'] as String,
      netBalance: (json['netBalance'] as num).toDouble(),
      displayText: json['displayText'] as String,
    );
  }
}

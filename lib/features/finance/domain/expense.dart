import 'expense_category.dart';
import 'payment_method.dart';

class Expense {
  const Expense({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.expenseDate,
    required this.createdAt,
    required this.updatedAt,
    this.merchantName,
    this.paymentMethod,
    this.notes,
    this.split,
  });

  final int id;
  final String userId;
  final double amount;
  final ExpenseCategory category;
  final String? merchantName;
  final PaymentMethod? paymentMethod;
  final DateTime expenseDate;
  final String? notes;
  final ExpenseSplitSummary? split;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as int,
      userId: json['userId'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: ExpenseCategory.fromApi(json['category'] as String),
      merchantName: json['merchantName'] as String?,
      paymentMethod: json['paymentMethod'] == null
          ? null
          : PaymentMethod.fromJson(
              json['paymentMethod'] as Map<String, dynamic>,
            ),
      expenseDate: DateTime.parse(json['expenseDate'] as String),
      notes: json['notes'] as String?,
      split: json['split'] == null
          ? null
          : ExpenseSplitSummary.fromJson(json['split'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class ExpenseSplitSummary {
  const ExpenseSplitSummary({
    required this.sharedExpenseId,
    required this.friendUserId,
    required this.friendName,
    required this.totalAmount,
    required this.currentUserShareAmount,
    required this.currentUserPaidAmount,
    required this.currentUserNetAmount,
    required this.displayText,
  });

  final int sharedExpenseId;
  final int friendUserId;
  final String friendName;
  final double totalAmount;
  final double currentUserShareAmount;
  final double currentUserPaidAmount;
  final double currentUserNetAmount;
  final String displayText;

  factory ExpenseSplitSummary.fromJson(Map<String, dynamic> json) {
    return ExpenseSplitSummary(
      sharedExpenseId: json['sharedExpenseId'] as int,
      friendUserId: json['friendUserId'] as int,
      friendName: json['friendName'] as String,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      currentUserShareAmount: (json['currentUserShareAmount'] as num)
          .toDouble(),
      currentUserPaidAmount: (json['currentUserPaidAmount'] as num).toDouble(),
      currentUserNetAmount: (json['currentUserNetAmount'] as num).toDouble(),
      displayText: json['displayText'] as String,
    );
  }
}

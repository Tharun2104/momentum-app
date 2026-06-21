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
  });

  final int id;
  final String userId;
  final double amount;
  final ExpenseCategory category;
  final String? merchantName;
  final PaymentMethod? paymentMethod;
  final DateTime expenseDate;
  final String? notes;
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
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

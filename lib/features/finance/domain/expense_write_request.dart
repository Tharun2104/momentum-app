import 'expense_category.dart';

class ExpenseWriteRequest {
  const ExpenseWriteRequest({
    required this.amount,
    required this.category,
    required this.expenseDate,
    this.merchantName,
    this.paymentMethodId,
    this.notes,
  });

  final double amount;
  final ExpenseCategory category;
  final DateTime expenseDate;
  final String? merchantName;
  final int? paymentMethodId;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'category': category.apiValue,
      'merchantName': merchantName,
      'paymentMethodId': paymentMethodId,
      'expenseDate': _dateOnly(expenseDate),
      'notes': notes,
    };
  }

  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

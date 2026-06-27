import 'expense_category.dart';

class ExpenseWriteRequest {
  const ExpenseWriteRequest({
    required this.amount,
    required this.category,
    required this.expenseDate,
    this.merchantName,
    this.paymentMethodId,
    this.notes,
    this.split,
  });

  final double amount;
  final ExpenseCategory category;
  final DateTime expenseDate;
  final String? merchantName;
  final int? paymentMethodId;
  final String? notes;
  final ExpenseSplitWriteRequest? split;

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'category': category.apiValue,
      'merchantName': merchantName,
      'paymentMethodId': paymentMethodId,
      'expenseDate': _dateOnly(expenseDate),
      'notes': notes,
      if (split != null) 'split': split!.toJson(),
    };
  }

  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class ExpenseSplitWriteRequest {
  const ExpenseSplitWriteRequest({
    required this.enabled,
    this.friendUserId,
    this.friendUserIds = const [],
    this.splitType = 'EQUAL',
  });

  final bool enabled;
  final int? friendUserId;
  final List<int> friendUserIds;
  final String splitType;

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'friendUserId': friendUserId,
      'friendUserIds': friendUserIds,
      'splitType': splitType,
    };
  }
}

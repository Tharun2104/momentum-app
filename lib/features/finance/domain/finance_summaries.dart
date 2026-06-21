import 'expense_category.dart';
import 'payment_method.dart';

class MonthlySummary {
  const MonthlySummary({
    required this.totalSpent,
    required this.transactionCount,
    required this.averageTransactionAmount,
  });

  final double totalSpent;
  final int transactionCount;
  final double averageTransactionAmount;

  factory MonthlySummary.fromJson(Map<String, dynamic> json) {
    return MonthlySummary(
      totalSpent: (json['totalSpent'] as num).toDouble(),
      transactionCount: json['transactionCount'] as int,
      averageTransactionAmount: (json['averageTransactionAmount'] as num)
          .toDouble(),
    );
  }
}

class CategorySummary {
  const CategorySummary({
    required this.category,
    required this.totalAmount,
    required this.percentage,
  });

  final ExpenseCategory category;
  final double totalAmount;
  final double percentage;

  factory CategorySummary.fromJson(Map<String, dynamic> json) {
    return CategorySummary(
      category: ExpenseCategory.fromApi(json['category'] as String),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

class PaymentMethodSummary {
  const PaymentMethodSummary({
    required this.paymentMethod,
    required this.totalAmount,
  });

  final PaymentMethod paymentMethod;
  final double totalAmount;

  factory PaymentMethodSummary.fromJson(Map<String, dynamic> json) {
    return PaymentMethodSummary(
      paymentMethod: PaymentMethod.fromJson(
        json['paymentMethod'] as Map<String, dynamic>,
      ),
      totalAmount: (json['totalAmount'] as num).toDouble(),
    );
  }
}

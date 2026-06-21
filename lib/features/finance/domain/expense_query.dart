class ExpenseQuery {
  const ExpenseQuery({this.month, this.paymentMethodId});

  final DateTime? month;
  final int? paymentMethodId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ExpenseQuery &&
            other.month == month &&
            other.paymentMethodId == paymentMethodId;
  }

  @override
  int get hashCode => Object.hash(month, paymentMethodId);
}

import 'package:flutter/material.dart';

enum ExpenseCategory {
  food,
  groceries,
  shopping,
  transport,
  bills,
  health,
  entertainment,
  other;

  String get apiValue => name.toUpperCase();

  String get label {
    switch (this) {
      case ExpenseCategory.food:
        return 'Food';
      case ExpenseCategory.groceries:
        return 'Groceries';
      case ExpenseCategory.shopping:
        return 'Shopping';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.bills:
        return 'Bills';
      case ExpenseCategory.health:
        return 'Health';
      case ExpenseCategory.entertainment:
        return 'Fun';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.groceries:
        return Icons.local_grocery_store_rounded;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag_rounded;
      case ExpenseCategory.transport:
        return Icons.directions_car_rounded;
      case ExpenseCategory.bills:
        return Icons.receipt_long_rounded;
      case ExpenseCategory.health:
        return Icons.health_and_safety_rounded;
      case ExpenseCategory.entertainment:
        return Icons.movie_rounded;
      case ExpenseCategory.other:
        return Icons.more_horiz_rounded;
    }
  }

  static ExpenseCategory fromApi(String value) {
    return ExpenseCategory.values.firstWhere(
      (category) => category.apiValue == value,
      orElse: () => ExpenseCategory.other,
    );
  }
}

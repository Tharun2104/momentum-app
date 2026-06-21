import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../data/finance_api_client.dart';
import '../data/finance_repository.dart';
import '../domain/expense.dart';
import '../domain/expense_query.dart';
import '../domain/finance_summaries.dart';
import '../domain/payment_method.dart';

final selectedFinanceMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return DioFinanceRepository(FinanceApiClient(ref.watch(dioProvider)));
});

final expensesProvider = FutureProvider<List<Expense>>((ref) {
  return ref.watch(financeRepositoryProvider).getExpenses();
});

final filteredExpensesProvider =
    FutureProvider.family<List<Expense>, ExpenseQuery>((ref, query) {
      return ref
          .watch(financeRepositoryProvider)
          .getExpenses(
            month: query.month,
            paymentMethodId: query.paymentMethodId,
          );
    });

final expenseProvider = FutureProvider.family<Expense, int>((ref, id) {
  return ref.watch(financeRepositoryProvider).getExpense(id);
});

final paymentMethodsProvider = FutureProvider<List<PaymentMethod>>((ref) {
  return ref.watch(financeRepositoryProvider).getPaymentMethods();
});

final paymentMethodProvider = FutureProvider.family<PaymentMethod, int>((
  ref,
  id,
) {
  return ref.watch(financeRepositoryProvider).getPaymentMethod(id);
});

final monthlySummaryProvider = FutureProvider<MonthlySummary>((ref) {
  final month = ref.watch(selectedFinanceMonthProvider);
  return ref.watch(financeRepositoryProvider).getMonthlySummary(month);
});

final categorySummaryProvider = FutureProvider<List<CategorySummary>>((ref) {
  final month = ref.watch(selectedFinanceMonthProvider);
  return ref.watch(financeRepositoryProvider).getCategorySummary(month);
});

final paymentMethodSummaryProvider = FutureProvider<List<PaymentMethodSummary>>(
  (ref) {
    final month = ref.watch(selectedFinanceMonthProvider);
    return ref.watch(financeRepositoryProvider).getPaymentMethodSummary(month);
  },
);

void refreshFinanceProviders(WidgetRef ref) {
  ref.invalidate(expensesProvider);
  ref.invalidate(filteredExpensesProvider);
  ref.invalidate(paymentMethodsProvider);
  ref.invalidate(monthlySummaryProvider);
  ref.invalidate(categorySummaryProvider);
  ref.invalidate(paymentMethodSummaryProvider);
}

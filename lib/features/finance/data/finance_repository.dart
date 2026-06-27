import '../domain/expense.dart';
import '../domain/expense_write_request.dart';
import '../domain/finance_summaries.dart';
import '../domain/payment_method.dart';
import '../domain/payment_method_write_request.dart';
import '../domain/shared_expense.dart';
import 'finance_api_client.dart';

abstract class FinanceRepository {
  Future<List<Expense>> getExpenses({DateTime? month, int? paymentMethodId});
  Future<Expense> getExpense(int id);
  Future<Expense> createExpense(ExpenseWriteRequest request);
  Future<Expense> updateExpense(int id, ExpenseWriteRequest request);
  Future<void> deleteExpense(int id);
  Future<List<PaymentMethod>> getPaymentMethods();
  Future<PaymentMethod> getPaymentMethod(int id);
  Future<PaymentMethod> createPaymentMethod(PaymentMethodWriteRequest request);
  Future<PaymentMethod> updatePaymentMethod(
    int id,
    PaymentMethodWriteRequest request,
  );
  Future<void> deletePaymentMethod(int id);
  Future<MonthlySummary> getMonthlySummary(DateTime month);
  Future<List<CategorySummary>> getCategorySummary(DateTime month);
  Future<List<PaymentMethodSummary>> getPaymentMethodSummary(DateTime month);
  Future<SplitsSummary> getSplitsSummary();
  Future<List<FriendBalance>> getFriendBalances();
  Future<List<SharedExpense>> getRecentSplits();
  Future<SharedExpense> getSharedExpense(int id);
  Future<void> deleteSharedExpense(int id);
}

class DioFinanceRepository implements FinanceRepository {
  DioFinanceRepository(this._client);

  final FinanceApiClient _client;

  @override
  Future<List<Expense>> getExpenses({DateTime? month, int? paymentMethodId}) =>
      _client.getExpenses(month: month, paymentMethodId: paymentMethodId);

  @override
  Future<Expense> getExpense(int id) => _client.getExpense(id);

  @override
  Future<Expense> createExpense(ExpenseWriteRequest request) =>
      _client.createExpense(request);

  @override
  Future<Expense> updateExpense(int id, ExpenseWriteRequest request) =>
      _client.updateExpense(id, request);

  @override
  Future<void> deleteExpense(int id) => _client.deleteExpense(id);

  @override
  Future<List<PaymentMethod>> getPaymentMethods() =>
      _client.getPaymentMethods();

  @override
  Future<PaymentMethod> getPaymentMethod(int id) =>
      _client.getPaymentMethod(id);

  @override
  Future<PaymentMethod> createPaymentMethod(
    PaymentMethodWriteRequest request,
  ) => _client.createPaymentMethod(request);

  @override
  Future<PaymentMethod> updatePaymentMethod(
    int id,
    PaymentMethodWriteRequest request,
  ) => _client.updatePaymentMethod(id, request);

  @override
  Future<void> deletePaymentMethod(int id) => _client.deletePaymentMethod(id);

  @override
  Future<MonthlySummary> getMonthlySummary(DateTime month) =>
      _client.getMonthlySummary(month);

  @override
  Future<List<CategorySummary>> getCategorySummary(DateTime month) =>
      _client.getCategorySummary(month);

  @override
  Future<List<PaymentMethodSummary>> getPaymentMethodSummary(DateTime month) =>
      _client.getPaymentMethodSummary(month);

  @override
  Future<SplitsSummary> getSplitsSummary() => _client.getSplitsSummary();

  @override
  Future<List<FriendBalance>> getFriendBalances() =>
      _client.getFriendBalances();

  @override
  Future<List<SharedExpense>> getRecentSplits() => _client.getRecentSplits();

  @override
  Future<SharedExpense> getSharedExpense(int id) =>
      _client.getSharedExpense(id);

  @override
  Future<void> deleteSharedExpense(int id) => _client.deleteSharedExpense(id);
}

import 'package:dio/dio.dart';

import '../domain/expense.dart';
import '../domain/expense_write_request.dart';
import '../domain/finance_summaries.dart';
import '../domain/payment_method.dart';
import '../domain/payment_method_write_request.dart';
import 'finance_api_exception.dart';

class FinanceApiClient {
  FinanceApiClient(this._dio);

  final Dio _dio;

  Future<List<Expense>> getExpenses({
    DateTime? month,
    int? paymentMethodId,
  }) async {
    return mapFinanceApiErrors(() async {
      final queryParameters = <String, dynamic>{};
      if (month != null) {
        queryParameters['month'] = _yearMonth(month);
      }
      if (paymentMethodId != null) {
        queryParameters['paymentMethodId'] = paymentMethodId;
      }

      final response = await _dio.get<List<dynamic>>(
        '/api/expenses',
        queryParameters: queryParameters,
      );

      return response.data!
          .map((json) => Expense.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Expense> getExpense(int id) async {
    return mapFinanceApiErrors(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/expenses/$id',
      );

      return Expense.fromJson(response.data!);
    });
  }

  Future<Expense> createExpense(ExpenseWriteRequest request) async {
    return mapFinanceApiErrors(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/expenses',
        data: request.toJson(),
      );

      return Expense.fromJson(response.data!);
    });
  }

  Future<Expense> updateExpense(int id, ExpenseWriteRequest request) async {
    return mapFinanceApiErrors(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        '/api/expenses/$id',
        data: request.toJson(),
      );

      return Expense.fromJson(response.data!);
    });
  }

  Future<void> deleteExpense(int id) async {
    return mapFinanceApiErrors(() async {
      await _dio.delete<void>('/api/expenses/$id');
    });
  }

  Future<List<PaymentMethod>> getPaymentMethods() async {
    return mapFinanceApiErrors(() async {
      final response = await _dio.get<List<dynamic>>('/api/payment-methods');

      return response.data!
          .map((json) => PaymentMethod.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }

  Future<PaymentMethod> getPaymentMethod(int id) async {
    return mapFinanceApiErrors(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/payment-methods/$id',
      );

      return PaymentMethod.fromJson(response.data!);
    });
  }

  Future<PaymentMethod> createPaymentMethod(
    PaymentMethodWriteRequest request,
  ) async {
    return mapFinanceApiErrors(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/payment-methods',
        data: request.toJson(),
      );

      return PaymentMethod.fromJson(response.data!);
    });
  }

  Future<PaymentMethod> updatePaymentMethod(
    int id,
    PaymentMethodWriteRequest request,
  ) async {
    return mapFinanceApiErrors(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        '/api/payment-methods/$id',
        data: request.toJson(),
      );

      return PaymentMethod.fromJson(response.data!);
    });
  }

  Future<void> deletePaymentMethod(int id) async {
    return mapFinanceApiErrors(() async {
      await _dio.delete<void>('/api/payment-methods/$id');
    });
  }

  Future<MonthlySummary> getMonthlySummary(DateTime month) async {
    return mapFinanceApiErrors(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/analytics/monthly-summary',
        queryParameters: {'month': _yearMonth(month)},
      );

      return MonthlySummary.fromJson(response.data!);
    });
  }

  Future<List<CategorySummary>> getCategorySummary(DateTime month) async {
    return mapFinanceApiErrors(() async {
      final response = await _dio.get<List<dynamic>>(
        '/api/analytics/category-summary',
        queryParameters: {'month': _yearMonth(month)},
      );

      return response.data!
          .map((json) => CategorySummary.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }

  Future<List<PaymentMethodSummary>> getPaymentMethodSummary(
    DateTime month,
  ) async {
    return mapFinanceApiErrors(() async {
      final response = await _dio.get<List<dynamic>>(
        '/api/analytics/payment-method-summary',
        queryParameters: {'month': _yearMonth(month)},
      );

      return response.data!
          .map(
            (json) =>
                PaymentMethodSummary.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    });
  }

  String _yearMonth(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }
}

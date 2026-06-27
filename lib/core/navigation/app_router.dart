import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/finance/presentation/expense_dashboard_screen.dart';
import '../../features/finance/domain/expense_query.dart';
import '../../features/finance/presentation/expense_form_screen.dart';
import '../../features/finance/presentation/expense_list_screen.dart';
import '../../features/finance/presentation/monthly_summary_screen.dart';
import '../../features/finance/presentation/payment_method_form_screen.dart';
import '../../features/finance/presentation/payment_method_list_screen.dart';
import '../../features/finance/presentation/shared_expense_detail_screen.dart';
import '../../features/finance/presentation/splits_screen.dart';
import '../../features/fitness/presentation/fitness_screen.dart';
import '../../features/friends/presentation/friends_screen.dart';
import '../../features/friends/presentation/incoming_requests_screen.dart';
import '../../features/friends/presentation/outgoing_requests_screen.dart';
import '../../features/friends/presentation/search_user_screen.dart';
import '../../features/run/presentation/run_history_screen.dart';
import '../../features/run/presentation/run_screen.dart';
import '../../screens/home_screen.dart';

GoRouter createAppRouter({
  required bool isAuthenticated,
  required bool isCheckingAuth,
}) {
  return GoRouter(
    redirect: (context, state) {
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      if (isCheckingAuth) {
        return isAuthRoute ? null : '/login';
      }
      if (!isAuthenticated) {
        return isAuthRoute ? null : '/login';
      }
      if (isAuthRoute) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(path: '/run', builder: (context, state) => const RunScreen()),
      GoRoute(
        path: '/fitness',
        builder: (context, state) => const FitnessScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const RunHistoryScreen(),
      ),
      GoRoute(
        path: '/friends',
        builder: (context, state) => const FriendsScreen(),
        routes: [
          GoRoute(
            path: 'search',
            builder: (context, state) => const SearchUserScreen(),
          ),
          GoRoute(
            path: 'incoming',
            builder: (context, state) => const IncomingRequestsScreen(),
          ),
          GoRoute(
            path: 'outgoing',
            builder: (context, state) => const OutgoingRequestsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/finance',
        builder: (context, state) => const ExpenseDashboardScreen(),
        routes: [
          GoRoute(
            path: 'expenses',
            builder: (context, state) => const ExpenseListScreen(),
          ),
          GoRoute(
            path: 'expenses/new',
            builder: (context, state) => const ExpenseFormScreen(),
          ),
          GoRoute(
            path: 'expenses/payment-method/:id',
            builder: (context, state) {
              final paymentMethodId = int.parse(state.pathParameters['id']!);
              final paymentMethodName =
                  state.uri.queryParameters['name'] ?? 'Payment method';
              final month = _parseYearMonth(state.uri.queryParameters['month']);
              return ExpenseListScreen(
                title: paymentMethodName,
                emptyTitle: 'No $paymentMethodName expenses',
                emptyMessage:
                    'Transactions for this payment method and month will show here.',
                query: ExpenseQuery(
                  month: month,
                  paymentMethodId: paymentMethodId,
                ),
              );
            },
          ),
          GoRoute(
            path: 'expenses/:id/edit',
            builder: (context, state) => ExpenseFormScreen(
              expenseId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'payment-methods',
            builder: (context, state) => const PaymentMethodListScreen(),
          ),
          GoRoute(
            path: 'payment-methods/new',
            builder: (context, state) => const PaymentMethodFormScreen(),
          ),
          GoRoute(
            path: 'payment-methods/:id/edit',
            builder: (context, state) => PaymentMethodFormScreen(
              paymentMethodId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'summary',
            builder: (context, state) => const MonthlySummaryScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/splits',
        builder: (context, state) => const SplitsScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) =>
                const ExpenseFormScreen(startWithSplit: true),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) => SharedExpenseDetailScreen(
              sharedExpenseId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Momentum')),
      body: Center(child: Text(state.error.toString())),
    ),
  );
}

DateTime? _parseYearMonth(String? value) {
  if (value == null) {
    return null;
  }
  final parts = value.split('-');
  if (parts.length != 2) {
    return null;
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null) {
    return null;
  }
  return DateTime(year, month);
}

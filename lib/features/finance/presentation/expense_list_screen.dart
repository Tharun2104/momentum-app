import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/expense.dart';
import '../domain/expense_query.dart';
import 'expense_card.dart';
import 'finance_formatters.dart';
import 'finance_providers.dart';
import 'finance_widgets.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({
    this.title = 'Expenses',
    this.emptyTitle = 'Nothing logged yet',
    this.emptyMessage =
        'Add expenses as they happen. The form is built for quick one-handed entry.',
    this.query,
    super.key,
  });

  final String title;
  final String emptyTitle;
  final String emptyMessage;
  final ExpenseQuery? query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = query == null
        ? ref.watch(expensesProvider)
        : ref.watch(filteredExpensesProvider(query!));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/finance/expenses/new'),
        child: const Icon(Icons.add_rounded),
      ),
      body: expenses.when(
        data: (items) {
          if (items.isEmpty) {
            return FinanceEmptyState(
              icon: Icons.receipt_rounded,
              title: emptyTitle,
              message: emptyMessage,
              action: FilledButton(
                onPressed: () => context.push('/finance/expenses/new'),
                child: const Text('Add expense'),
              ),
            );
          }
          final grouped = _groupByDate(items);
          return RefreshIndicator(
            onRefresh: () async => refreshFinanceProviders(ref),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final entry = grouped.entries.elementAt(index);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
                      child: Text(
                        expenseDate(entry.key),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    ...entry.value.map(
                      (expense) => ExpenseCard(
                        expense: expense,
                        onTap: () => context.push(
                          '/finance/expenses/${expense.id}/edit',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }

  Map<DateTime, List<Expense>> _groupByDate(List<Expense> expenses) {
    final grouped = <DateTime, List<Expense>>{};
    for (final expense in expenses) {
      final date = DateTime(
        expense.expenseDate.year,
        expense.expenseDate.month,
        expense.expenseDate.day,
      );
      grouped.putIfAbsent(date, () => []).add(expense);
    }
    return grouped;
  }
}

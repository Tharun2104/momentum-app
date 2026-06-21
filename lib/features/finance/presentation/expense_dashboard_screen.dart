import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'expense_card.dart';
import 'finance_formatters.dart';
import 'finance_providers.dart';
import 'finance_widgets.dart';

class ExpenseDashboardScreen extends ConsumerWidget {
  const ExpenseDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlySummary = ref.watch(monthlySummaryProvider);
    final categorySummary = ref.watch(categorySummaryProvider);
    final expenses = ref.watch(expensesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money'),
        actions: [
          IconButton(
            tooltip: 'Payment methods',
            onPressed: () => context.push('/finance/payment-methods'),
            icon: const Icon(Icons.account_balance_wallet_rounded),
          ),
          IconButton(
            tooltip: 'Monthly summary',
            onPressed: () => context.push('/finance/summary'),
            icon: const Icon(Icons.bar_chart_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/finance/expenses/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => refreshFinanceProviders(ref),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: monthlySummary.when(
                data: (summary) => Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: .24),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spent this month',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimary.withValues(alpha: .8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        money(summary.totalSpent),
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _SummaryPill(
                            label: '${summary.transactionCount} expenses',
                          ),
                          const SizedBox(width: 10),
                          _SummaryPill(
                            label:
                                '${money(summary.averageTransactionAmount)} avg',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox(
                  height: 190,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _ErrorCard(message: error.toString()),
              ),
            ),
            const FinanceSectionHeader(title: 'Categories'),
            categorySummary.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Your category breakdown appears here.'),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: items
                        .take(4)
                        .map(
                          (item) => FinanceProgressRow(
                            label: item.category.label,
                            value: money(item.totalAmount),
                            progress: item.percentage / 100,
                            icon: item.category.icon,
                          ),
                        )
                        .toList(),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _InlineError(message: error.toString()),
            ),
            FinanceSectionHeader(
              title: 'Recent expenses',
              action: TextButton(
                onPressed: () => context.push('/finance/expenses'),
                child: const Text('View all'),
              ),
            ),
            expenses.when(
              data: (items) {
                if (items.isEmpty) {
                  return FinanceEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No expenses yet',
                    message:
                        'Add your first expense and Momentum will start building your monthly picture.',
                    action: FilledButton.icon(
                      onPressed: () => context.push('/finance/expenses/new'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add expense'),
                    ),
                  );
                }
                return Column(
                  children: items
                      .take(5)
                      .map(
                        (expense) => ExpenseCard(
                          expense: expense,
                          onTap: () => context.push(
                            '/finance/expenses/${expense.id}/edit',
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _InlineError(message: error.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(20), child: Text(message)),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(20), child: Text(message));
  }
}

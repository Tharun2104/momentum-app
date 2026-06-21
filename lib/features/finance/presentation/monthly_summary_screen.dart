import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'finance_formatters.dart';
import 'finance_providers.dart';
import 'finance_widgets.dart';

class MonthlySummaryScreen extends ConsumerWidget {
  const MonthlySummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedFinanceMonthProvider);
    final monthlySummary = ref.watch(monthlySummaryProvider);
    final categorySummary = ref.watch(categorySummaryProvider);
    final paymentSummary = ref.watch(paymentMethodSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly summary')),
      body: RefreshIndicator(
        onRefresh: () async => refreshFinanceProviders(ref),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => _moveMonth(ref, -1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      financeMonth(month),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _moveMonth(ref, 1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: monthlySummary.when(
                data: (summary) => Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total spent'),
                        const SizedBox(height: 8),
                        Text(
                          money(summary.totalSpent),
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _Metric(
                                label: 'Transactions',
                                value: '${summary.transactionCount}',
                              ),
                            ),
                            Expanded(
                              child: _Metric(
                                label: 'Average',
                                value: money(summary.averageTransactionAmount),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text(error.toString()),
              ),
            ),
            const FinanceSectionHeader(title: 'By category'),
            categorySummary.when(
              data: (items) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: items
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
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text(error.toString()),
            ),
            const FinanceSectionHeader(title: 'By payment method'),
            paymentSummary.when(
              data: (items) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: items
                      .map(
                        (item) => FinanceProgressRow(
                          label: item.paymentMethod.nickname,
                          value: money(item.totalAmount),
                          progress:
                              monthlySummary.valueOrNull == null ||
                                  monthlySummary.valueOrNull!.totalSpent == 0
                              ? 0
                              : item.totalAmount /
                                    monthlySummary.valueOrNull!.totalSpent,
                          icon: item.paymentMethod.type.icon,
                          onTap: () => context.push(
                            Uri(
                              path:
                                  '/finance/expenses/payment-method/${item.paymentMethod.id}',
                              queryParameters: {
                                'month': _yearMonth(month),
                                'name': item.paymentMethod.nickname,
                              },
                            ).toString(),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text(error.toString()),
            ),
          ],
        ),
      ),
    );
  }

  void _moveMonth(WidgetRef ref, int delta) {
    final current = ref.read(selectedFinanceMonthProvider);
    ref.read(selectedFinanceMonthProvider.notifier).state = DateTime(
      current.year,
      current.month + delta,
    );
  }

  String _yearMonth(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

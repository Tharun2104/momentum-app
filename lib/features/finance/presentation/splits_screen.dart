import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/shared_expense.dart';
import 'finance_formatters.dart';
import 'finance_providers.dart';
import 'finance_widgets.dart';

class SplitsScreen extends ConsumerWidget {
  const SplitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(splitsSummaryProvider);
    final friendBalances = ref.watch(friendBalancesProvider);
    final recentSplits = ref.watch(recentSplitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Splits')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/splits/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add split'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => refreshFinanceProviders(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
          children: [
            summary.when(
              data: (value) => _BalanceSummaryCard(summary: value),
              loading: () => const SizedBox(
                height: 184,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _InlineError(message: error.toString()),
            ),
            const SizedBox(height: 22),
            const FinanceSectionHeader(title: 'Friend balances'),
            friendBalances.when(
              data: (items) {
                if (items.isEmpty) {
                  return const FinanceEmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No split balances',
                    message: 'Shared expenses with friends will show here.',
                  );
                }
                return Column(
                  children: items
                      .map((balance) => _FriendBalanceTile(balance: balance))
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _InlineError(message: error.toString()),
            ),
            const SizedBox(height: 12),
            const FinanceSectionHeader(title: 'Recent splits'),
            recentSplits.when(
              data: (items) {
                if (items.isEmpty) {
                  return const FinanceEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No shared expenses yet',
                    message: 'Create a split expense from Money to start.',
                  );
                }
                return Column(
                  children: items
                      .map(
                        (sharedExpense) => _SharedExpenseTile(
                          sharedExpense: sharedExpense,
                          onTap: () =>
                              context.push('/splits/${sharedExpense.id}'),
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

class _BalanceSummaryCard extends StatelessWidget {
  const _BalanceSummaryCard({required this.summary});

  final SplitsSummary summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPositive = summary.netBalance >= 0;
    final background = isPositive ? colorScheme.primary : colorScheme.error;
    final foreground = isPositive ? colorScheme.onPrimary : colorScheme.onError;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Net balance',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foreground.withValues(alpha: .82),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            money(summary.netBalance),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  label: 'You are owed',
                  value: money(summary.totalOwedToYou),
                  foreground: foreground,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryValue(
                  label: 'You owe',
                  value: money(summary.totalYouOwe),
                  foreground: foreground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.foreground,
  });

  final String label;
  final String value;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground.withValues(alpha: .82),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendBalanceTile extends StatelessWidget {
  const _FriendBalanceTile({required this.balance});

  final FriendBalance balance;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPositive = balance.netBalance > 0;
    final isNegative = balance.netBalance < 0;
    final color = isPositive
        ? colorScheme.primary
        : isNegative
        ? colorScheme.error
        : colorScheme.outline;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          foregroundColor: color,
          child: const Icon(Icons.person_rounded),
        ),
        title: Text(balance.friendName),
        subtitle: Text(balance.displayText),
        trailing: Text(
          money(balance.netBalance),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SharedExpenseTile extends StatelessWidget {
  const _SharedExpenseTile({required this.sharedExpense, required this.onTap});

  final SharedExpense sharedExpense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Icon(sharedExpense.category.icon, size: 20),
        ),
        title: Text(sharedExpense.title),
        subtitle: Text(
          '${sharedExpense.otherUserName} • ${expenseDate(sharedExpense.expenseDate)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          money(sharedExpense.currentUserShareAmount),
          textAlign: TextAlign.end,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
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

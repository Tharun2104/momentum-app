import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/shared_expense.dart';
import 'finance_formatters.dart';
import 'finance_providers.dart';

class SharedExpenseDetailScreen extends ConsumerStatefulWidget {
  const SharedExpenseDetailScreen({required this.sharedExpenseId, super.key});

  final int sharedExpenseId;

  @override
  ConsumerState<SharedExpenseDetailScreen> createState() =>
      _SharedExpenseDetailScreenState();
}

class _SharedExpenseDetailScreenState
    extends ConsumerState<SharedExpenseDetailScreen> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final sharedExpense = ref.watch(
      sharedExpenseProvider(widget.sharedExpenseId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split details'),
        actions: [
          IconButton(
            tooltip: 'Delete split',
            onPressed: _deleting ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: sharedExpense.when(
        data: (value) => _SharedExpenseDetail(sharedExpense: value),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete split?'),
        content: const Text(
          'This removes the split and its linked expense from monthly totals.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await ref
          .read(financeRepositoryProvider)
          .deleteSharedExpense(widget.sharedExpenseId);
      if (!mounted) return;
      refreshFinanceProviders(ref);
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }
}

class _SharedExpenseDetail extends StatelessWidget {
  const _SharedExpenseDetail({required this.sharedExpense});

  final SharedExpense sharedExpense;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          sharedExpense.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(expenseDate(sharedExpense.expenseDate)),
        const SizedBox(height: 20),
        _AmountPanel(sharedExpense: sharedExpense),
        const SizedBox(height: 20),
        _DetailRow(label: 'Friend', value: sharedExpense.otherUserName),
        _DetailRow(label: 'Paid by', value: sharedExpense.paidByName),
        _DetailRow(label: 'Category', value: sharedExpense.category.label),
        _DetailRow(label: 'Status', value: sharedExpense.displayText),
        if (sharedExpense.participants.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'People',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...sharedExpense.participants.map(
            (participant) => _ParticipantTile(participant: participant),
          ),
        ],
      ],
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant});

  final SharedExpenseParticipant participant;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Text(participant.user.name.characters.first.toUpperCase()),
      ),
      title: Text(participant.user.name),
      subtitle: Text('Share ${money(participant.shareAmount)}'),
      trailing: Text(
        money(participant.netAmount),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _AmountPanel extends StatelessWidget {
  const _AmountPanel({required this.sharedExpense});

  final SharedExpense sharedExpense;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _DetailRow(
            label: 'Total split',
            value: money(sharedExpense.totalAmount),
          ),
          _DetailRow(
            label: 'Your share',
            value: money(sharedExpense.currentUserShareAmount),
          ),
          _DetailRow(
            label: 'You paid',
            value: money(sharedExpense.currentUserPaidAmount),
          ),
          _DetailRow(
            label: 'Net',
            value: money(sharedExpense.currentUserNetAmount),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'finance_providers.dart';
import 'finance_widgets.dart';

class PaymentMethodListScreen extends ConsumerWidget {
  const PaymentMethodListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment methods')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/finance/payment-methods/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: methods.when(
        data: (items) {
          if (items.isEmpty) {
            return FinanceEmptyState(
              icon: Icons.wallet_rounded,
              title: 'Create your first label',
              message:
                  'Add labels like Amex, Chase, BofA, Cash, or Apple Pay. Nothing connects to a bank.',
              action: FilledButton(
                onPressed: () => context.push('/finance/payment-methods/new'),
                child: const Text('Add payment method'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final method = items[index];
              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  leading: CircleAvatar(child: Icon(method.type.icon)),
                  title: Text(
                    method.nickname,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(method.type.label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(
                    '/finance/payment-methods/${method.id}/edit',
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}

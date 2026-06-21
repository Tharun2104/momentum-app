import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/payment_method.dart';
import '../domain/payment_method_type.dart';
import '../domain/payment_method_write_request.dart';
import 'finance_providers.dart';

class PaymentMethodFormScreen extends ConsumerStatefulWidget {
  const PaymentMethodFormScreen({this.paymentMethodId, super.key});

  final int? paymentMethodId;

  @override
  ConsumerState<PaymentMethodFormScreen> createState() =>
      _PaymentMethodFormScreenState();
}

class _PaymentMethodFormScreenState
    extends ConsumerState<PaymentMethodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  PaymentMethodType _type = PaymentMethodType.creditCard;
  bool _seeded = false;
  bool _saving = false;

  bool get _isEditing => widget.paymentMethodId != null;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.paymentMethodId == null
        ? const AsyncValue<PaymentMethod?>.data(null)
        : ref
              .watch(paymentMethodProvider(widget.paymentMethodId!))
              .whenData((value) => value);

    return existing.when(
      data: (method) {
        if (method != null && !_seeded) {
          _nicknameController.text = method.nickname;
          _type = method.type;
          _seeded = true;
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _isEditing ? 'Edit payment method' : 'Add payment method',
            ),
            actions: [
              if (_isEditing)
                IconButton(
                  tooltip: 'Delete',
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _nicknameController,
                  autofocus: !_isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Nickname',
                    hintText: 'Amex, Chase, Cash...',
                    prefixIcon: Icon(Icons.badge_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nickname is required'
                      : null,
                ),
                const SizedBox(height: 22),
                Text(
                  'Type',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: PaymentMethodType.values.map((type) {
                    return ChoiceChip(
                      selected: _type == type,
                      avatar: Icon(type.icon, size: 18),
                      label: Text(type.label),
                      onSelected: (_) => setState(() => _type = type),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text(
                  'Labels only. Momentum does not connect to banks, cards, or Apple Pay.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_saving ? 'Saving...' : 'Save payment method'),
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(error.toString())),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final request = PaymentMethodWriteRequest(
      nickname: _nicknameController.text.trim(),
      type: _type,
    );
    final repository = ref.read(financeRepositoryProvider);
    try {
      if (_isEditing) {
        await repository.updatePaymentMethod(widget.paymentMethodId!, request);
      } else {
        await repository.createPaymentMethod(request);
      }
      if (!mounted) return;
      refreshFinanceProviders(ref);
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete payment method?'),
        content: const Text(
          'Existing expenses will stay saved without this label.',
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

    await ref
        .read(financeRepositoryProvider)
        .deletePaymentMethod(widget.paymentMethodId!);
    if (!mounted) return;
    refreshFinanceProviders(ref);
    context.pop();
  }
}

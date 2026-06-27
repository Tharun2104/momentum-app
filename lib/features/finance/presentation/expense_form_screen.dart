import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/expense.dart';
import '../domain/expense_category.dart';
import '../domain/expense_write_request.dart';
import '../domain/payment_method.dart';
import '../../friends/domain/friend_user.dart';
import '../../friends/presentation/friends_providers.dart';
import 'finance_formatters.dart';
import 'finance_providers.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({
    this.expenseId,
    this.startWithSplit = false,
    super.key,
  });

  final int? expenseId;
  final bool startWithSplit;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _notesController = TextEditingController();
  ExpenseCategory? _category = ExpenseCategory.food;
  int? _paymentMethodId;
  DateTime _expenseDate = DateTime.now();
  bool _splitEnabled = false;
  final Set<int> _splitFriendUserIds = {};
  bool _saving = false;
  bool _seeded = false;

  bool get _isEditing => widget.expenseId != null;

  @override
  void initState() {
    super.initState();
    _splitEnabled = widget.startWithSplit && !_isEditing;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paymentMethods = ref.watch(paymentMethodsProvider);
    final friends = ref.watch(friendsProvider);
    final existingExpense = widget.expenseId == null
        ? const AsyncValue<Expense?>.data(null)
        : ref
              .watch(expenseProvider(widget.expenseId!))
              .whenData((value) => value);

    return existingExpense.when(
      data: (expense) {
        if (expense != null && !_seeded) {
          _seedFromExpense(expense);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(_isEditing ? 'Edit expense' : 'Add expense'),
            actions: [
              if (_isEditing)
                IconButton(
                  tooltip: 'Delete',
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  TextFormField(
                    controller: _amountController,
                    autofocus: !_isEditing,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                    onChanged: (_) {
                      if (_splitEnabled) {
                        setState(() {});
                      }
                    },
                    decoration: const InputDecoration(
                      prefixText: r'$ ',
                      labelText: 'Amount',
                      border: InputBorder.none,
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value ?? '');
                      if (amount == null || amount <= 0) {
                        return 'Enter an amount greater than 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Category',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ExpenseCategory.values.map((category) {
                      return ChoiceChip(
                        selected: _category == category,
                        avatar: Icon(category.icon, size: 18),
                        label: Text(category.label),
                        onSelected: (_) => setState(() => _category = category),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Payment method',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  paymentMethods.when(
                    data: (methods) => _PaymentMethodSelector(
                      methods: methods,
                      selectedId: _paymentMethodId,
                      onSelected: (id) => setState(() => _paymentMethodId = id),
                      onAdd: () => context.push('/finance/payment-methods/new'),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text(error.toString()),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _merchantController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Merchant',
                      prefixIcon: Icon(Icons.storefront_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(expenseDate(_expenseDate)),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  if (_isEditing && expense?.split != null) ...[
                    const SizedBox(height: 20),
                    _ExpenseSplitHistoryCard(split: expense!.split!),
                  ],
                  if (!_isEditing) ...[
                    const SizedBox(height: 20),
                    friends.when(
                      data: (acceptedFriends) => _SplitSection(
                        amount: double.tryParse(_amountController.text) ?? 0,
                        enabled: _splitEnabled,
                        selectedFriendUserIds: _splitFriendUserIds,
                        friends: acceptedFriends,
                        onEnabledChanged: (value) => setState(() {
                          _splitEnabled = value;
                          if (!value) {
                            _splitFriendUserIds.clear();
                          }
                        }),
                        onFriendToggled: (id) => setState(() {
                          if (!_splitFriendUserIds.remove(id)) {
                            _splitFriendUserIds.add(id);
                          }
                        }),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => Text(error.toString()),
                    ),
                  ],
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_saving ? 'Saving...' : 'Save expense'),
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

  void _seedFromExpense(Expense expense) {
    _amountController.text = expense.amount.toStringAsFixed(2);
    _merchantController.text = expense.merchantName ?? '';
    _notesController.text = expense.notes ?? '';
    _category = expense.category;
    _paymentMethodId = expense.paymentMethod?.id;
    _expenseDate = expense.expenseDate;
    _seeded = true;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDate: _expenseDate,
    );
    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _category == null) {
      return;
    }
    if (_paymentMethodId == null) {
      _showError('Select a payment method');
      return;
    }
    if (_splitEnabled && _splitFriendUserIds.isEmpty) {
      _showError('Select at least one friend to split with');
      return;
    }
    setState(() => _saving = true);
    final request = ExpenseWriteRequest(
      amount: double.parse(_amountController.text),
      category: _category!,
      merchantName: _merchantController.text.trim().isEmpty
          ? null
          : _merchantController.text.trim(),
      paymentMethodId: _paymentMethodId,
      expenseDate: _expenseDate,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      split: _splitEnabled
          ? ExpenseSplitWriteRequest(
              enabled: true,
              friendUserId: _splitFriendUserIds.isEmpty
                  ? null
                  : _splitFriendUserIds.first,
              friendUserIds: _splitFriendUserIds.toList(),
            )
          : null,
    );
    final repository = ref.read(financeRepositoryProvider);
    try {
      if (_isEditing) {
        await repository.updateExpense(widget.expenseId!, request);
      } else {
        await repository.createExpense(request);
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

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text(
          'This expense will be removed from your monthly summaries.',
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

    await ref.read(financeRepositoryProvider).deleteExpense(widget.expenseId!);
    if (!mounted) return;
    refreshFinanceProviders(ref);
    context.pop();
  }
}

class _SplitSection extends StatelessWidget {
  const _SplitSection({
    required this.amount,
    required this.enabled,
    required this.selectedFriendUserIds,
    required this.friends,
    required this.onEnabledChanged,
    required this.onFriendToggled,
  });

  final double amount;
  final bool enabled;
  final Set<int> selectedFriendUserIds;
  final List<FriendUser> friends;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onFriendToggled;

  @override
  Widget build(BuildContext context) {
    final selectedFriends = _selectedFriends();
    final memberCount = selectedFriends.length + 1;
    final share = amount > 0 && selectedFriends.isNotEmpty
        ? amount / memberCount
        : 0.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Split',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Switch(value: enabled, onChanged: onEnabledChanged),
              ],
            ),
            const SizedBox(height: 2),
            const Text('Split equally with friends'),
            if (enabled) ...[
              const SizedBox(height: 14),
              if (friends.isEmpty)
                const Text('Add friends first from Profile.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: friends
                      .map(
                        (friend) => FilterChip(
                          selected: selectedFriendUserIds.contains(friend.id),
                          avatar: const Icon(Icons.person_rounded, size: 18),
                          label: Text(friend.name),
                          onSelected: (_) => onFriendToggled(friend.id),
                        ),
                      )
                      .toList(),
                ),
              if (friends.isNotEmpty) ...[
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _SplitPreviewRow(label: 'Total', value: money(amount)),
                        _SplitPreviewRow(
                          label: 'People',
                          value: memberCount.toString(),
                        ),
                        _SplitPreviewRow(
                          label: 'Your share',
                          value: money(share),
                        ),
                        _SplitPreviewRow(
                          label: 'Each friend',
                          value: money(share),
                        ),
                        const Divider(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            selectedFriends.isEmpty
                                ? 'Select friends to preview who owes what'
                                : _previewText(selectedFriends, share),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<FriendUser> _selectedFriends() {
    return friends
        .where((friend) => selectedFriendUserIds.contains(friend.id))
        .toList();
  }

  String _previewText(List<FriendUser> selectedFriends, double share) {
    if (selectedFriends.length == 1) {
      return '${selectedFriends.single.name} owes ${money(share)}';
    }
    return '${selectedFriends.map((friend) => friend.name).join(', ')} owe ${money(share)} each';
  }
}

class _ExpenseSplitHistoryCard extends StatelessWidget {
  const _ExpenseSplitHistoryCard({required this.split});

  final ExpenseSplitSummary split;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.call_split_rounded, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Split with ${split.friendName}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SplitPreviewRow(
              label: 'Original total',
              value: money(split.totalAmount),
            ),
            _SplitPreviewRow(
              label: 'Your expense',
              value: money(split.currentUserShareAmount),
            ),
            _SplitPreviewRow(
              label: 'You paid',
              value: money(split.currentUserPaidAmount),
            ),
            const Divider(height: 20),
            Text(
              split.displayText,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitPreviewRow extends StatelessWidget {
  const _SplitPreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.methods,
    required this.selectedId,
    required this.onSelected,
    required this.onAdd,
  });

  final List<PaymentMethod> methods;
  final int? selectedId;
  final ValueChanged<int?> onSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (methods.isEmpty) {
      return OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('Add a payment method'),
      );
    }
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: methods.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == methods.length) {
            return ActionChip(
              avatar: const Icon(Icons.add_rounded),
              label: const Text('New'),
              onPressed: onAdd,
            );
          }
          final method = methods[index];
          final selected = selectedId == method.id;
          return ChoiceChip(
            selected: selected,
            avatar: Icon(method.type.icon),
            label: SizedBox(
              width: 90,
              child: Text(
                method.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            onSelected: (_) => onSelected(selected ? null : method.id),
          );
        },
      ),
    );
  }
}

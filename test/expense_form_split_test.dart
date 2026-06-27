import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:momentum_app/features/finance/data/finance_repository.dart';
import 'package:momentum_app/features/finance/domain/expense.dart';
import 'package:momentum_app/features/finance/domain/expense_category.dart';
import 'package:momentum_app/features/finance/domain/expense_write_request.dart';
import 'package:momentum_app/features/finance/domain/finance_summaries.dart';
import 'package:momentum_app/features/finance/domain/payment_method.dart';
import 'package:momentum_app/features/finance/domain/payment_method_type.dart';
import 'package:momentum_app/features/finance/domain/payment_method_write_request.dart';
import 'package:momentum_app/features/finance/domain/shared_expense.dart';
import 'package:momentum_app/features/finance/presentation/expense_form_screen.dart';
import 'package:momentum_app/features/finance/presentation/finance_providers.dart';
import 'package:momentum_app/features/friends/data/friends_repository.dart';
import 'package:momentum_app/features/friends/domain/friend_request.dart';
import 'package:momentum_app/features/friends/domain/friend_user.dart';
import 'package:momentum_app/features/friends/presentation/friends_providers.dart';

void main() {
  testWidgets('add expense screen shows split toggle', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await _scrollToSplit(tester);

    expect(find.text('Split'), findsOneWidget);
    expect(find.text('Split equally with friends'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('friend chips appear when split is enabled', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await _scrollToSplit(tester);
    await _enableSplit(tester);

    expect(find.byType(FilterChip), findsWidgets);
    expect(find.text('Prathibha'), findsOneWidget);
  });

  testWidgets('save fails when split is enabled with no selected friend', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(friendsRepository: _FakeFriendsRepository(friends: [])),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '40');
    await tester.tap(find.text('Cash'));
    await _scrollToSplit(tester);
    await _enableSplit(tester);
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect(
      find.text('Select at least one friend to split with'),
      findsOneWidget,
    );
  });

  testWidgets('split preview calculates half correctly', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '40');
    await _scrollToSplit(tester);
    await _enableSplit(tester);
    await tester.tap(find.text('Prathibha'));
    await tester.pumpAndSettle();

    expect(find.text(r'$40.00'), findsOneWidget);
    expect(find.text(r'$20.00'), findsNWidgets(2));
    expect(find.text('Prathibha owes \$20.00'), findsOneWidget);
  });

  testWidgets('save sends split payload when enabled with selected friend', (
    tester,
  ) async {
    final financeRepository = _FakeFinanceRepository();
    await tester.pumpWidget(_testApp(financeRepository: financeRepository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '50');
    await tester.tap(find.text('Cash'));
    await _scrollToSplit(tester);
    await _enableSplit(tester);
    await tester.tap(find.text('Prathibha'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect(financeRepository.createdExpenses, hasLength(1));
    final split = financeRepository.createdExpenses.single.split;
    expect(split, isNotNull);
    expect(split!.enabled, isTrue);
    expect(split.friendUserId, _prathibha.id);
    expect(split.friendUserIds, [_prathibha.id]);
    expect(split.splitType, 'EQUAL');
  });

  test('normal expense payload omits split when disabled', () {
    final request = ExpenseWriteRequest(
      amount: 18.50,
      category: ExpenseCategory.food,
      expenseDate: DateTime(2026, 6, 21),
      paymentMethodId: 1,
    );

    expect(request.toJson().containsKey('split'), isFalse);
  });
}

Future<void> _scrollToSplit(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Split'),
    240,
    scrollable: find.byType(Scrollable).first,
  );
}

Future<void> _enableSplit(WidgetTester tester) async {
  final splitSwitch = tester.widget<Switch>(find.byType(Switch));
  splitSwitch.onChanged!(true);
  await tester.pumpAndSettle();
}

Widget _testApp({
  FinanceRepository? financeRepository,
  FriendsRepository? friendsRepository,
}) {
  return ProviderScope(
    overrides: [
      financeRepositoryProvider.overrideWithValue(
        financeRepository ?? _FakeFinanceRepository(),
      ),
      friendsRepositoryProvider.overrideWithValue(
        friendsRepository ?? _FakeFriendsRepository(),
      ),
    ],
    child: const MaterialApp(home: ExpenseFormScreen()),
  );
}

class _FakeFinanceRepository implements FinanceRepository {
  final List<ExpenseWriteRequest> createdExpenses = [];

  @override
  Future<Expense> createExpense(ExpenseWriteRequest request) async {
    createdExpenses.add(request);
    final now = DateTime.parse('2026-06-21T12:00:00Z');
    return Expense(
      id: 1,
      userId: '1',
      amount: request.amount,
      category: request.category,
      expenseDate: request.expenseDate,
      createdAt: now,
      updatedAt: now,
      merchantName: request.merchantName,
      paymentMethod: _paymentMethod,
      notes: request.notes,
    );
  }

  @override
  Future<void> deleteExpense(int id) async {}

  @override
  Future<void> deleteSharedExpense(int id) async {}

  @override
  Future<List<CategorySummary>> getCategorySummary(DateTime month) async => [];

  @override
  Future<Expense> getExpense(int id) async => throw UnimplementedError();

  @override
  Future<List<Expense>> getExpenses({
    DateTime? month,
    int? paymentMethodId,
  }) async => [];

  @override
  Future<MonthlySummary> getMonthlySummary(DateTime month) async {
    return const MonthlySummary(
      totalSpent: 0,
      transactionCount: 0,
      averageTransactionAmount: 0,
    );
  }

  @override
  Future<PaymentMethod> getPaymentMethod(int id) async => _paymentMethod;

  @override
  Future<List<PaymentMethod>> getPaymentMethods() async => [_paymentMethod];

  @override
  Future<List<PaymentMethodSummary>> getPaymentMethodSummary(
    DateTime month,
  ) async => [];

  @override
  Future<List<FriendBalance>> getFriendBalances() async => [];

  @override
  Future<SharedExpense> getSharedExpense(int id) async {
    return SharedExpense(
      id: id,
      title: 'Dinner',
      totalAmount: 50,
      category: ExpenseCategory.food,
      expenseDate: DateTime.parse('2026-06-21T12:00:00Z'),
      paidByUserId: 1,
      paidByName: 'You',
      friendUserId: _prathibha.id,
      friendName: _prathibha.name,
      currentUserShareAmount: 25,
      currentUserPaidAmount: 50,
      currentUserNetAmount: 25,
      otherUserName: _prathibha.name,
      displayText: 'Prathibha owes you \$25',
    );
  }

  @override
  Future<List<SharedExpense>> getRecentSplits() async => [];

  @override
  Future<SplitsSummary> getSplitsSummary() async {
    return const SplitsSummary(
      netBalance: 0,
      totalOwedToYou: 0,
      totalYouOwe: 0,
    );
  }

  @override
  Future<Expense> updateExpense(int id, ExpenseWriteRequest request) async {
    return createExpense(request);
  }

  @override
  Future<PaymentMethod> createPaymentMethod(
    PaymentMethodWriteRequest request,
  ) async => _paymentMethod;

  @override
  Future<void> deletePaymentMethod(int id) async {}

  @override
  Future<PaymentMethod> updatePaymentMethod(
    int id,
    PaymentMethodWriteRequest request,
  ) async => _paymentMethod;
}

class _FakeFriendsRepository implements FriendsRepository {
  _FakeFriendsRepository({List<FriendUser>? friends})
    : friends = friends ?? const [_prathibha];

  final List<FriendUser> friends;

  @override
  Future<FriendRequest> acceptRequest(int requestId) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteFriend(int friendUserId) async {}

  @override
  Future<List<FriendUser>> getFriends() async => friends;

  @override
  Future<List<FriendRequest>> getIncomingRequests() async => [];

  @override
  Future<List<FriendRequest>> getOutgoingRequests() async => [];

  @override
  Future<FriendRequest> rejectRequest(int requestId) {
    throw UnimplementedError();
  }

  @override
  Future<FriendRequest> sendRequest(int receiverUserId) {
    throw UnimplementedError();
  }

  @override
  Future<FriendUser> searchUser(String email) {
    throw UnimplementedError();
  }
}

final _paymentMethod = PaymentMethod(
  id: 1,
  userId: '1',
  nickname: 'Cash',
  type: PaymentMethodType.cash,
  createdAt: DateTime.parse('2026-06-21T12:00:00Z'),
  updatedAt: DateTime.parse('2026-06-21T12:00:00Z'),
);

const _prathibha = FriendUser(
  id: 2,
  name: 'Prathibha',
  email: 'prathibha@example.com',
);

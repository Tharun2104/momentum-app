import 'package:intl/intl.dart';

final _currency = NumberFormat.simpleCurrency(decimalDigits: 2);
final _date = DateFormat('EEE, MMM d');
final _month = DateFormat('MMMM yyyy');

String money(double value) => _currency.format(value);

String expenseDate(DateTime value) => _date.format(value);

String financeMonth(DateTime value) => _month.format(value);

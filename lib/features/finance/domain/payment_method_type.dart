import 'package:flutter/material.dart';

enum PaymentMethodType {
  creditCard,
  debitCard,
  cash,
  digitalWallet,
  other;

  String get apiValue {
    switch (this) {
      case PaymentMethodType.creditCard:
        return 'CREDIT_CARD';
      case PaymentMethodType.debitCard:
        return 'DEBIT_CARD';
      case PaymentMethodType.cash:
        return 'CASH';
      case PaymentMethodType.digitalWallet:
        return 'DIGITAL_WALLET';
      case PaymentMethodType.other:
        return 'OTHER';
    }
  }

  String get label {
    switch (this) {
      case PaymentMethodType.creditCard:
        return 'Credit Card';
      case PaymentMethodType.debitCard:
        return 'Debit Card';
      case PaymentMethodType.cash:
        return 'Cash';
      case PaymentMethodType.digitalWallet:
        return 'Digital Wallet';
      case PaymentMethodType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMethodType.creditCard:
        return Icons.credit_card_rounded;
      case PaymentMethodType.debitCard:
        return Icons.payment_rounded;
      case PaymentMethodType.cash:
        return Icons.payments_rounded;
      case PaymentMethodType.digitalWallet:
        return Icons.wallet_rounded;
      case PaymentMethodType.other:
        return Icons.account_balance_wallet_rounded;
    }
  }

  static PaymentMethodType fromApi(String value) {
    return PaymentMethodType.values.firstWhere(
      (type) => type.apiValue == value,
      orElse: () => PaymentMethodType.other,
    );
  }
}

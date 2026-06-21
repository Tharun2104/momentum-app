import 'payment_method_type.dart';

class PaymentMethodWriteRequest {
  const PaymentMethodWriteRequest({required this.nickname, required this.type});

  final String nickname;
  final PaymentMethodType type;

  Map<String, dynamic> toJson() {
    return {'nickname': nickname, 'type': type.apiValue};
  }
}

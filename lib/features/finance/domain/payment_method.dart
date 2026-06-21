import 'payment_method_type.dart';

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String userId;
  final String nickname;
  final PaymentMethodType type;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as int,
      userId: json['userId'] as String,
      nickname: json['nickname'] as String,
      type: PaymentMethodType.fromApi(json['type'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

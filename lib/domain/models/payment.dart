/// A selectable payment method (from POS Profile / snapshot).
class PaymentMode {
  const PaymentMode({required this.name, this.type, this.isDefault = false});

  final String name;
  final String? type;
  final bool isDefault;
}

/// An entered payment line on the payment screen.
class PaymentEntry {
  PaymentEntry({required this.modeOfPayment, this.type, this.amount = 0});

  final String modeOfPayment;
  final String? type;
  double amount;

  Map<String, dynamic> toJson() => {
        'mode_of_payment': modeOfPayment,
        if (type != null) 'type': type,
        'amount': amount,
      };
}

/// A customer selectable in the POS, from live lookup or snapshot cache.
class PosCustomer {
  const PosCustomer({
    required this.name,
    this.customerName,
    this.mobileNo,
    this.emailId,
    this.customerGroup,
    this.loyaltyProgram,
    this.allowCredit = false,
  });

  final String name;
  final String? customerName;
  final String? mobileNo;
  final String? emailId;
  final String? customerGroup;
  final String? loyaltyProgram;
  final bool allowCredit;

  String get display => customerName ?? name;

  factory PosCustomer.fromJson(Map<String, dynamic> m) => PosCustomer(
        name: m['name'] as String,
        customerName: m['customer_name'] as String?,
        mobileNo: m['mobile_no'] as String?,
        emailId: m['email_id'] as String?,
        customerGroup: m['customer_group'] as String?,
        loyaltyProgram: m['loyalty_program'] as String?,
        allowCredit: m['allow_credit'] == 1 || m['allow_credit'] == true,
      );
}

/// Resolved POS session context (profile + price list + warehouse).
class ProfileContext {
  const ProfileContext({
    required this.posProfile,
    required this.priceList,
    required this.warehouse,
    required this.currency,
  });

  final String posProfile;
  final String priceList;
  final String warehouse;
  final String currency;
}

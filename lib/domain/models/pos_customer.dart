/// A customer selectable in the POS, from live lookup or snapshot cache.
class PosCustomer {
  const PosCustomer({
    required this.name,
    this.customerName,
    this.customerType,
    this.mobileNo,
    this.emailId,
    this.customerGroup,
    this.territory,
    this.loyaltyProgram,
    this.allowCredit = false,
  });

  final String name;
  final String? customerName;
  final String? customerType; // Company / Individual
  final String? mobileNo;
  final String? emailId;
  final String? customerGroup;
  final String? territory;
  final String? loyaltyProgram;
  final bool allowCredit;

  String get display => customerName ?? name;

  String get subtitle => [
        if (customerGroup != null && customerGroup!.isNotEmpty) customerGroup,
        if (mobileNo != null && mobileNo!.isNotEmpty) mobileNo,
        if (emailId != null && emailId!.isNotEmpty) emailId,
      ].whereType<String>().join(' • ');

  factory PosCustomer.fromJson(Map<String, dynamic> m) => PosCustomer(
        name: m['name'] as String,
        customerName: m['customer_name'] as String?,
        customerType: m['customer_type'] as String?,
        mobileNo: m['mobile_no'] as String?,
        emailId: m['email_id'] as String?,
        customerGroup: m['customer_group'] as String?,
        territory: m['territory'] as String?,
        loyaltyProgram: m['loyalty_program'] as String?,
        allowCredit: m['allow_credit'] == 1 || m['allow_credit'] == true,
      );
}

/// Resolved POS session context (profile + price list + warehouse + company).
class ProfileContext {
  const ProfileContext({
    required this.posProfile,
    required this.priceList,
    required this.warehouse,
    required this.currency,
    required this.company,
  });

  final String posProfile;
  final String priceList;
  final String warehouse;
  final String currency;
  final String company;
}

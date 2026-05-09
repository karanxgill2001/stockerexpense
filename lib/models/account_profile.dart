enum AccountWorkspaceAccess { stocker, finance, both }

extension AccountWorkspaceAccessParsing on AccountWorkspaceAccess {
  static AccountWorkspaceAccess fromRaw(Object? value) {
    final normalized = value.toString().trim().toLowerCase();
    switch (normalized) {
      case 'stocker':
      case 'stock':
      case 'stock manager':
        return AccountWorkspaceAccess.stocker;
      case 'finance':
      case 'expense tracker':
        return AccountWorkspaceAccess.finance;
      default:
        return AccountWorkspaceAccess.both;
    }
  }

  String get storageValue {
    switch (this) {
      case AccountWorkspaceAccess.stocker:
        return 'stocker';
      case AccountWorkspaceAccess.finance:
        return 'finance';
      case AccountWorkspaceAccess.both:
        return 'both';
    }
  }

  String get title {
    switch (this) {
      case AccountWorkspaceAccess.stocker:
        return 'Stocker only';
      case AccountWorkspaceAccess.finance:
        return 'Finance only';
      case AccountWorkspaceAccess.both:
        return 'Stocker and Finance';
    }
  }
}

class AccountProfile {
  const AccountProfile({
    required this.companyName,
    required this.fullName,
    required this.address,
    required this.email,
    required this.phoneNo,
    required this.masterKey,
    required this.accessScope,
    this.canManageFinanceEntries = true,
  });

  final String companyName;
  final String fullName;
  final String address;
  final String email;
  final String phoneNo;
  final String masterKey;
  final AccountWorkspaceAccess accessScope;
  final bool canManageFinanceEntries;

  bool get canUseStockManager =>
      accessScope == AccountWorkspaceAccess.stocker ||
      accessScope == AccountWorkspaceAccess.both;

  bool get canUseExpenseTracker =>
      accessScope == AccountWorkspaceAccess.finance ||
      accessScope == AccountWorkspaceAccess.both;

  bool get canToggleWorkspace => accessScope == AccountWorkspaceAccess.both;

  Map<String, dynamic> toJson() {
    return {
      'companyName': companyName,
      'fullName': fullName,
      'address': address,
      'email': email,
      'phoneNo': phoneNo,
      'masterKey': masterKey,
      'accessScope': accessScope.storageValue,
      'canManageFinanceEntries': canManageFinanceEntries,
    };
  }

  factory AccountProfile.fromJson(Map<String, dynamic> json) {
    final rawFinanceAccess =
        json['canManageFinanceEntries'] ??
        json['canEditFinanceEntries'] ??
        json['can edit finance entries'] ??
        json['finance entry edit access'];

    return AccountProfile(
      companyName: (json['companyName'] ?? json['company name'] ?? '')
          .toString(),
      fullName: (json['fullName'] ?? json['full name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phoneNo: (json['phoneNo'] ?? json['phone no'] ?? '').toString(),
      masterKey: (json['masterKey'] ?? json['master key'] ?? '').toString(),
      accessScope: AccountWorkspaceAccessParsing.fromRaw(
        json['accessScope'] ?? json['access'] ?? json['workspace access'],
      ),
      canManageFinanceEntries: rawFinanceAccess == null
          ? true
          : _parseBool(rawFinanceAccess),
    );
  }

  static bool _parseBool(Object? value) {
    final normalized = value.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
}

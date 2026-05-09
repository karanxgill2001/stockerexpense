import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  const SessionService._();

  static const String _rememberMeKey = 'remember_me';
  static const String _signedInKey = 'signed_in';
  static const String _userEmailKey = 'user_email';
  static const String _userFullNameKey = 'user_full_name';
  static const String _companyNameKey = 'company_name';
  static const String _addressKey = 'address';
  static const String _phoneNoKey = 'phone_no';
  static const String _canManageFinanceEntriesKey = 'can_manage_finance_entries';

  static Future<bool> shouldStaySignedIn() async {
    final preferences = await SharedPreferences.getInstance();
    final rememberMe = preferences.getBool(_rememberMeKey) ?? false;
    final signedIn = preferences.getBool(_signedInKey) ?? false;
    return rememberMe && signedIn;
  }

  static Future<void> saveLogin({
    required bool keepSignedIn,
    required String email,
    String? fullName,
    String? companyName,
    String? address,
    String? phoneNo,
    bool canManageFinanceEntries = true,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setBool(_rememberMeKey, keepSignedIn);
    await preferences.setBool(_signedInKey, true);
    await preferences.setString(_userEmailKey, email);
    if (fullName != null && fullName.trim().isNotEmpty) {
      await preferences.setString(_userFullNameKey, fullName.trim());
    } else {
      await preferences.remove(_userFullNameKey);
    }
    if (companyName != null && companyName.trim().isNotEmpty) {
      await preferences.setString(_companyNameKey, companyName.trim());
    } else {
      await preferences.remove(_companyNameKey);
    }
    if (address != null && address.trim().isNotEmpty) {
      await preferences.setString(_addressKey, address.trim());
    } else {
      await preferences.remove(_addressKey);
    }
    if (phoneNo != null && phoneNo.trim().isNotEmpty) {
      await preferences.setString(_phoneNoKey, phoneNo.trim());
    } else {
      await preferences.remove(_phoneNoKey);
    }
    await preferences.setBool(
      _canManageFinanceEntriesKey,
      canManageFinanceEntries,
    );
  }

  static Future<String?> getUserEmail() async {
    final preferences = await SharedPreferences.getInstance();
    final signedIn = preferences.getBool(_signedInKey) ?? false;
    if (!signedIn) {
      return null;
    }
    return preferences.getString(_userEmailKey);
  }

  static Future<String?> getUserFullName() async {
    final preferences = await SharedPreferences.getInstance();
    final signedIn = preferences.getBool(_signedInKey) ?? false;
    if (!signedIn) {
      return null;
    }
    return preferences.getString(_userFullNameKey);
  }

  static Future<bool> getCanManageFinanceEntries() async {
    final preferences = await SharedPreferences.getInstance();
    final signedIn = preferences.getBool(_signedInKey) ?? false;
    if (!signedIn) {
      return true;
    }

    return preferences.getBool(_canManageFinanceEntriesKey) ?? true;
  }

  static Future<void> updateStoredProfile({
    required String email,
    required String fullName,
    required String companyName,
    required String address,
    required String phoneNo,
    bool canManageFinanceEntries = true,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_signedInKey, true);
    await preferences.setString(_userEmailKey, email.trim());
    await preferences.setString(_userFullNameKey, fullName.trim());
    await preferences.setString(_companyNameKey, companyName.trim());
    await preferences.setString(_addressKey, address.trim());
    await preferences.setString(_phoneNoKey, phoneNo.trim());
    await preferences.setBool(
      _canManageFinanceEntriesKey,
      canManageFinanceEntries,
    );
  }

  static Future<void> updateFinanceEntryAccess(
    bool canManageFinanceEntries,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      _canManageFinanceEntriesKey,
      canManageFinanceEntries,
    );
  }

  static Future<void> clearSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_rememberMeKey);
    await preferences.remove(_signedInKey);
    await preferences.remove(_userEmailKey);
    await preferences.remove(_userFullNameKey);
    await preferences.remove(_companyNameKey);
    await preferences.remove(_addressKey);
    await preferences.remove(_phoneNoKey);
    await preferences.remove(_canManageFinanceEntriesKey);
  }
}

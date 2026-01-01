import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAccount {
  final String email;
  final String password;

  SavedAccount({required this.email, required this.password});

  Map<String, String> toMap() => {'email': email, 'password': password};

  factory SavedAccount.fromMap(Map<String, dynamic> map) =>
      SavedAccount(email: map['email'], password: map['password']);
}

class AccountService {
  // Use a per-user key to isolate switch account lists
  String get _key {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return 'saved_accounts_${uid ?? 'anonymous'}';
  }

  Future<void> saveAccount(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> currentList = prefs.getStringList(_key) ?? [];
      
      final List<SavedAccount> accounts = currentList
          .map((item) => SavedAccount.fromMap(jsonDecode(item)))
          .toList();
      
      accounts.removeWhere((a) => a.email == email);
      accounts.add(SavedAccount(email: email, password: password));
      
      await prefs.setStringList(
        _key,
        accounts.map((a) => jsonEncode(a.toMap())).toList(),
      );
    } catch (e) {
      // Fallback or ignore if SharedPreferences is not available
    }
  }

  Future<List<SavedAccount>> getSavedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> currentList = prefs.getStringList(_key) ?? [];
      return currentList
          .map((item) => SavedAccount.fromMap(jsonDecode(item)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> removeAccount(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> currentList = prefs.getStringList(_key) ?? [];
      final updatedList = currentList
          .map((item) => SavedAccount.fromMap(jsonDecode(item)))
          .where((a) => a.email != email)
          .map((a) => jsonEncode(a.toMap()))
          .toList();
      await prefs.setStringList(_key, updatedList);
    } catch (e) {}
  }
}

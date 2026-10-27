import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact.dart';
import '../models/favorite.dart';

class PersistenceService {
  static const _favoritesKey = 'favorites';
  static const _contactsKey = 'contacts';

  Future<List<FavoriteEntry>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoritesKey);
    if (raw == null) return [];

    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => FavoriteEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveFavorites(List<FavoriteEntry> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(favorites.map((f) => f.toJson()).toList());
    await prefs.setString(_favoritesKey, encoded);
  }

  Future<List<SupportContact>> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contactsKey);
    if (raw == null) return _defaultContacts;

    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SupportContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveContacts(List<SupportContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(contacts.map((c) => c.toJson()).toList());
    await prefs.setString(_contactsKey, encoded);
  }

  static const _defaultContacts = [
    SupportContact(name: 'Mom', phoneNumber: ''),
    SupportContact(name: 'Christy', phoneNumber: ''),
    SupportContact(name: 'Ms. Ghere', phoneNumber: ''),
  ];
}

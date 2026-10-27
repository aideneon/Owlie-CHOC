import 'package:flutter/foundation.dart';

import '../data/content_repository.dart';
import '../data/persistence_service.dart';
import '../models/contact.dart';
import '../models/favorite.dart';
import '../theme/intensity_colors.dart';

class AppState extends ChangeNotifier {
  AppState(this._persistence);

  final PersistenceService _persistence;

  List<FavoriteEntry> _favorites = [];
  List<SupportContact> _contacts = [];
  bool _loaded = false;

  List<FavoriteEntry> get favorites => List.unmodifiable(_favorites);
  List<SupportContact> get contacts => List.unmodifiable(_contacts);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _favorites = await _persistence.loadFavorites();
    _contacts = await _persistence.loadContacts();
    _loaded = true;
    notifyListeners();
  }

  bool isFavorite(String exerciseId) {
    return _favorites.any((f) => f.exerciseId == exerciseId);
  }

  FavoriteEntry? favoriteForExercise(String exerciseId) {
    try {
      return _favorites.firstWhere((f) => f.exerciseId == exerciseId);
    } catch (_) {
      return null;
    }
  }

  Future<void> toggleFavorite({
    required String exerciseId,
    required int intensity,
  }) async {
    final existing = favoriteForExercise(exerciseId);
    if (existing != null) {
      _favorites.remove(existing);
    } else {
      _favorites.add(
        FavoriteEntry(exerciseId: exerciseId, intensity: intensity),
      );
    }
    await _persistence.saveFavorites(_favorites);
    notifyListeners();
  }

  Future<void> removeFavorite(String exerciseId) async {
    _favorites.removeWhere((f) => f.exerciseId == exerciseId);
    await _persistence.saveFavorites(_favorites);
    notifyListeners();
  }

  Map<IntensityBand, List<FavoriteEntry>> favoritesByBand() {
    final map = {
      for (final band in IntensityBand.values) band: <FavoriteEntry>[],
    };

    for (final favorite in _favorites) {
      final band = IntensityColors.bandForLevel(favorite.intensity);
      map[band]!.add(favorite);
    }

    return map;
  }

  Future<void> updateContacts(List<SupportContact> contacts) async {
    _contacts = contacts;
    await _persistence.saveContacts(_contacts);
    notifyListeners();
  }

  Future<void> addContact(SupportContact contact) async {
    _contacts = [..._contacts, contact];
    await _persistence.saveContacts(_contacts);
    notifyListeners();
  }

  Future<void> updateContact(int index, SupportContact contact) async {
    if (index < 0 || index >= _contacts.length) return;
    _contacts = [..._contacts]..[index] = contact;
    await _persistence.saveContacts(_contacts);
    notifyListeners();
  }

  Future<void> removeContact(int index) async {
    if (index < 0 || index >= _contacts.length) return;
    _contacts = [..._contacts]..removeAt(index);
    await _persistence.saveContacts(_contacts);
    notifyListeners();
  }

  String exerciseName(String exerciseId) {
    return ContentRepository.exerciseById(exerciseId).name;
  }
}

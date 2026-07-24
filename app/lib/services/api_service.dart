import 'local_repository.dart';

class DuplicateCafeException implements Exception {
  final String message;
  final List<dynamic> candidates;
  DuplicateCafeException(this.message, this.candidates);

  @override
  String toString() => message;
}

class ApiService {
  // We forward everything to LocalRepository to avoid renaming imports globally.

  // ========== CAFE ==========
  static Future<List<dynamic>> getCafes({
    String? search, 
    List<String>? categories, 
    List<String>? areas, 
    String? city, 
    double? minRating, 
    List<String>? prices,
    String? visitStatus,
  }) async {
    return await LocalRepository.getCafes(
      search: search,
      areas: areas,
      categories: categories,
      prices: prices,
      visitStatus: visitStatus,
      minRating: minRating,
    );
  }

  static Future<Map<String, List<String>>> getFilters() async {
    return await LocalRepository.getFilters();
  }

  static Future<Map<String, dynamic>> getCafeDetail(String id) async {
    final res = await LocalRepository.getCafeDetail(id);
    if (res == null) throw Exception('Cafe tidak ditemukan');
    return res;
  }
  
  static Future<Map<String, dynamic>> addCafe(Map<String, dynamic> data) async {
    return await LocalRepository.addCafe(data);
  }

  static Future<void> updateCafe(String id, Map<String, dynamic> data) async {
    await LocalRepository.updateCafe(id, data);
  }

  static Future<void> deleteCafe(String id) async {
    await LocalRepository.deleteCafe(id);
  }

  // ========== DIARY / VISITS ==========
  static Future<Map<String, dynamic>> getMyVisits() async {
    final res = await LocalRepository.getMyVisits();
    return { 'visits': res, 'total_count': res.length };
  }

  static Future<Map<String, dynamic>> getVisitDetail(String visitId) async {
    final res = await LocalRepository.getVisitDetail(visitId);
    if (res == null) throw Exception('Visit tidak ditemukan');
    return res;
  }

  static Future<void> addVisit(Map<String, dynamic> data) async {
    final photoPath = data.remove('photo_path') as String?;
    final photoPaths = photoPath != null ? [photoPath] : <String>[];
    await LocalRepository.logVisit(data, photoPaths);
  }
  
  static Future<void> updateVisit(String visitId, Map<String, dynamic> data) async {
    final photoPath = data.remove('photo_path') as String?;
    final newPhotoPaths = photoPath != null ? [photoPath] : <String>[];
    await LocalRepository.editVisit(visitId, data, newPhotoPaths, []);
  }

  static Future<void> deleteVisit(String visitId) async {
    await LocalRepository.deleteVisit(visitId);
  }

  // ========== PROFILE ==========
  static Future<Map<String, dynamic>> getMeProfile() async {
    final prof = await LocalRepository.getProfile();
    final stats = await LocalRepository.getMyStats();
    return {
      'user': prof ?? {},
      'stats': stats['stats'],
      'taste': stats['taste'],
      'is_self': true,
    };
  }

  static Future<Map<String, dynamic>> updateMeProfile(Map<String, dynamic> data) async {
    await LocalRepository.updateProfile(data);
    return data;
  }

  // ========== LISTS ==========
  static Future<List<dynamic>> getMyLists() async {
    return await LocalRepository.getMyLists();
  }

  static Future<Map<String, dynamic>> getListDetail(String listId) async {
    final res = await LocalRepository.getListDetail(listId);
    if (res == null) throw Exception('List tidak ditemukan');
    return res;
  }

  static Future<void> createList(String title, String? description, List<String> cafeIds, Map<String, String> notes, {String? coverImagePath}) async {
    await LocalRepository.createList(title, description, cafeIds, notes, coverImagePath: coverImagePath);
  }

  static Future<void> updateList(String listId, String title, String? description, List<String> cafeIds, Map<String, String> notes, {String? coverImagePath}) async {
    await LocalRepository.updateList(listId, title, description, cafeIds, notes, coverImagePath: coverImagePath);
  }

  static Future<void> deleteList(String listId) async {
    await LocalRepository.deleteList(listId);
  }

  // ========== WATCHLIST ==========
  static Future<List<dynamic>> getWatchlist() async {
    return await LocalRepository.getWatchlist();
  }

  static Future<void> addToWatchlist(String cafeId) async {
    await LocalRepository.addToWatchlist(cafeId);
  }

  static Future<void> removeFromWatchlist(String cafeId) async {
    await LocalRepository.removeFromWatchlist(cafeId);
  }

  static Future<bool> isInWatchlist(String cafeId) async {
    return await LocalRepository.isInWatchlist(cafeId);
  }

  // ========== SEARCH ==========
  static Future<List<dynamic>> search(String query, {required String type}) async {
    if (type == 'cafe') {
      return await LocalRepository.getCafes(search: query);
    } else if (type == 'list') {
      final allLists = await LocalRepository.getMyLists();
      return allLists.where((list) => list['title'].toString().toLowerCase().contains(query.toLowerCase())).toList();
    }
    return [];
  }
}

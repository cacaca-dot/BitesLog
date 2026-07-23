import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class DuplicateCafeException implements Exception {
  final String message;
  final List<dynamic> candidates;
  DuplicateCafeException(this.message, this.candidates);

  @override
  String toString() => message;
}

class ApiService {
  // Ganti IP sesuai device kamu
  static const String baseUrl = 'http://192.168.100.186:3000/api/v1';

  // ========== LOGIN (positional parameters) ==========
  static Future<Map<String, dynamic>> login(
    String email, // ← email/username
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  // ========== UPLOAD IMAGE ==========
  static Future<String> uploadImage(String base64Image) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/uploads'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'image_base64': base64Image}),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data']['url'];
    } else {
      throw Exception('Gagal upload gambar');
    }
  }

  // ========== REGISTER (Map) ==========
  static Future<Map<String, dynamic>> register(
    Map<String, String> data, // ← sesuai panggilan kamu
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  // ========== GET TOKEN ==========
  static Future<String?> _getToken() async {
    return await AuthService.getToken();
  }

  // ========== GET CAFES ==========
  static Future<List<dynamic>> getCafes({
    String? search, 
    List<String>? categories, 
    List<String>? areas, 
    String? city, 
    double? minRating, 
    String? priceRange
  }) async {
    final token = await _getToken();
    
    final queryParams = <String>[];
    if (search != null && search.isNotEmpty) queryParams.add('search=${Uri.encodeComponent(search)}');
    if (categories != null && categories.isNotEmpty) queryParams.add('categories=${Uri.encodeComponent(categories.join(','))}');
    if (areas != null && areas.isNotEmpty) queryParams.add('areas=${Uri.encodeComponent(areas.join(','))}');
    if (city != null && city.isNotEmpty) queryParams.add('city=${Uri.encodeComponent(city)}');
    if (minRating != null) queryParams.add('min_rating=${minRating.toString()}');
    if (priceRange != null && priceRange.isNotEmpty) queryParams.add('price_range=${Uri.encodeComponent(priceRange)}');
    
    final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    final url = '$baseUrl/cafes$queryString';
        
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? [];
    } else {
      throw Exception('Gagal mengambil data cafe (Code: ${response.statusCode})');
    }
  }

  // ========== GET CAFE FILTERS ==========
  static Future<Map<String, dynamic>> getFilters() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/cafes/filters'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? {'categories': [], 'cities': []};
    } else {
      throw Exception('Gagal mengambil filter (Code: ${response.statusCode})');
    }
  }

  // ========== GET CAFE DETAIL ==========
  static Future<Map<String, dynamic>> getCafeDetail(String cafeId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/cafes/$cafeId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'];
    } else {
      throw Exception('Gagal mengambil detail cafe');
    }
  }

  // ========== GET CAFE REVIEWS ==========
  static Future<List<dynamic>> getCafeReviews(String cafeId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/cafes/$cafeId/reviews'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? [];
    } else {
      throw Exception('Gagal mengambil review cafe');
    }
  }

  // ========== GET CAFE PHOTOS ==========
  static Future<List<dynamic>> getCafePhotos(String cafeId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/cafes/$cafeId/photos'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? [];
    } else {
      throw Exception('Gagal mengambil foto cafe');
    }
  }

  // ========== GET FEED ==========
  static Future<List<dynamic>> getFeed() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/feed'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? [];
    } else {
      throw Exception('Gagal mengambil data feed: ${response.statusCode} - ${response.body}');
    }
  }

  // ========== WATCHLIST (S-14) ==========
  static Future<List<dynamic>> getWatchlist() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/watchlist'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? [];
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['error']?['message'] ?? 'Gagal mengambil data watchlist');
    }
  }

  static Future<Map<String, dynamic>> addToWatchlist(String cafeId) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/watchlist'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'cafe_id': cafeId,
      }),
    );

    final body = jsonDecode(response.body);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return body['data'] ?? {};
    } else {
      throw Exception(body['error']?['message'] ?? 'Gagal menambahkan ke watchlist');
    }
  }



  static Future<void> removeFromWatchlist(String cafeId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/watchlist/$cafeId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error']?['message'] ?? 'Gagal menghapus dari watchlist');
    }
  }

  // ========== GET MY LISTS ==========
  static Future<List<dynamic>> getMyLists() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/lists/me'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? [];
    } else {
      throw Exception('Gagal mengambil List Aku');
    }
  }

  // ========== TOGGLE SAVE LIST ==========
  static Future<Map<String, dynamic>> toggleSaveList(String listId, bool isSaved) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/lists/$listId/save');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = isSaved
        ? await http.delete(url, headers: headers)
        : await http.post(url, headers: headers);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final bodyData = jsonDecode(response.body);
      return bodyData['data'] ?? {};
    } else {
      throw Exception('Gagal toggle save list');
    }
  }

  // ========== GET SAVED LISTS ==========
  static Future<List<dynamic>> getSavedLists() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/lists/saved'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? [];
    } else {
      throw Exception('Gagal mengambil List Tersimpan');
    }
  }

  // ========== GET LIST DETAIL ==========
  static Future<Map<String, dynamic>> getListDetail(String id) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/lists/$id'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? {};
    } else {
      throw Exception('Gagal mengambil detail list');
    }
  }

  // ========== CREATE LIST ==========
  static Future<Map<String, dynamic>> createList({
    required String title,
    String? description,
    required bool isPublic,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/lists'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'is_public': isPublic,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'];
    } else {
      throw Exception('Gagal membuat list');
    }
  }

  // ========== UPDATE LIST ==========
  static Future<Map<String, dynamic>> updateList({
    required String listId,
    required String title,
    String? description,
    required bool isPublic,
  }) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/lists/$listId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'is_public': isPublic,
      }),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'];
    } else {
      throw Exception('Gagal update list');
    }
  }

  // ========== DELETE LIST ==========
  static Future<void> deleteList(String listId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/lists/$listId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Gagal menghapus list');
    }
  }

  // ========== ADD CAFE TO LIST ==========
  static Future<void> addCafeToList(String listId, String cafeId, {String? note}) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/lists/$listId/items'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'cafe_id': cafeId,
        'note': note,
      }),
    );

    if (response.statusCode != 201 && response.statusCode != 200 && response.statusCode != 409) {
      // 409 Conflict diabaikan saja (cafe sudah ada)
      throw Exception('Gagal menambah cafe ke list');
    }
  }

  // ========== REMOVE CAFE FROM LIST ==========
  static Future<void> removeCafeFromList(String listId, String cafeId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/lists/$listId/items/$cafeId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Gagal menghapus cafe dari list');
    }
  }

  // ========== SEARCH ==========
  static Future<List<dynamic>> search(String query, {String type = 'user'}) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query)}&type=$type'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return (body['data'] as List<dynamic>?) ?? [];
    } else {
      throw Exception('Gagal melakukan pencarian');
    }
  }

  // ========== REORDER CAFES ==========
  static Future<void> reorderCafes(String listId, List<String> cafeIds) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/lists/$listId/items/reorder'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'order': cafeIds}),
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal mengatur urutan cafe');
    }
  }

  // ========== UPDATE CAFE NOTE ==========
  static Future<void> updateCafeNote(String listId, String cafeId, String? note) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/lists/$listId/items/$cafeId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'note': note}),
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal memperbarui catatan');
    }
  }

  // ========== SOCIAL LIKES ==========
  static Future<Map<String, dynamic>> toggleLike(String targetType, String targetId, bool isLiked) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/likes');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      'target_type': targetType,
      'target_id': targetId,
    });

    final response = isLiked
        ? await http.delete(url, headers: headers, body: body)
        : await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final bodyData = jsonDecode(response.body);
      return bodyData['data'] ?? {};
    } else {
      throw Exception('Gagal toggle like');
    }
  }

  // ========== GET COMMENTS ==========
  static Future<List<dynamic>> getComments(String targetType, String targetId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/comments?target_type=$targetType&target_id=$targetId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? [];
    } else {
      throw Exception('Gagal mengambil komentar');
    }
  }

  // ========== ADD COMMENT ==========
  static Future<Map<String, dynamic>> addComment(String targetType, String targetId, String text, {String? parentCommentId}) async {
    final token = await _getToken();
    
    final payload = {
      'target_type': targetType,
      'target_id': targetId,
      'comment_text': text,
    };
    if (parentCommentId != null) {
      payload['parent_comment_id'] = parentCommentId;
    }
    
    final response = await http.post(
      Uri.parse('$baseUrl/comments'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 201) {
      final body = jsonDecode(response.body);
      return body['data'];
    } else {
      throw Exception('Gagal menambahkan komentar');
    }
  }

  // ========== DELETE COMMENT ==========
  static Future<void> deleteComment(String commentId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/comments/$commentId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal menghapus komentar');
    }
  }

  // ========== GET VISIT DETAIL (S-12) ==========
  static Future<Map<String, dynamic>> getVisitDetail(String id) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/visits/$id'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'];
    } else {
      throw Exception('Gagal mengambil detail kunjungan');
    }
  }

  // ========== UPDATE VISIT (S-13) ==========
  static Future<Map<String, dynamic>> updateVisit(String id, Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/visits/$id'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'];
    } else {
      throw Exception('Gagal update kunjungan: ${response.body}');
    }
  }

  // ========== DELETE VISIT (S-12) ==========
  static Future<void> deleteVisit(String id) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/visits/$id'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal menghapus kunjungan');
    }
  }

  // ========== ADD CAFE (S-07) ==========
  static Future<Map<String, dynamic>> addCafe(Map<String, dynamic> data, {bool force = false}) async {
    final token = await _getToken();
    final bodyData = Map<String, dynamic>.from(data);
    if (force) {
      bodyData['force'] = true;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/cafes'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(bodyData),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return body;
    } else if (response.statusCode == 409) {
      final candidates = body['data'] as List<dynamic>? ?? [];
      throw DuplicateCafeException(
        body['error']?['message'] ?? 'Kandidat duplikat ditemukan',
        candidates,
      );
    } else {
      throw Exception(body['error']?['message'] ?? 'Gagal menambahkan cafe');
    }
  }

  // ========== ADD VISIT (S-10) ==========
  static Future<Map<String, dynamic>> addVisit(Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/visits'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 201) {
      final body = jsonDecode(response.body);
      return body['data'];
    } else {
      throw Exception('Gagal mencatat kunjungan: ${response.body}');
    }
  }

  // ========== GET MY VISITS (DIARY S-11) ==========
  static Future<Map<String, dynamic>> getMyVisits() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/me/visits'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? {};
    } else {
      throw Exception('Gagal mengambil diary: ${response.body}');
    }
  }

  // ========== GET ME PROFILE (S-18) ==========
  static Future<Map<String, dynamic>> getMyProfile() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/me/profile'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? {};
    } else {
      throw Exception('Gagal mengambil profile: ${response.body}');
    }
  }

  // ========== GET USER PROFILE (S-18/19) ==========
  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/profile'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? {};
    } else {
      throw Exception('Gagal mengambil profile user: ${response.body}');
    }
  }

  // ========== UPDATE ME PROFILE (S-18) ==========
  static Future<Map<String, dynamic>> updateMyProfile({
    String? fullName,
    String? bio,
    String? avatarUrl,
    bool? isPrivate,
  }) async {
    final token = await _getToken();
    
    final Map<String, dynamic> reqBody = {};
    if (fullName != null) reqBody['full_name'] = fullName;
    if (bio != null) reqBody['bio'] = bio;
    if (avatarUrl != null) reqBody['avatar_url'] = avatarUrl;
    if (isPrivate != null) reqBody['is_private'] = isPrivate;

    final response = await http.put(
      Uri.parse('$baseUrl/me/profile'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(reqBody),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? {};
    } else {
      throw Exception('Gagal update profile: ${response.body}');
    }
  }

  // ========== S-19 FOLLOW / UNFOLLOW ==========
  static Future<void> followUser(String userId) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/users/$userId/follow'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Gagal follow: ${response.body}');
    }
  }

  static Future<void> unfollowUser(String userId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$userId/follow'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Gagal unfollow: ${response.body}');
    }
  }

  // ========== S-20 FOLLOWERS / FOLLOWING ==========
  static Future<List<dynamic>> getFollowers(String userId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/followers'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? [];
    } else {
      throw Exception('Gagal mengambil followers');
    }
  }

  static Future<List<dynamic>> getFollowing(String userId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/following'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? [];
    } else {
      throw Exception('Gagal mengambil following');
    }
  }

  // ========== S-19 USER VISITS & LISTS (privacy-aware) ==========
  static Future<Map<String, dynamic>> getUserVisits(String userId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/visits'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? {};
    } else {
      throw Exception('Gagal mengambil visits user');
    }
  }

  static Future<Map<String, dynamic>> getUserLists(String userId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/lists'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? {};
    } else {
      throw Exception('Gagal mengambil lists user');
    }
  }

  // ========== NOTIFICATIONS ==========
  static Future<List<dynamic>> getNotifications() async {
    final token = await _getToken();
    if (token == null) throw Exception('Belum login');
    
    final response = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? [];
    } else {
      throw Exception('Gagal mengambil notifikasi');
    }
  }

  static Future<int> getUnreadNotificationCount() async {
    final token = await _getToken();
    if (token == null) return 0;
    
    final response = await http.get(
      Uri.parse('$baseUrl/notifications/unread-count'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data']['count'] ?? 0;
    } else {
      return 0; // Silently fail for badge
    }
  }

  static Future<void> markNotificationsAsRead() async {
    final token = await _getToken();
    if (token == null) return;
    
    await http.put(
      Uri.parse('$baseUrl/notifications/read'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }
}

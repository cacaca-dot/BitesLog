import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'database_service.dart';
import 'local_auth_service.dart';

class LocalRepository {
  static final _dbService = DatabaseService.instance;
  static const _uuid = Uuid();

  static Future<String?> _saveImageLocally(String? sourcePath) async {
    if (sourcePath == null || sourcePath.isEmpty) return null;
    if (sourcePath.startsWith('http') || sourcePath.startsWith('data:')) return sourcePath;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
      final fileName = '${_uuid.v4()}$ext';
      final savedImage = File(p.join(appDir.path, fileName));
      await File(sourcePath).copy(savedImage.path);
      return fileName; // Save only the relative file name
    } catch (e) {
      print('Error saving image locally: $e');
      return null;
    }
  }

  static Future<String> getFullImagePath(String fileName) async {
    if (fileName.startsWith('http') || fileName.startsWith('data:') || fileName.startsWith('/')) {
      return fileName;
    }
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, fileName);
  }

  // ==========================================
  // PROFILE & AUTH
  // ==========================================
  static Future<String> getUserId() async {
    final id = await LocalAuthService.getCurrentUserId();
    if (id == null) throw Exception('Not logged in');
    return id;
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    final user = await LocalAuthService.getCurrentUser();
    return user?.toMap();
  }

  static Future<void> updateProfile(Map<String, dynamic> data) async {
    if (data.containsKey('avatar_url') && data['avatar_url'] != null) {
      final savedUrl = await _saveImageLocally(data['avatar_url']);
      if (savedUrl != null) data['avatar_url'] = savedUrl;
    }
    await LocalAuthService.updateProfile(data);
  }
  static void _enrichCafeMap(Map<String, dynamic> map) {
    String? rawAddress = map['address']?.toString();
    String? rawArea = map['area']?.toString();
    String? rawCity = map['city']?.toString();

    if (rawAddress != null && rawAddress.isNotEmpty) {
      if (rawArea == null || rawArea.isEmpty || rawArea == 'Unknown Area') {
        final kecMatch = RegExp(r'Kecamatan\s+([A-Za-z\s]+)(?:,|$)').firstMatch(rawAddress);
        if (kecMatch != null) rawArea = kecMatch.group(1)!.trim();
      }
      if (rawCity == null || rawCity.isEmpty || rawCity == 'Unknown City') {
        final kotaMatch = RegExp(r'(Kota|Kabupaten)\s+([A-Za-z\s]+)(?:,|$)').firstMatch(rawAddress);
        if (kotaMatch != null) rawCity = '${kotaMatch.group(1)} ${kotaMatch.group(2)!.trim()}';
      }
    }
    
    map['area'] = rawArea;
    map['city'] = rawCity ?? 'Unknown City';
  }

  static Future<Map<String, dynamic>> getMyStats() async {
    final userId = await getUserId();
    final db = await _dbService.database;
    final visitsRes = await db.query('visits', where: 'user_id = ?', whereArgs: [userId]);
    
    int totalVisits = visitsRes.length;
    Set<String> uniqueCafes = {};
    double totalRating = 0;
    int ratedVisits = 0;
    
    for (var v in visitsRes) {
      uniqueCafes.add(v['cafe_id'].toString());
      if (v['rating'] != null) {
        double r = double.tryParse(v['rating'].toString()) ?? 0.0;
        if (r > 0) {
          totalRating += r;
          ratedVisits++;
        }
      }
    }
    
    final listsRes = await db.query('lists', where: 'user_id = ?', whereArgs: [userId]);
    
    // Calculate My Taste (most frequent category)
    String? tasteTag;
    if (totalVisits > 0) {
      final query = '''
        SELECT c.categories 
        FROM visits v 
        JOIN cafes c ON v.cafe_id = c.id
        WHERE v.user_id = ?
      ''';
      final res = await db.rawQuery(query, [userId]);
      Map<String, int> categoryCounts = {};
      for (var row in res) {
        if (row['categories'] != null) {
          try {
            List<dynamic> cats = jsonDecode(row['categories'].toString());
            for (var c in cats) {
              categoryCounts[c.toString()] = (categoryCounts[c.toString()] ?? 0) + 1;
            }
          } catch (e) {
            // ignore
          }
        }
      }
      
      if (categoryCounts.isNotEmpty) {
        var sortedCats = categoryCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        String topCat = sortedCats.first.key;
        if (topCat == 'Kopi') tasteTag = 'Pecinta Kopi';
        else if (topCat == 'Brunch') tasteTag = 'Anak Brunch';
        else if (topCat == 'Dessert' || topCat == 'Kue') tasteTag = 'Sweet Tooth';
        else if (topCat == 'Makanan Berat') tasteTag = 'Foodie';
        else tasteTag = 'Cafe Hopper';
      }
    }

    return {
      'stats': {
        'total_visits': totalVisits,
        'unique_cafes': uniqueCafes.length,
        'total_lists': listsRes.length,
        'avg_rating_given': ratedVisits > 0 ? (totalRating / ratedVisits).toStringAsFixed(1) : 0,
      },
      'taste': tasteTag != null ? {'tag': tasteTag} : null
    };
  }

  // ==========================================
  // CAFES
  // ==========================================
  static Future<List<Map<String, dynamic>>> getCafes({
    String? search,
    List<String>? areas,
    List<String>? categories,
    List<String>? prices,
    String? visitStatus,
    double? minRating,
  }) async {
    final userId = await getUserId();
    final db = await _dbService.database;
    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (search != null && search.isNotEmpty) {
      where += ' AND name LIKE ?';
      whereArgs.add('%$search%');
    }
    
    if (areas != null && areas.isNotEmpty) {
      final placeholders = List.filled(areas.length, '?').join(',');
      where += ' AND area IN ($placeholders)';
      whereArgs.addAll(areas);
    }
    
    if (prices != null && prices.isNotEmpty) {
      final placeholders = List.filled(prices.length, '?').join(',');
      where += ' AND price IN ($placeholders)';
      whereArgs.addAll(prices);
    }
    
    if (categories != null && categories.isNotEmpty) {
      List<String> catConditions = [];
      for (var cat in categories) {
        catConditions.add('categories LIKE ?');
        whereArgs.add('%"$cat"%');
      }
      where += ' AND (${catConditions.join(' OR ')})';
    }

    if (visitStatus != null) {
      if (visitStatus == 'Sudah Dikunjungi') {
        where += ' AND (SELECT COUNT(*) FROM visits v WHERE v.cafe_id = c.id AND v.user_id = ?) > 0';
        whereArgs.add(userId);
      } else if (visitStatus == 'Belum Dikunjungi') {
        where += ' AND (SELECT COUNT(*) FROM visits v WHERE v.cafe_id = c.id AND v.user_id = ?) = 0';
        whereArgs.add(userId);
      }
    }

    if (minRating != null) {
      where += ' AND rating >= ?';
      whereArgs.add(minRating);
    }

    whereArgs.insert(0, userId);
    final res = await db.rawQuery('''
      SELECT c.*, c.price as price_range, c.rating as avg_rating, 
             (SELECT COUNT(*) FROM visits v WHERE v.cafe_id = c.id AND v.user_id = ?) as visit_count
      FROM cafes c
      WHERE $where
    ''', whereArgs);
    
    return res.map((row) {
      final map = Map<String, dynamic>.from(row);
      try {
        if (map['categories'] != null) {
          map['categories'] = jsonDecode(map['categories']);
        }
      } catch (e) {
        map['categories'] = [];
      }
      _enrichCafeMap(map);
      return map;
    }).toList();
  }

  static Future<Map<String, List<String>>> getFilters() async {
    final db = await _dbService.database;
    final res = await db.query('cafes', columns: ['categories', 'area']);
    final Set<String> categories = {};
    final Set<String> areas = {};
    for (var row in res) {
      if (row['area'] != null && row['area'].toString().isNotEmpty) {
        areas.add(row['area'].toString());
      }
      if (row['categories'] != null) {
        try {
          final cats = jsonDecode(row['categories'].toString());
          for (var c in cats) {
            if (c.toString().isNotEmpty) categories.add(c.toString());
          }
        } catch (_) {}
      }
    }
    return {
      'categories': categories.toList()..sort(),
      'areas': areas.toList()..sort(),
    };
  }

  static Future<Map<String, dynamic>?> getCafeDetail(String id) async {
    final userId = await getUserId();
    final db = await _dbService.database;
    final res = await db.rawQuery('''
      SELECT c.*, c.price as price_range, c.rating as avg_rating, 
             (SELECT COUNT(*) FROM visits v WHERE v.cafe_id = c.id AND v.user_id = ?) as visit_count,
             (SELECT COUNT(*) FROM watchlist w WHERE w.cafe_id = c.id AND w.user_id = ?) as in_watchlist_count
      FROM cafes c
      WHERE c.id = ?
    ''', [userId, userId, id]);
    if (res.isEmpty) return null;
    
    final cafe = Map<String, dynamic>.from(res.first);
    try {
      if (cafe['categories'] != null) cafe['categories'] = jsonDecode(cafe['categories']);
    } catch (_) { cafe['categories'] = []; }

    cafe['is_in_watchlist'] = (cafe['in_watchlist_count'] ?? 0) > 0;
    _enrichCafeMap(cafe);
    
    // Fetch user's visits (reviews) for this cafe
    final visitsRes = await db.rawQuery('''
      SELECT * FROM visits 
      WHERE cafe_id = ? AND user_id = ?
      ORDER BY visit_date DESC, created_at DESC
    ''', [id, userId]);
    
    final reviews = <Map<String, dynamic>>[];
    final photos = <Map<String, dynamic>>[];
    
    for (var v in visitsRes) {
      final visitMap = Map<String, dynamic>.from(v);
      final pRes = await db.query('visit_photos', where: 'visit_id = ?', whereArgs: [v['id']]);
      if (pRes.isNotEmpty) {
        visitMap['photos'] = pRes;
        for (var p in pRes) {
          photos.add({'url': p['photo_url']});
        }
      }
      reviews.add(visitMap);
    }
    
    cafe['reviews'] = reviews;
    cafe['photos'] = photos;
    
    return cafe;
  }
  
  static Future<Map<String, dynamic>> addCafe(Map<String, dynamic> data) async {
     final db = await _dbService.database;
     final id = _uuid.v4();
     final userId = await getUserId();
     
     String? savedImagePath;
     if (data['image_url'] != null) {
       savedImagePath = await _saveImageLocally(data['image_url']);
     }

     List<String> categoryList = [];
     if (data['categories'] != null && data['categories'].toString().isNotEmpty) {
       categoryList = data['categories'].toString().split(',');
     }

     final row = {
       'id': id,
       'name': data['name'],
       'area': data['area'],
       'city': data['city'],
       'address': data['address'],
       'categories': jsonEncode(categoryList),
       'price': data['price_range'],
       'lat': data['latitude'],
       'lng': data['longitude'],
       'rating': 0.0,
       'image_url': savedImagePath,
       'created_by': userId,
     };
     await db.insert('cafes', row);
     
     // Alias these so Cafe.fromJson parses correctly
     row['price_range'] = row['price'];
     row['avg_rating'] = row['rating'];
     row['categories'] = categoryList;
     row['visit_count'] = 0;
     
     return row;
  }
  static Future<void> updateCafe(String id, Map<String, dynamic> data) async {
     final db = await _dbService.database;
     
     final updateData = <String, dynamic>{};
     if (data.containsKey('name')) updateData['name'] = data['name'];
     if (data.containsKey('area')) updateData['area'] = data['area'];
     if (data.containsKey('city')) updateData['city'] = data['city'];
     if (data.containsKey('address')) updateData['address'] = data['address'];
     if (data.containsKey('price_range')) updateData['price'] = data['price_range'];
     if (data.containsKey('latitude')) updateData['lat'] = data['latitude'];
     if (data.containsKey('longitude')) updateData['lng'] = data['longitude'];
     
     if (data.containsKey('categories')) {
       List<String> categoryList = [];
       if (data['categories'] != null && data['categories'].toString().isNotEmpty) {
         categoryList = data['categories'].toString().split(',');
       }
       updateData['categories'] = jsonEncode(categoryList);
     }
     
     if (data.containsKey('image_url') && data['image_url'] != null) {
       updateData['image_url'] = await _saveImageLocally(data['image_url']);
     }

     await db.update('cafes', updateData, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteCafe(String id) async {
     final db = await _dbService.database;
     await db.delete('cafes', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // VISITS
  // ==========================================
  static Future<List<Map<String, dynamic>>> getMyVisits() async {
    final userId = await getUserId();
    final db = await _dbService.database;
    // Join with cafes to get cafe details
    final res = await db.rawQuery('''
      SELECT v.*, c.name as cafe_name, c.area as cafe_area, c.city as cafe_city, c.address as cafe_address, c.image_url as cafe_image
      FROM visits v
      JOIN cafes c ON v.cafe_id = c.id
      WHERE v.user_id = ?
      ORDER BY v.visit_date DESC, v.created_at DESC
    ''', [userId]);
    
    // We also need photos for each visit
    final visits = <Map<String, dynamic>>[];
    for (var row in res) {
      final visit = Map<String, dynamic>.from(row);
      final tempCafe = {
        'area': visit['cafe_area'],
        'city': visit['cafe_city'],
        'address': visit['cafe_address'],
      };
      _enrichCafeMap(tempCafe);
      visit['cafe_area'] = tempCafe['area'];
      visit['cafe_city'] = tempCafe['city'];
      
      final photosRes = await db.query('visit_photos', where: 'visit_id = ?', whereArgs: [visit['id']]);
      visit['photos'] = photosRes.map((p) => p['photo_url']).toList(); // We'll convert relative paths later in UI
      visits.add(visit);
    }
    return visits;
  }
  
  static Future<Map<String, dynamic>?> getVisitDetail(String id) async {
    final db = await _dbService.database;
    final res = await db.rawQuery('''
      SELECT v.*, c.name as cafe_name, c.area as cafe_area, c.city as cafe_city, c.address as cafe_address, c.image_url as cafe_image, c.price as cafe_price
      FROM visits v
      JOIN cafes c ON v.cafe_id = c.id
      WHERE v.id = ?
    ''', [id]);
    
    if (res.isEmpty) return null;
    final visit = Map<String, dynamic>.from(res.first);
    
    final tempCafe = {
      'area': visit['cafe_area'],
      'city': visit['cafe_city'],
      'address': visit['cafe_address'],
    };
    _enrichCafeMap(tempCafe);
    visit['cafe_area'] = tempCafe['area'];
    visit['cafe_city'] = tempCafe['city'];
    
    final photosRes = await db.query('visit_photos', where: 'visit_id = ?', whereArgs: [visit['id']]);
    visit['photos'] = photosRes; 
    return visit;
  }

  static Future<void> logVisit(Map<String, dynamic> data, List<String> photoPaths) async {
    final userId = await getUserId();
    final db = await _dbService.database;
    final visitId = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    
    await db.insert('visits', {
      'id': visitId,
      'user_id': userId,
      'cafe_id': data['cafe_id'],
      'rating': data['rating'],
      'review': data['review'],
      'favorite_drink': data['favorite_drink'],
      'price': data['price'],
      'visit_date': data['visit_date'] ?? now,
      'created_at': now,
    });

    for (var path in photoPaths) {
      final savedPath = await _saveImageLocally(path);
      if (savedPath != null) {
        await db.insert('visit_photos', {
          'id': _uuid.v4(),
          'visit_id': visitId,
          'photo_url': savedPath,
          'created_at': now,
        });
      }
    }

    await _recalculateCafeRating(data['cafe_id']);

    // Otomatis hapus dari watchlist saat user log visit
    await db.delete('watchlist', where: 'cafe_id = ? AND user_id = ?', whereArgs: [data['cafe_id'], userId]);
  }
  
  static Future<void> editVisit(String visitId, Map<String, dynamic> data, List<String> newPhotoPaths, List<String> deletedPhotoIds) async {
    final db = await _dbService.database;
    
    final updateData = <String, dynamic>{};
    if (data.containsKey('rating')) updateData['rating'] = data['rating'];
    if (data.containsKey('review')) updateData['review'] = data['review'];
    if (data.containsKey('favorite_drink')) updateData['favorite_drink'] = data['favorite_drink'];
    if (data.containsKey('price')) updateData['price'] = data['price'];
    if (data.containsKey('visit_date')) updateData['visit_date'] = data['visit_date'];
    
    if (updateData.isNotEmpty) {
      await db.update('visits', updateData, where: 'id = ?', whereArgs: [visitId]);
    }
    
    for (var pId in deletedPhotoIds) {
      await db.delete('visit_photos', where: 'id = ?', whereArgs: [pId]);
    }
    
    final now = DateTime.now().toIso8601String();
    for (var path in newPhotoPaths) {
      final savedPath = await _saveImageLocally(path);
      if (savedPath != null) {
        await db.insert('visit_photos', {
          'id': _uuid.v4(),
          'visit_id': visitId,
          'photo_url': savedPath,
          'created_at': now,
        });
      }
    }
    
    final res = await db.query('visits', columns: ['cafe_id'], where: 'id = ?', whereArgs: [visitId]);
    if (res.isNotEmpty) {
      await _recalculateCafeRating(res.first['cafe_id'].toString());
    }
  }

  static Future<void> deleteVisit(String visitId) async {
    final db = await _dbService.database;
    final res = await db.query('visits', columns: ['cafe_id'], where: 'id = ?', whereArgs: [visitId]);
    String? cafeId;
    if (res.isNotEmpty) cafeId = res.first['cafe_id'].toString();
    
    await db.delete('visits', where: 'id = ?', whereArgs: [visitId]);
    if (cafeId != null) {
      await _recalculateCafeRating(cafeId);
    }
  }

  static Future<void> _recalculateCafeRating(String cafeId) async {
    final db = await _dbService.database;
    final res = await db.rawQuery('SELECT AVG(rating) as avg_r FROM visits WHERE cafe_id = ? AND rating > 0', [cafeId]);
    
    double newRating = 0.0;
    if (res.isNotEmpty && res.first['avg_r'] != null) {
      newRating = double.tryParse(res.first['avg_r'].toString()) ?? 0.0;
    }
    
    await db.update('cafes', {'rating': newRating}, where: 'id = ?', whereArgs: [cafeId]);
  }

  // ==========================================
  // LISTS
  // ==========================================
  static Future<List<Map<String, dynamic>>> getMyLists() async {
    final userId = await getUserId();
    final db = await _dbService.database;
    final lists = await db.query('lists', where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
    
    List<Map<String, dynamic>> result = [];
    for (var list in lists) {
      var item = Map<String, dynamic>.from(list);
      final countRes = await db.rawQuery('SELECT COUNT(*) as c FROM list_items WHERE list_id = ?', [item['id']]);
      item['cafe_count'] = countRes.isNotEmpty ? countRes.first['c'] : 0;
      
      // Get first 3 cafe images
      final imagesRes = await db.rawQuery('''
        SELECT c.image_url 
        FROM list_items li
        JOIN cafes c ON li.cafe_id = c.id
        WHERE li.list_id = ?
        ORDER BY li.created_at ASC
        LIMIT 3
      ''', [item['id']]);
      item['thumbnails'] = imagesRes.map((r) => r['image_url']).where((url) => url != null).toList();
      result.add(item);
    }
    return result;
  }
  
  static Future<Map<String, dynamic>?> getListDetail(String listId) async {
    final db = await _dbService.database;
    final lists = await db.query('lists', where: 'id = ?', whereArgs: [listId]);
    if (lists.isEmpty) return null;
    
    final result = Map<String, dynamic>.from(lists.first);
    final itemsRes = await db.rawQuery('''
      SELECT li.*, c.name as cafe_name, c.area as cafe_area, c.city as cafe_city, c.address as cafe_address, c.image_url as cafe_image, c.price as cafe_price
      FROM list_items li
      JOIN cafes c ON li.cafe_id = c.id
      WHERE li.list_id = ?
      ORDER BY li.created_at ASC
    ''', [listId]);
    
    result['items'] = itemsRes.map((row) {
      final item = Map<String, dynamic>.from(row);
      final tempCafe = {
        'area': item['cafe_area'],
        'city': item['cafe_city'],
        'address': item['cafe_address'],
      };
      _enrichCafeMap(tempCafe);
      item['cafe_area'] = tempCafe['area'];
      item['cafe_city'] = tempCafe['city'];
      return item;
    }).toList();
    
    return result;
  }
  
  static Future<void> createList(String title, String? description, List<String> cafeIds, Map<String, String> notes, {String? coverImagePath}) async {
    final userId = await getUserId();
    final db = await _dbService.database;
    final listId = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    
    String? savedCover;
    if (coverImagePath != null) {
      savedCover = await _saveImageLocally(coverImagePath);
    }
    
    await db.insert('lists', {
      'id': listId,
      'user_id': userId,
      'title': title,
      'description': description,
      'cover_image': savedCover,
      'created_at': now,
    });
    
    for (var cafeId in cafeIds) {
      await db.insert('list_items', {
        'id': _uuid.v4(),
        'list_id': listId,
        'cafe_id': cafeId,
        'notes': notes[cafeId],
        'created_at': now,
      });
    }
  }
  
  static Future<void> updateList(String listId, String title, String? description, List<String> cafeIds, Map<String, String> notes, {String? coverImagePath}) async {
    final db = await _dbService.database;
    
    final updateData = <String, dynamic>{
      'title': title,
      'description': description,
    };
    
    if (coverImagePath != null) {
      // If it's a new local file, save it. If it's already a relative path or url, just keep it.
      if (coverImagePath.startsWith('/data/') || coverImagePath.contains('\\') || coverImagePath.contains('/')) {
        // Just try to save it, _saveImageLocally handles skip if it's already in docs dir
        final savedCover = await _saveImageLocally(coverImagePath);
        if (savedCover != null) updateData['cover_image'] = savedCover;
      } else {
        updateData['cover_image'] = coverImagePath; // if somehow passed just the name
      }
    }
    
    await db.update('lists', updateData, where: 'id = ?', whereArgs: [listId]);
    
    await db.delete('list_items', where: 'list_id = ?', whereArgs: [listId]);
    final now = DateTime.now().toIso8601String();
    for (var cafeId in cafeIds) {
      await db.insert('list_items', {
        'id': _uuid.v4(),
        'list_id': listId,
        'cafe_id': cafeId,
        'notes': notes[cafeId],
        'created_at': now,
      });
    }
  }
  
  static Future<void> deleteList(String listId) async {
    final db = await _dbService.database;
    await db.delete('lists', where: 'id = ?', whereArgs: [listId]);
  }

  // ==========================================
  // WATCHLIST
  // ==========================================
  static Future<List<Map<String, dynamic>>> getWatchlist() async {
    final userId = await getUserId();
    final db = await _dbService.database;
    final res = await db.rawQuery('''
      SELECT c.*, w.created_at as saved_at
      FROM watchlist w
      JOIN cafes c ON w.cafe_id = c.id
      WHERE w.user_id = ?
      ORDER BY w.created_at DESC
    ''', [userId]);
    return res.map((r) {
      final map = Map<String, dynamic>.from(r);
      _enrichCafeMap(map);
      return map;
    }).toList();
  }
  
  static Future<void> addToWatchlist(String cafeId) async {
    final userId = await getUserId();
    final db = await _dbService.database;
    final exists = await isInWatchlist(cafeId);
    if (!exists) {
      await db.insert('watchlist', {
        'id': _uuid.v4(),
        'user_id': userId,
        'cafe_id': cafeId,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
  
  static Future<void> removeFromWatchlist(String cafeId) async {
    final userId = await getUserId();
    final db = await _dbService.database;
    await db.delete('watchlist', where: 'cafe_id = ? AND user_id = ?', whereArgs: [cafeId, userId]);
  }
  
  static Future<bool> isInWatchlist(String cafeId) async {
    final userId = await getUserId();
    final db = await _dbService.database;
    final res = await db.query('watchlist', where: 'cafe_id = ? AND user_id = ?', whereArgs: [cafeId, userId]);
    return res.isNotEmpty;
  }
}

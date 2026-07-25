import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'database_service.dart';

/// Model sederhana untuk user yang sedang login
class LocalUser {
  final String id;
  final String fullName;
  final String username;
  final String email;
  final String? bio;
  final String? avatarPath;

  const LocalUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    this.bio,
    this.avatarPath,
  });

  factory LocalUser.fromMap(Map<String, dynamic> map) {
    return LocalUser(
      id: map['id'].toString(),
      fullName: map['full_name'].toString(),
      username: map['username'].toString(),
      email: map['email'].toString(),
      bio: map['bio']?.toString(),
      avatarPath: map['avatar_path']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'full_name': fullName,
    'username': username,
    'email': email,
    'bio': bio,
    'avatar_path': avatarPath,
    'avatar_url': avatarPath,
  };
}

/// Autentikasi lokal SQLite + SharedPreferences. TANPA server/internet.
class LocalAuthService {
  static const _sessionKey = 'biteslog_user_id';
  static const _uuid = Uuid();

  // ============================================================
  // REGISTER
  // ============================================================
  /// Daftarkan akun baru. Return null jika berhasil, atau pesan error jika gagal.
  static Future<String?> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {
    final db = await DatabaseService.instance.database;

    // Cek username sudah dipakai
    final existingUsername = await db.query(
      'users',
      where: 'LOWER(username) = ?',
      whereArgs: [username.toLowerCase()],
    );
    if (existingUsername.isNotEmpty) return 'Username "$username" sudah dipakai.';

    // Cek email sudah dipakai
    final existingEmail = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.toLowerCase()],
    );
    if (existingEmail.isNotEmpty) return 'Email sudah terdaftar.';

    // Hash password dengan salt acak
    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);
    final userId = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await db.insert('users', {
      'id': userId,
      'full_name': fullName,
      'username': username,
      'email': email.toLowerCase(),
      'password_hash': hash,
      'salt': salt,
      'bio': null,
      'avatar_path': null,
      'created_at': now,
    });

    // Jangan auto-login setelah register, biarkan user login manual
    // await _saveSession(userId);
    return null; // null = berhasil
  }

  // ============================================================
  // LOGIN
  // ============================================================
  /// Login dengan username atau email. Return null jika berhasil, atau pesan error.
  static Future<String?> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final db = await DatabaseService.instance.database;
    final input = usernameOrEmail.trim().toLowerCase();

    final results = await db.query(
      'users',
      where: 'LOWER(username) = ? OR LOWER(email) = ?',
      whereArgs: [input, input],
    );

    if (results.isEmpty) return 'Akun tidak ditemukan.';

    final user = results.first;
    final storedHash = user['password_hash'].toString();
    final salt = user['salt'].toString();

    if (_hashPassword(password, salt) != storedHash) {
      return 'Password salah.';
    }

    await _saveSession(user['id'].toString());
    return null; // null = berhasil
  }

  // ============================================================
  // LOGOUT
  // ============================================================
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  // ============================================================
  // CURRENT USER
  // ============================================================
  /// Cek apakah ada sesi aktif (user sudah login)
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_sessionKey);
  }

  /// Ambil user_id dari sesi aktif
  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionKey);
  }

  /// Ambil data lengkap user yang sedang login
  static Future<LocalUser?> getCurrentUser() async {
    final userId = await getCurrentUserId();
    if (userId == null) return null;

    final db = await DatabaseService.instance.database;
    final res = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (res.isEmpty) return null;

    return LocalUser.fromMap(res.first);
  }

  // ============================================================
  // UPDATE PROFIL
  // ============================================================
  static Future<void> updateProfile(Map<String, dynamic> data) async {
    final userId = await getCurrentUserId();
    if (userId == null) return;

    final db = await DatabaseService.instance.database;
    final updateData = <String, dynamic>{};
    if (data.containsKey('full_name')) updateData['full_name'] = data['full_name'];
    if (data.containsKey('username')) updateData['username'] = data['username'];
    if (data.containsKey('bio')) updateData['bio'] = data['bio'];
    if (data.containsKey('avatar_path')) updateData['avatar_path'] = data['avatar_path'];
    if (data.containsKey('avatar_url')) updateData['avatar_path'] = data['avatar_url'];

    if (updateData.isNotEmpty) {
      await db.update('users', updateData, where: 'id = ?', whereArgs: [userId]);
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================
  /// Cek apakah username tersedia (untuk validasi realtime di register)
  static Future<bool> isUsernameAvailable(String username) async {
    final db = await DatabaseService.instance.database;
    final res = await db.query(
      'users',
      where: 'LOWER(username) = ?',
      whereArgs: [username.toLowerCase()],
    );
    return res.isEmpty;
  }

  static Future<void> _saveSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, userId);
  }

  static String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }
}

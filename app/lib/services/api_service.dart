import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Ganti IP sesuai device kamu
  static const String baseUrl = 'http://localhost:3000/api/v1';

  // ========== LOGIN (positional parameters) ==========
  static Future<Map<String, dynamic>> login(
    String email,      // ← email/username
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': email,
        'password': password,
      }),
    );
    return jsonDecode(response.body);
  }

  // ========== REGISTER (Map) ==========
  static Future<Map<String, dynamic>> register(
    Map<String, String> data,   // ← sesuai panggilan kamu
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }
}
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  // Flutter Web pada komputer yang menjalankan XAMPP.
  static const String baseUrl = 'http://localhost/lapor_sarana_api';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
  };

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        'success': false,
        'message': 'Format respons server tidak sesuai.',
      };
    } on FormatException {
      return {
        'success': false,
        'message':
            'Respons server bukan JSON yang valid (HTTP ${response.statusCode}).',
      };
    }
  }

  static Future<Map<String, dynamic>> _postJson(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/$endpoint'),
          headers: _headers,
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 20));

    final result = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      result['success'] = false;
      result.putIfAbsent(
        'message',
        () => 'Permintaan gagal. Kode HTTP ${response.statusCode}.',
      );
    }

    return result;
  }

  // ================= LOGIN =================
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) {
    return _postJson('auth.php', {
      'action': 'login',
      'username': username,
      'password': password,
    });
  }

  // ================= REGISTER PELAPOR =================
  static Future<Map<String, dynamic>> register({
    required String name,
    required String username,
    required String password,
  }) {
    return _postJson('auth.php', {
      'action': 'register',
      'name': name,
      'username': username,
      'password': password,
    });
  }

  // ================= TAMBAH PENGADUAN =================
  static Future<Map<String, dynamic>> createComplaint({
    required int userId,
    required String title,
    required String location,
    required String description,
    Uint8List? photoBytes,
    String? photoName,
  }) async {
    final uri = Uri.parse('$baseUrl/complaints.php');

    // Pengaduan tanpa foto.
    if (photoBytes == null || photoBytes.isEmpty) {
      return _postJson('complaints.php', {
        'user_id': userId,
        'title': title,
        'location': location,
        'description': description,
      });
    }

    // Pengaduan dengan foto.
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..fields['user_id'] = userId.toString()
      ..fields['title'] = title
      ..fields['location'] = location
      ..fields['description'] = description
      ..files.add(
        http.MultipartFile.fromBytes(
          'photo',
          photoBytes,
          filename: photoName ?? 'foto_pengaduan.jpg',
        ),
      );

    final streamed = await request.send().timeout(const Duration(seconds: 30));

    final response = await http.Response.fromStream(streamed);
    final result = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      result['success'] = false;
      result.putIfAbsent(
        'message',
        () => 'Pengaduan gagal dikirim. HTTP ${response.statusCode}.',
      );
    }

    return result;
  }

  // ================= AMBIL DAFTAR PENGADUAN =================
  static Future<Map<String, dynamic>> getComplaints({
    required int userId,
    required String role,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/complaints.php',
    ).replace(queryParameters: {'user_id': userId.toString(), 'role': role});

    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));

    final result = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      result['success'] = false;
      result.putIfAbsent(
        'message',
        () => 'Gagal mengambil pengaduan. HTTP ${response.statusCode}.',
      );
    }

    return result;
  }

  // ================= UPDATE STATUS OLEH ADMIN =================
  static Future<Map<String, dynamic>> updateComplaintStatus({
    required int adminId,
    required int complaintId,
    required String status,
    required String response,
  }) {
    return _postJson('complaints.php', {
      'action': 'update_status',
      'admin_id': adminId,
      'complaint_id': complaintId,
      'status': status,
      'response': response,
    });
  }
}

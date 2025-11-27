import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;

import '../models/appointment.dart';
import '../models/clinic.dart';
import '../models/fine.dart';
import '../models/support_message.dart';
import '../models/user.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  final String _baseUrl =
      Platform.isAndroid ? 'http://192.168.8.121:8050/api' : 'http://192.168.8.121:8050/api';
  String? _token;

  void updateToken(String? token) {
    _token = token;
  }

  Map<String, String> _headers({bool authorized = true}) {
    final headers = {'Content-Type': 'application/json'};
    if (authorized && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: _headers(authorized: false),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: _headers(authorized: false),
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'phone': phone,
      }),
    );
    return _decode(response);
  }

  Future<AppUser> fetchProfile() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: _headers(),
    );
    final data = _decode(response);
    return AppUser.fromJson(data);
  }

  Future<List<Appointment>> fetchAppointments({
    DateTime? from,
    DateTime? to,
    String? doctorId,
  }) async {
    final query = <String, String>{};
    if (from != null && to != null) {
      query['from'] = from.toIso8601String();
      query['to'] = to.toIso8601String();
    }
    if (doctorId != null) query['doctorId'] = doctorId;

    final uri = Uri.parse('$_baseUrl/appointments').replace(queryParameters: query);
    final response = await http.get(uri, headers: _headers());
    final data = _decode(response) as List<dynamic>;
    return data.map((json) => Appointment.fromJson(json)).toList();
  }

  Future<Appointment?> fetchNextAppointment() async {
    final now = DateTime.now();
    final inThirtyDays = now.add(const Duration(days: 30));
    final appointments = await fetchAppointments(from: now, to: inThirtyDays);
    if (appointments.isEmpty) return null;
    appointments.sort((a, b) => a.startTime.compareTo(b.startTime));
    return appointments.firstWhere(
      (appointment) => appointment.startTime.isAfter(now),
      orElse: () => appointments.first,
    );
  }

  Future<void> confirmAppointment(String appointmentId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/appointments/$appointmentId/confirm'),
      headers: _headers(),
    );
    _decode(response);
  }

  Future<String> cancelAppointment(String appointmentId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/appointments/$appointmentId/cancel'),
      headers: _headers(),
    );

    if (response.statusCode == 403) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(data['message'] ?? 'Отмена недоступна', statusCode: 403);
    }

    final data = _decode(response);
    return data['status'] ?? 'cancelled';
  }

  Future<List<Clinic>> fetchClinics({
    double? lat,
    double? lon,
  }) async {
    final query = <String, String>{};
    if (lat != null && lon != null) {
      query['lat'] = lat.toString();
      query['lon'] = lon.toString();
    }

    final uri = Uri.parse('$_baseUrl/clinics').replace(
      queryParameters: query.isEmpty ? null : query,
    );
    final response = await http.get(uri, headers: _headers());
    final data = _decode(response) as List<dynamic>;
    return data.map((json) => Clinic.fromJson(json)).toList();
  }

  Future<List<Fine>> fetchFines() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/fines'),
      headers: _headers(),
    );
    final data = _decode(response) as List<dynamic>;
    return data.map((json) => Fine.fromJson(json)).toList();
  }

  Future<void> sendSupportMessage(String content) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/support'),
      headers: _headers(),
      body: jsonEncode({'content': content}),
    );
    _decode(response);
  }

  Future<List<SupportMessage>> fetchSupportMessages({String? status}) async {
    final query = <String, String>{};
    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }
    final uri = Uri.parse('$_baseUrl/support').replace(
      queryParameters: query.isEmpty ? null : query,
    );
    final response = await http.get(uri, headers: _headers());
    final data = _decode(response) as List<dynamic>;
    return data.map((json) => SupportMessage.fromJson(json)).toList();
  }

  Future<void> updateSupportMessageStatus(
    String messageId, {
    required String status,
    String? assignedTo,
  }) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/support/$messageId'),
      headers: _headers(),
      body: jsonEncode({'status': status, 'assignedTo': assignedTo}),
    );
    _decode(response);
  }

  Future<List<AppUser>> fetchUsers({String? role}) async {
    final uri = Uri.parse('$_baseUrl/users').replace(
      queryParameters: role != null ? {'role': role} : null,
    );
    final response = await http.get(uri, headers: _headers());
    final data = _decode(response) as List<dynamic>;
    return data.map((json) => AppUser.fromJson(json)).toList();
  }

  Future<AppUser> createUser({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users'),
      headers: _headers(),
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'role': role,
        'phone': phone,
      }),
    );
    final data = _decode(response);
    return AppUser.fromJson(data);
  }

  Future<String> fetchAiTip() async {
    final response = await http.post(
      Uri.parse('$_baseUrl/gemini/ask'),
      headers: _headers(authorized: false),
      body: jsonEncode({
        'prompt':
            'Поделись коротким советом (одно предложение) по уходу за зубами на русском языке.',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['response'] ??
          'Улыбка ярче, если чистить зубы не менее двух минут дважды в день.';
    }

    return 'Не удалось получить совет от ИИ.';
  }

  dynamic _decode(http.Response response) {
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final message = body is Map<String, dynamic> && body['message'] != null
        ? body['message'] as String
        : 'Ошибка сервера (${response.statusCode})';
    throw ApiException(message, statusCode: response.statusCode);
  }
}

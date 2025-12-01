import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;

import '../models/appointment.dart';
import '../models/clinic.dart';
import '../models/fine.dart';
import '../models/slot.dart';
import '../models/medical_record.dart';
import '../models/profile_summary.dart';
import '../models/review.dart';
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
      Platform.isAndroid ? 'http://192.168.0.14:8050/api' : 'http://192.168.0.14:8050/api';
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
    final filtered = appointments
        .where(
          (a) =>
              (a.status == 'scheduled' || a.status == 'confirmed') &&
              a.startTime.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (filtered.isEmpty) return null;
    return filtered.first;
  }

  Future<Appointment> confirmAppointment(String appointmentId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/appointments/$appointmentId/confirm'),
      headers: _headers(),
    );
    final data = _decode(response);
    return Appointment.fromJson(data);
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

  Future<SupportMessage> sendSupportMessage(String content) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/support'),
      headers: _headers(),
      body: jsonEncode({'content': content}),
    );
    final data = _decode(response);
    return SupportMessage.fromJson(data);
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

  Future<List<SupportMessage>> fetchMySupportThreads() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/support/my'),
      headers: _headers(),
    );
    final data = _decode(response) as List<dynamic>;
    return data.map((json) => SupportMessage.fromJson(json)).toList();
  }

  Future<SupportMessage> replySupportMessage({
    required String messageId,
    required String content,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/support/$messageId/reply'),
      headers: _headers(),
      body: jsonEncode({'content': content}),
    );
    final data = _decode(response);
    return SupportMessage.fromJson(data);
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

  Future<List<AppUser>> fetchDoctors() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/doctors'),
      headers: _headers(),
    );
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

  Future<List<Slot>> fetchSlots({String? doctorId, String? status}) async {
    final query = <String, String>{};
    if (doctorId != null) query['doctorId'] = doctorId;
    if (status != null) query['status'] = status;
    final uri = Uri.parse('$_baseUrl/appointments/slots')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _headers());
    final data = _decode(response) as List<dynamic>;
    return data.map((json) => Slot.fromJson(json)).toList();
  }

  Future<void> createSlot({
    required String doctorId,
    required String clinicId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/appointments/slots'),
      headers: _headers(),
      body: jsonEncode({
        'doctorId': doctorId,
        'clinicId': clinicId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
      }),
    );
    _decode(response);
  }

  Future<void> deleteSlot(String slotId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/appointments/slots/$slotId'),
      headers: _headers(),
    );
    _decode(response);
  }

  Future<Appointment> bookSlot({
    required Slot slot,
    required String service,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/appointments'),
      headers: _headers(),
      body: jsonEncode({
        'slotId': slot.id,
        'doctorId': slot.doctorId,
        'clinicId': slot.clinicId,
        'startTime': slot.startTime.toIso8601String(),
        'service': service,
      }),
    );
    final data = _decode(response);
    return Appointment.fromJson(data);
  }

  Future<Map<String, dynamic>> fetchStatsOverview() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/stats/overview'),
      headers: _headers(),
    );
    return _decode(response) as Map<String, dynamic>;
  }

  Future<RoleProfileSummary> fetchRoleProfileSummary() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/profile/overview'),
      headers: _headers(),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return RoleProfileSummary.fromJson(data);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/change-password'),
      headers: _headers(),
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    _decode(response);
  }

  Future<AppUser> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    int? experienceYears,
    List<String>? services,
    List<String>? specialties,
    String? bio,
  }) async {
    final payload = <String, dynamic>{};
    if (firstName != null) payload['firstName'] = firstName;
    if (lastName != null) payload['lastName'] = lastName;
    if (phone != null && phone.isNotEmpty) payload['phone'] = phone;
    if (experienceYears != null) payload['experienceYears'] = experienceYears;
    if (services != null) payload['services'] = services;
    if (specialties != null) payload['specialties'] = specialties;
    if (bio != null) payload['bio'] = bio;

    final response = await http.patch(
      Uri.parse('$_baseUrl/auth/me'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    final data = _decode(response);
    return AppUser.fromJson(data);
  }

  Future<AppUser> updateDoctorByAdmin({
    required String userId,
    String? firstName,
    String? lastName,
    String? phone,
    int? experienceYears,
    List<String>? services,
    List<String>? specialties,
    String? bio,
  }) async {
    final payload = <String, dynamic>{};
    if (firstName != null) payload['firstName'] = firstName;
    if (lastName != null) payload['lastName'] = lastName;
    if (phone != null) payload['phone'] = phone;
    if (experienceYears != null) payload['experienceYears'] = experienceYears;
    if (services != null) payload['services'] = services;
    if (specialties != null) payload['specialties'] = specialties;
    if (bio != null) payload['bio'] = bio;

    final response = await http.patch(
      Uri.parse('$_baseUrl/users/$userId'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    final data = _decode(response);
    return AppUser.fromJson(data);
  }

  Future<void> updateClinic(String clinicId, Map<String, dynamic> payload) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/clinics/$clinicId'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    _decode(response);
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

  Future<Map<String, dynamic>> generateClinicQr(String clinicId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/clinics/$clinicId/qr'),
      headers: _headers(),
    );
    return _decode(response) as Map<String, dynamic>;
  }

  Future<Appointment> confirmAppointmentByQr(String payload) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/appointments/qr-confirm'),
      headers: _headers(),
      body: jsonEncode({'payload': payload}),
    );
    final data = _decode(response);
    return Appointment.fromJson(data);
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
  Future<List<MedicalRecord>> fetchMyMedicalRecords() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/records/mine'),
      headers: _headers(),
    );
    final data = _decode(response) as List<dynamic>;
    return data.map((json) => MedicalRecord.fromJson(json)).toList();
  }

  Future<List<MedicalRecord>> fetchMedicalRecords(String patientId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/records/$patientId'),
      headers: _headers(),
    );
    final data = _decode(response) as List<dynamic>;
    return data.map((json) => MedicalRecord.fromJson(json)).toList();
  }

  Future<MedicalRecord> createMedicalRecord({
    required String patientId,
    required String title,
    String? description,
    String? appointmentId,
    List<String>? tags,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/records'),
      headers: _headers(),
      body: jsonEncode({
        'patientId': patientId,
        'appointmentId': appointmentId,
        'title': title,
        'description': description,
        'tags': tags?.join(','),
      }),
    );
    final data = _decode(response);
    return MedicalRecord.fromJson(data);
  }

  Future<MedicalRecord> updateMedicalRecord({
    required String recordId,
    String? title,
    String? description,
    List<String>? tags,
  }) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/records/$recordId'),
      headers: _headers(),
      body: jsonEncode({
        'title': title,
        'description': description,
        if (tags != null) 'tags': tags,
      }),
    );
    final data = _decode(response);
    return MedicalRecord.fromJson(data);
  }

  Future<List<Review>> fetchDoctorReviews(String doctorId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/reviews/doctor/$doctorId'),
      headers: _headers(),
    );
    final data = _decode(response) as List<dynamic>;
    return data.map((json) => Review.fromJson(json)).toList();
  }

  Future<void> submitReview({
    required String appointmentId,
    required int rating,
    String? comment,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/reviews'),
      headers: _headers(),
      body: jsonEncode({
        'appointmentId': appointmentId,
        'rating': rating,
        'comment': comment,
      }),
    );
    _decode(response);
  }
}
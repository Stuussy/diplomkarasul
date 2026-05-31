import 'dart:convert';
import 'dart:io' show Platform, File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/appointment.dart';
import '../models/app_notification.dart';
import '../models/clinic.dart';
import '../models/fine.dart';
import '../models/slot.dart';
import '../models/medical_record.dart';
import '../models/profile_summary.dart';
import '../models/review.dart';
import '../models/support_message.dart';
import '../models/treatment_plan.dart';
import '../models/user.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({String? baseUrl}) : _baseUrl = baseUrl ?? _defaultBaseUrl();

  final String _baseUrl;
  String? _token;

  static const _prodBaseUrl = 'https://diplomkarasul.onrender.com/api';
  // Set SIMULATOR=true when running on Xcode Simulator:
  // flutter run --dart-define=SIMULATOR=true
  static const _isSimulator = bool.fromEnvironment('SIMULATOR', defaultValue: false);

  static String _defaultBaseUrl() {
    const env = String.fromEnvironment('API_BASE_URL');
    if (env.isNotEmpty) return env;
    if (kIsWeb) return 'http://localhost:8050/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:8050/api';
    if (Platform.isIOS) {
      // iOS Simulator uses localhost; real device uses prod
      return _isSimulator ? 'http://localhost:8050/api' : _prodBaseUrl;
    }
    return 'http://localhost:8050/api';
  }

  void updateToken(String? token) {
    _token = token;
  }

  Map<String, String> _headers({bool authorized = true, bool json = true}) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (authorized && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<http.Response> _sendMultipart(
    String path, {
    Map<String, String> fields = const {},
    List<File>? files,
    bool authorized = true,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl$path'));
    request.headers.addAll(_headers(authorized: authorized, json: false));
    request.fields.addAll(fields);
    if (files != null) {
      for (final file in files) {
        request.files.add(
          await http.MultipartFile.fromPath('files', file.path),
        );
      }
    }
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
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

  Future<void> requestPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/forgot-password'),
      headers: _headers(authorized: false),
      body: jsonEncode({'email': email}),
    );
    _decode(response);
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/reset-password'),
      headers: _headers(authorized: false),
      body: jsonEncode({
        'email': email,
        'code': code,
        'newPassword': newPassword,
      }),
    );
    _decode(response);
  }

  Future<Map<String, dynamic>> bootstrapDirector({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String bootstrapSecret,
    String? phone,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/bootstrap-director'),
      headers: _headers(authorized: false),
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'phone': phone,
        'bootstrapSecret': bootstrapSecret,
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

    final uri = Uri.parse(
      '$_baseUrl/appointments',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _headers());
    final data = _decode(response) as List<dynamic>;
    return data.map((json) => Appointment.fromJson(json)).toList();
  }

  Future<Appointment?> fetchNextAppointment() async {
    final now = DateTime.now();
    final inThirtyDays = now.add(const Duration(days: 30));
    final appointments = await fetchAppointments(from: now, to: inThirtyDays);
    final filtered =
        appointments
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

  Future<Appointment> completeAppointment(String appointmentId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/appointments/$appointmentId/complete'),
      headers: _headers(),
    );
    final data = _decode(response);
    return Appointment.fromJson(data);
  }

  Future<Appointment> markAppointmentNoShow(String appointmentId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/appointments/$appointmentId/no-show'),
      headers: _headers(),
    );
    final data = _decode(response);
    return Appointment.fromJson(data);
  }

  /// Cancels an appointment. Returns `true` if a late-cancel fine was issued.
  Future<bool> cancelAppointment(String appointmentId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/appointments/$appointmentId/cancel'),
      headers: _headers(),
    );
    final data = _decode(response);
    return data is Map<String, dynamic> && data['fineIssued'] == true;
  }

  Future<List<Clinic>> fetchClinics({
    double? lat,
    double? lon,
    String? status,
  }) async {
    final query = <String, String>{};
    if (lat != null && lon != null) {
      query['lat'] = lat.toString();
      query['lon'] = lon.toString();
    }
    if (status != null) {
      query['status'] = status;
    }

    final uri = Uri.parse(
      '$_baseUrl/clinics',
    ).replace(queryParameters: query.isEmpty ? null : query);
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

  Future<void> payFine(String fineId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/fines/$fineId/pay'),
      headers: _headers(),
    );
    _decode(response);
  }

  Future<Map<String, dynamic>> seedSlots({required String untilDate}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/seed-slots'),
      headers: _headers(),
      body: jsonEncode({'untilDate': untilDate}),
    );
    return _decode(response) as Map<String, dynamic>;
  }

  Future<SupportMessage> sendSupportMessage(
    String content, {
    required String category,
    List<File>? files,
  }) async {
    final response = await _sendMultipart(
      '/support',
      fields: {'content': content, 'category': category},
      files: files,
    );
    final data = _decode(response);
    return SupportMessage.fromJson(data);
  }

  Future<List<SupportMessage>> fetchSupportMessages({String? status}) async {
    final query = <String, String>{};
    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }
    final uri = Uri.parse(
      '$_baseUrl/support',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _headers());
    final data = _decode(response) as List<dynamic>;
    return data.map((json) => SupportMessage.fromJson(json)).toList();
  }

  Future<List<AppNotification>> fetchNotifications({bool unreadOnly = false}) async {
    final query = <String, String>{};
    if (unreadOnly) query['unread'] = 'true';
    final uri = Uri.parse('$_baseUrl/notifications')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _headers());
    final data = _decode(response) as List<dynamic>;
    return data.map((json) => AppNotification.fromJson(json)).toList();
  }

  Future<void> markNotificationRead(String id) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/notifications/$id/read'),
      headers: _headers(),
    );
    _decode(response);
  }

  Future<void> markAllNotificationsRead() async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/notifications/read-all'),
      headers: _headers(),
    );
    _decode(response);
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
    final uri = Uri.parse(
      '$_baseUrl/users',
    ).replace(queryParameters: role != null ? {'role': role} : null);
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
    List<String>? specialties,
    List<String>? clinics,
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
        if (specialties != null && specialties.isNotEmpty) 'specialties': specialties,
        if (clinics != null && clinics.isNotEmpty) 'clinics': clinics,
      }),
    );
    final data = _decode(response);
    return AppUser.fromJson(data);
  }

  Future<List<Slot>> fetchSlots({String? doctorId, String? status}) async {
    final query = <String, String>{};
    if (doctorId != null) query['doctorId'] = doctorId;
    if (status != null) query['status'] = status;
    final uri = Uri.parse(
      '$_baseUrl/appointments/slots',
    ).replace(queryParameters: query.isEmpty ? null : query);
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

  Future<Map<String, dynamic>> fetchGoogleCalendarStatus() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/google-calendar/status'),
      headers: _headers(),
    );
    return _decode(response) as Map<String, dynamic>;
  }

  Future<String> getGoogleCalendarConnectUrl() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/google-calendar/connect'),
      headers: _headers(),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return data['url']?.toString() ?? '';
  }

  Future<void> disconnectGoogleCalendar() async {
    final response = await http.post(
      Uri.parse('$_baseUrl/google-calendar/disconnect'),
      headers: _headers(),
    );
    _decode(response);
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

  Future<void> updateUserStatus(String userId, bool isActive) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/users/$userId/status'),
      headers: _headers(),
      body: jsonEncode({'isActive': isActive}),
    );
    _decode(response);
  }

  Future<void> updateClinic(
    String clinicId,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/clinics/$clinicId'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    _decode(response);
  }

  Future<Clinic> createClinic(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/clinics'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    final data = _decode(response);
    return Clinic.fromJson(data);
  }

  Future<Clinic> addClinicService(
    String clinicId,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/clinics/$clinicId/services'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    final data = _decode(response);
    return Clinic.fromJson(data);
  }

  Future<Clinic> updateClinicService(
    String clinicId,
    String serviceId,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/clinics/$clinicId/services/$serviceId'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    final data = _decode(response);
    return Clinic.fromJson(data);
  }

  Future<Clinic> deleteClinicService(String clinicId, String serviceId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/clinics/$clinicId/services/$serviceId'),
      headers: _headers(),
    );
    final data = _decode(response);
    return Clinic.fromJson(data);
  }

  Future<Clinic> addClinicDoctor(String clinicId, String doctorId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/clinics/$clinicId/doctors'),
      headers: _headers(),
      body: jsonEncode({'doctorId': doctorId}),
    );
    final data = _decode(response);
    return Clinic.fromJson(data);
  }

  Future<Clinic> removeClinicDoctor(String clinicId, String doctorId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/clinics/$clinicId/doctors/$doctorId'),
      headers: _headers(),
    );
    final data = _decode(response);
    return Clinic.fromJson(data);
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
    List<ToothMark>? toothMap,
    double? price,
    List<File>? files,
  }) async {
    final response = await _sendMultipart(
      '/records',
      fields: {
        'patientId': patientId,
        if (appointmentId != null) 'appointmentId': appointmentId,
        'title': title,
        if (description != null) 'description': description,
        if (tags != null) 'tags': tags.join(','),
        if (toothMap != null)
          'toothMap': jsonEncode(toothMap.map((t) => t.toJson()).toList()),
        if (price != null) 'price': price.toString(),
      },
      files: files,
    );
    final data = _decode(response);
    return MedicalRecord.fromJson(data);
  }

  Future<void> deleteMedicalRecord(String recordId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/records/$recordId'),
      headers: _headers(),
    );
    _decode(response);
  }

  Future<MedicalRecord> updateMedicalRecord({
    required String recordId,
    String? title,
    String? description,
    List<String>? tags,
    List<ToothMark>? toothMap,
    double? price,
  }) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/records/$recordId'),
      headers: _headers(),
      body: jsonEncode({
        'title': title,
        'description': description,
        if (tags != null) 'tags': tags,
        if (toothMap != null)
          'toothMap': toothMap.map((t) => t.toJson()).toList(),
        if (price != null) 'price': price,
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

  /// Отзывы о клинике в целом (агрегация по всем врачам) + сводка.
  Future<ClinicReviews> fetchClinicReviews({int limit = 10}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/reviews/clinic?limit=$limit'),
      headers: _headers(),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return ClinicReviews.fromJson(data);
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

  // ---- Планы лечения (Treatment Plans) ----

  /// Генерирует черновик плана лечения через ИИ (не сохраняет).
  Future<TreatmentPlan> generateTreatmentPlan({
    required String complaint,
    String? patientId,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/treatment-plans/ai-generate'),
      headers: _headers(),
      body: jsonEncode({
        'complaint': complaint,
        if (patientId != null) 'patientId': patientId,
      }),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return TreatmentPlan.fromJson(data);
  }

  Future<TreatmentPlan> createTreatmentPlan({
    required String patientId,
    required String title,
    String? diagnosis,
    String? summary,
    required List<TreatmentStep> steps,
    bool aiGenerated = false,
    String status = 'active',
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/treatment-plans'),
      headers: _headers(),
      body: jsonEncode({
        'patientId': patientId,
        'title': title,
        if (diagnosis != null) 'diagnosis': diagnosis,
        if (summary != null) 'summary': summary,
        'steps': steps.map((s) => s.toJson()).toList(),
        'aiGenerated': aiGenerated,
        'status': status,
      }),
    );
    final data = _decode(response);
    return TreatmentPlan.fromJson(data);
  }

  Future<List<TreatmentPlan>> fetchMyTreatmentPlans() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/treatment-plans/mine'),
      headers: _headers(),
    );
    final data = _decode(response) as List<dynamic>;
    return data.map((json) => TreatmentPlan.fromJson(json)).toList();
  }

  Future<List<TreatmentPlan>> fetchTreatmentPlans(String patientId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/treatment-plans/patient/$patientId'),
      headers: _headers(),
    );
    final data = _decode(response) as List<dynamic>;
    return data.map((json) => TreatmentPlan.fromJson(json)).toList();
  }

  Future<TreatmentPlan> updateTreatmentStepStatus({
    required String planId,
    required String stepId,
    required String status,
  }) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/treatment-plans/$planId/steps/$stepId'),
      headers: _headers(),
      body: jsonEncode({'status': status}),
    );
    final data = _decode(response);
    return TreatmentPlan.fromJson(data);
  }

  Future<TreatmentPlan> updateTreatmentPlan({
    required String planId,
    String? title,
    String? summary,
    String? status,
    List<TreatmentStep>? steps,
  }) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/treatment-plans/$planId'),
      headers: _headers(),
      body: jsonEncode({
        if (title != null) 'title': title,
        if (summary != null) 'summary': summary,
        if (status != null) 'status': status,
        if (steps != null) 'steps': steps.map((s) => s.toJson()).toList(),
      }),
    );
    final data = _decode(response);
    return TreatmentPlan.fromJson(data);
  }

  Future<void> deleteTreatmentPlan(String planId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/treatment-plans/$planId'),
      headers: _headers(),
    );
    _decode(response);
  }

  Future<String> aiConsult(String question) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/ai/consult'),
      headers: _headers(),
      body: jsonEncode({'question': question}),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return data['answer']?.toString() ?? '';
  }

  /// История диалога с ИИ. Возвращает список пар {role, content}.
  Future<List<AiHistoryMessage>> fetchAiHistory() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/ai/history'),
      headers: _headers(),
    );
    final data = _decode(response) as List<dynamic>;
    return data
        .map((e) => AiHistoryMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Очистить историю диалога с ИИ.
  Future<void> clearAiHistory() async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/ai/history'),
      headers: _headers(),
    );
    _decode(response);
  }
}

/// Одно сообщение из истории ИИ-консультации.
class AiHistoryMessage {
  AiHistoryMessage({required this.role, required this.content});
  final String role; // 'user' | 'assistant'
  final String content;

  bool get isUser => role == 'user';

  factory AiHistoryMessage.fromJson(Map<String, dynamic> json) => AiHistoryMessage(
        role: json['role']?.toString() ?? 'assistant',
        content: json['content']?.toString() ?? '',
      );
}

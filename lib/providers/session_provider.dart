import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/api_service.dart';

class SessionProvider extends ChangeNotifier {
  SessionProvider(this._apiService) {
    _restoreSession();
  }

  final ApiService _apiService;
  AppUser? _user;
  String? _token;
  bool _isLoading = true;

  int _bookingVersion = 0;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _user != null;
  AppUser? get user => _user;
  ApiService get apiService => _apiService;
  int get bookingVersion => _bookingVersion;

  void notifyBooked() {
    _bookingVersion++;
    notifyListeners();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');

    if (_token != null) {
      _apiService.updateToken(_token);
      try {
        _user = await _apiService.fetchProfile();
      } catch (_) {
        _token = null;
        await prefs.remove('token');
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    try {
      final result = await _apiService.login(email, password);
      await _persistSession(result);
      return null;
    } catch (error) {
      return _extractMessage(error);
    }
  }

  Future<String?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final result = await _apiService.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        phone: phone,
      );
      await _persistSession(result);
      return null;
    } catch (error) {
      return _extractMessage(error);
    }
  }

  Future<void> refreshProfile() async {
    if (_token == null) return;
    _user = await _apiService.fetchProfile();
    notifyListeners();
  }

  Future<String?> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    int? experienceYears,
    List<String>? services,
    List<String>? specialties,
    String? bio,
  }) async {
    try {
      final updated = await _apiService.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        experienceYears: experienceYears,
        services: services,
        specialties: specialties,
        bio: bio,
      );
      _user = updated;
      notifyListeners();
      return null;
    } catch (error) {
      return _extractMessage(error);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _token = null;
    _user = null;
    _apiService.updateToken(null);
    notifyListeners();
  }

  Future<void> _persistSession(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    _token = payload['token'] as String?;
    if (_token != null) {
      await prefs.setString('token', _token!);
      _apiService.updateToken(_token);
    }
    _user = AppUser.fromJson(payload['user'] as Map<String, dynamic>);
    notifyListeners();
  }

  String _extractMessage(Object error) {
    return error is ApiException ? error.message : 'Не удалось выполнить запрос.';
  }
}

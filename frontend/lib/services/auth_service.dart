import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';
import '../demo/demo_mode.dart';
import '../demo/demo_data.dart';
import '../models/profile.dart';
import 'api_client.dart';
import 'supabase_service.dart';

/// Thrown by [AuthService.signIn] when the backend requires an OTP step
/// (either `REQUIRE_LOGIN_OTP` is on, or this is a new device). The caller
/// should navigate to an OTP screen and call [AuthService.verifyOtp].
class OtpRequiredException implements Exception {
  final String transientToken;
  OtpRequiredException(this.transientToken);
}

/// Thrown after a successful driver login when the driver hasn't completed
/// their profile setup yet (home/work GPS coordinates not set).
class ProfileIncompleteException implements Exception {
  final Profile profile;
  ProfileIncompleteException(this.profile);
}

class AuthService extends ChangeNotifier {
  Profile? _currentProfile;
  Profile? get currentProfile => _currentProfile;

  SupabaseClient get _client => SupabaseService.instance.client;
  ApiClient get _api => ApiClient.instance;

  /// Legacy Supabase auth user - only populated in demo mode is null, and in
  /// live mode this is now always null since auth runs against the new
  /// backend instead of Supabase auth. Retained for screens not yet migrated.
  User? getCurrentUser() => DemoMode.active ? null : _client.auth.currentUser;

  /// Works in both demo and live mode.
  String? get currentUserId => _currentProfile?.id ?? getCurrentUser()?.id;

  Future<Profile> signIn(String email, String password) async {
    if (DemoMode.active) {
      final profileId = DemoMode.authenticate(email, password);
      if (profileId == null) throw Exception('Invalid email or password');
      final profile = DemoData.profiles[profileId]!;
      _currentProfile = profile;
      notifyListeners();
      return profile;
    }

    try {
      final response = await _api.post('/auth/login', body: {
        'email': email.trim(),
        'password': password,
        'deviceId': _api.deviceId,
        'deviceType': ApiConfig.deviceType,
      });
      final data = response['data'] as Map<String, dynamic>;

      if (data['requiresOtp'] == true) {
        throw OtpRequiredException(data['transientToken'] as String);
      }

      return await _applyLoginResult(data);
    } on OtpRequiredException {
      rethrow;
    } on ProfileIncompleteException {
      rethrow;
    } on ApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Connection refused')) {
        throw Exception('Network error. Check your connection.');
      }
      throw Exception('Sign in failed. Try again.');
    }
  }

  /// Completes login after an [OtpRequiredException] using the 6-digit code
  /// emailed to the user.
  Future<Profile> verifyOtp(String transientToken, String code) async {
    try {
      final response = await _api.post('/auth/login/verify-otp', body: {
        'transientToken': transientToken,
        'code': code,
        'deviceId': _api.deviceId,
        'deviceType': ApiConfig.deviceType,
      });
      return await _applyLoginResult(response['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<Profile> _applyLoginResult(Map<String, dynamic> data) async {
    final tokens = data['tokens'] as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>;

    await _api.setSession(
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
      user: user,
    );

    final profile = Profile.fromJson(user);
    if (profile.isDriver && !profile.isApproved) {
      await _api.clearSession();
      throw Exception('Your account is pending admin approval. Please wait.');
    }

    _currentProfile = profile;
    notifyListeners();

    if (profile.isDriver && !profile.isProfileComplete) {
      throw ProfileIncompleteException(profile);
    }

    return profile;
  }

  Future<void> signOut() async {
    if (DemoMode.active) {
      _currentProfile = null;
      notifyListeners();
      return;
    }
    try {
      final refreshToken = _api.refreshToken;
      if (refreshToken != null) {
        await _api.post('/auth/logout', body: {'refreshToken': refreshToken});
      }
    } catch (_) {
      // Best-effort: still clear local session even if the server call fails.
    }
    await _api.clearSession();
    _currentProfile = null;
    notifyListeners();
  }

  Future<Profile?> getCurrentProfile() async {
    if (DemoMode.active) return _currentProfile;
    if (_currentProfile != null) return _currentProfile;
    if (!_api.isLoggedIn) return null;

    try {
      final response = await _api.get('/auth/me');
      _currentProfile = Profile.fromJson(response['data'] as Map<String, dynamic>);
      notifyListeners();
      return _currentProfile;
    } on ApiException catch (e) {
      if (e.statusCode == 401) await _api.clearSession();
      return null;
    } catch (_) {
      // Network error (SocketException, timeout) — keep session, show login.
      return null;
    }
  }

  Future<void> registerDriver({
    required String email,
    required String password,
    required String fullName,
    required String? phone,
  }) async {
    if (DemoMode.active) {
      // In demo mode, simulate signup by adding to pending list.
      DemoData.pendingUsers.add({
        'id': 'pending-${DateTime.now().millisecondsSinceEpoch}',
        'full_name': fullName.trim(),
        'email': email.trim(),
        'phone': phone?.trim() ?? '',
        'role': 'driver',
        'is_approved': false,
      });
      notifyListeners();
      return;
    }
    try {
      await _api.post('/auth/register', body: {
        'email': email.trim(),
        'password': password,
        'fullName': fullName.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      });
    } on ApiException catch (e) {
      throw Exception(_extractApiError(e));
    }
  }

  Future<Profile> completeDriverProfile({
    required double homeLat,
    required double homeLng,
    String? homeAddress,
    required double workSiteLat,
    required double workSiteLng,
    String? workSiteName,
  }) async {
    try {
      final response = await _api.patch('/users/me/complete-profile', body: {
        'homeLat': homeLat,
        'homeLng': homeLng,
        if (homeAddress != null && homeAddress.isNotEmpty) 'homeAddress': homeAddress,
        'workSiteLat': workSiteLat,
        'workSiteLng': workSiteLng,
        if (workSiteName != null && workSiteName.isNotEmpty) 'workSiteName': workSiteName,
      });
      final updatedUser = response['data'] as Map<String, dynamic>;
      final profile = Profile.fromJson(updatedUser);
      _currentProfile = profile;
      notifyListeners();
      return profile;
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Extracts first human-readable message from a zod validation ApiException.
  /// Falls back to e.message ("Validation failed") if no field errors present.
  String _extractApiError(ApiException e) {
    final fieldErrors = e.details?['fieldErrors'] as Map<String, dynamic>?;
    if (fieldErrors != null) {
      for (final errors in fieldErrors.values) {
        if (errors is List && errors.isNotEmpty) {
          return errors.first.toString();
        }
      }
    }
    final formErrors = e.details?['formErrors'] as List?;
    if (formErrors != null && formErrors.isNotEmpty) {
      return formErrors.first.toString();
    }
    return e.message;
  }

  Future<List<Map<String, dynamic>>> fetchPendingDrivers() async {
    if (DemoMode.active) return List.from(DemoData.pendingUsers);
    try {
      final response = await _api.get('/users', query: {
        'role': 'DRIVER',
        'isApproved': 'false',
        'pageSize': '100',
      });
      final list = response['data'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> approveDriver(String driverId) async {
    if (DemoMode.active) {
      DemoData.pendingUsers.removeWhere((u) => u['id'] == driverId);
      notifyListeners();
      return;
    }
    try {
      await _api.patch('/users/$driverId/approve', body: {});
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }
}

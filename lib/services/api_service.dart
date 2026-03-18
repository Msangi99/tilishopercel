import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://duka.hisgc.net';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // ─── Token Management ───

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return jsonDecode(userJson);
    }
    return null;
  }

  static Future<void> _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ─── Auth Headers ───

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── API Calls ───

  /// Login with username and password.
  /// Returns the user data on success, throws on failure.
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['status'] == 'success') {
      // Check if user role is staff (not admin)
      final userRole = data['data']['user']['role']?.toString().toLowerCase() ?? '';
      final isAdmin = data['data']['user']['is_admin'] ?? false;
      
      if (userRole != 'staff' || isAdmin) {
        throw Exception('Hii ni akaunti ya Admin. Tafadhali tumia admin portal.');
      }
      
      await _saveToken(data['data']['token']);
      await _saveUser(data['data']['user']);
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Imeshindikana kuingia');
    }
  }

  /// Logout — revoke token on server and clear local storage.
  static Future<void> logout() async {
    try {
      final headers = await _authHeaders();
      await http.post(
        Uri.parse('$baseUrl/api/logout'),
        headers: headers,
      );
    } catch (_) {
      // Even if the server call fails, clear local auth
    }
    await _clearAuth();
  }

  /// Get current user info from the server.
  static Future<Map<String, dynamic>> getUser() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/user'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        // Update cached user data
        await _saveUser(data['data']['user']);
        return data['data'];
      }
    }

    if (response.statusCode == 401) {
      await _clearAuth();
      throw Exception('Session imeisha, tafadhali ingia tena');
    }

    throw Exception('Imeshindikana kupata taarifa');
  }

  /// Update current user profile. Only include fields to change.
  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? username,
    String? password,
    String? passwordConfirmation,
  }) async {
    final headers = await _authHeaders();
    final body = <String, dynamic>{};
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;
    if (username != null && username.isNotEmpty) body['username'] = username;
    if (password != null && password.isNotEmpty) {
      body['password'] = password;
      body['password_confirmation'] = passwordConfirmation ?? password;
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/api/user'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success' && data['data']?['user'] != null) {
        await _saveUser(data['data']['user']);
        return data['data'];
      }
    }

    if (response.statusCode == 401) {
      await _clearAuth();
      throw Exception('Session imeisha, tafadhali ingia tena');
    }

    final err = jsonDecode(response.body);
    throw Exception(err['message'] ?? 'Imeshindikana kusasisha wasifu');
  }

  /// Check if current user is staff
  static Future<bool> isStaff() async {
    try {
      final user = await getUser();
      final role = user['user']['role'] ?? '';
      final isAdmin = user['user']['is_admin'] ?? false;
      return role.toLowerCase() == 'staff' && !isAdmin;
    } catch (e) {
      return false;
    }
  }

  /// Check if current user is admin
  static Future<bool> isAdmin() async {
    try {
      final user = await getUser();
      final isAdmin = user['user']['is_admin'] ?? false;
      final role = user['user']['role'] ?? '';
      return isAdmin || role.toLowerCase() == 'admin';
    } catch (e) {
      return false;
    }
  }

  /// Get current user role
  static Future<String> getUserRole() async {
    try {
      final user = await getUser();
      return user['user']['role'] ?? 'staff';
    } catch (e) {
      return 'staff';
    }
  }

  // ─── Parcel Management ───

  /// Get parcels created by the current user (staff).
  /// [date] optional Y-m-d; if null, backend uses today.
  static Future<Map<String, dynamic>> getMyParcels({int page = 1, String? date}) async {
    final headers = await _authHeaders();
    var url = '$baseUrl/api/parcels/my?page=$page';
    if (date != null && date.isNotEmpty) {
      url += '&date=$date';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return data['data'];
      }
    }

    if (response.statusCode == 401) {
      await _clearAuth();
      throw Exception('Session imeisha, tafadhali ingia tena');
    }

    throw Exception('Imeshindikana kupata parcels');
  }

  /// Create a new parcel
  static Future<Map<String, dynamic>> createParcel({
    required String senderName,
    required String senderPhone,
    required String receiverName,
    required String receiverPhone,
    required String origin,
    required String destination,
    required double amount,
    String? description,
    String? travelDate,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/parcels'),
      headers: headers,
      body: jsonEncode({
        'sender_name': senderName,
        'sender_phone': senderPhone,
        'receiver_name': receiverName,
        'receiver_phone': receiverPhone,
        'origin': origin,
        'destination': destination,
        'amount': amount,
        'description': description,
        if (travelDate != null) 'travel_date': travelDate,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return data['data'];
      }
    }

    if (response.statusCode == 401) {
      await _clearAuth();
      throw Exception('Session imeisha, tafadhali ingia tena');
    }

    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Imeshindikana kuunda parcel');
  }

  /// Scan parcel using tracking number
  static Future<Map<String, dynamic>> scanParcel(String trackingNumber) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/parcels/scan'),
      headers: headers,
      body: jsonEncode({
        'tracking_number': trackingNumber,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return data['data'];
      }
    }

    if (response.statusCode == 401) {
      await _clearAuth();
      throw Exception('Session imeisha, tafadhali ingia tena');
    }

    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Imeshindikana kuscan parcel');
  }

  /// View parcel details by tracking number without changing its status.
  static Future<Map<String, dynamic>> viewParcel(String trackingNumber) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/parcels/view/$trackingNumber'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return data['data'];
      }
    }

    if (response.statusCode == 401) {
      await _clearAuth();
      throw Exception('Session imeisha, tafadhali ingia tena');
    }

    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Imeshindikana kupata parcel');
  }

  /// Assign transporter (selected worker on current staff's assigned bus) to a parcel.
  static Future<Map<String, dynamic>> assignTransporter(
    String trackingNumber, {
    required String workerName,
    required String workerRole,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/parcels/assign-transporter'),
      headers: headers,
      body: jsonEncode({
        'tracking_number': trackingNumber,
        'worker_name': workerName,
        'worker_role': workerRole,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return data['data'];
      }
    }

    if (response.statusCode == 401) {
      await _clearAuth();
      throw Exception('Session imeisha, tafadhali ingia tena');
    }

    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Imeshindikana kuhifadhi usafirishaji');
  }

  /// Assign receiver (current staff) to a parcel.
  static Future<Map<String, dynamic>> assignReceiver(String trackingNumber) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/parcels/assign-receiver'),
      headers: headers,
      body: jsonEncode({'tracking_number': trackingNumber}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return data['data'];
      }
    }

    if (response.statusCode == 401) {
      await _clearAuth();
      throw Exception('Session imeisha, tafadhali ingia tena');
    }

    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Imeshindikana kupokea parcel');
  }

  /// Get available buses
  static Future<List<dynamic>> getBuses() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/buses'),
      headers: headers,
    );

    if (response.statusCode == 401) {
      await _clearAuth();
      throw Exception('Session imeisha, tafadhali ingia tena');
    }

    if (response.statusCode == 200) {
      final decoded = _parseJson(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Imeshindikana kupata buses (jibu lisilotarajiwa)');
      }
      final data = decoded;
      final status = data['status'] ?? data['Status'];
      if (status != 'success') {
        final msg = data['message'] ?? 'Imeshindikana kupata buses';
        throw Exception(msg);
      }
      final dataPayload = data['data'] ?? data['Data'];
      if (dataPayload is List) return List<dynamic>.from(dataPayload);
      if (dataPayload is Map) {
        final buses = dataPayload['buses'] ?? dataPayload['Buses'];
        if (buses is List) return List<dynamic>.from(buses);
      }
      return [];
    }

    final err = _parseJson(response.body);
    final msg = err is Map ? err['message'] : null;
    throw Exception(msg ?? 'Imeshindikana kupata buses (${response.statusCode})');
  }

  /// Get available routes
  static Future<List<dynamic>> getRoutes() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/routes'),
      headers: headers,
    );

    if (response.statusCode == 401) {
      await _clearAuth();
      throw Exception('Session imeisha, tafadhali ingia tena');
    }

    if (response.statusCode == 200) {
      final decoded = _parseJson(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Imeshindikana kupata routes (jibu lisilotarajiwa)');
      }
      final data = decoded;
      final status = data['status'] ?? data['Status'];
      if (status != 'success') {
        final msg = data['message'] ?? 'Imeshindikana kupata routes';
        throw Exception(msg);
      }
      final dataPayload = data['data'] ?? data['Data'];
      if (dataPayload is List) return List<dynamic>.from(dataPayload);
      if (dataPayload is Map) {
        final routes = dataPayload['routes'] ?? dataPayload['Routes'];
        if (routes is List) return List<dynamic>.from(routes);
      }
      return [];
    }

    final err = _parseJson(response.body);
    final msg = err is Map ? err['message'] : null;
    throw Exception(msg ?? 'Imeshindikana kupata routes (${response.statusCode})');
  }

  static dynamic _parseJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// Get dashboard statistics.
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/dashboard'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return data['data'];
      }
    }

    if (response.statusCode == 401) {
      await _clearAuth();
      throw Exception('Session imeisha, tafadhali ingia tena');
    }

    throw Exception('Imeshindikana kupata takwimu');
  }
}

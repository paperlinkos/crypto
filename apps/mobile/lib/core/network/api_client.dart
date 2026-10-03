import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/constants.dart';
import '../storage/secure_storage.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final dynamic details;

  ApiException({
    required this.message,
    required this.statusCode,
    this.details,
  });

  @override
  String toString() => message;
}

class ApiClient {
  final SecureStorageService _storage;
  String _baseUrl = AppConstants.defaultApiBaseUrl;

  ApiClient({SecureStorageService? storage})
      : _storage = storage ?? SecureStorageService();

  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<dynamic> get(String endpoint, {bool requiresAuth = true, Map<String, String>? queryParams}) async {
    var uri = Uri.parse('$_baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final headers = await _getHeaders(requiresAuth: requiresAuth);
    final response = await http.get(uri, headers: headers);
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, {dynamic body, bool requiresAuth = true, Map<String, String>? customHeaders}) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    final response = await http.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> patch(String endpoint, {dynamic body, bool requiresAuth = true}) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final headers = await _getHeaders(requiresAuth: requiresAuth);

    final response = await http.patch(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint, {bool requiresAuth = true}) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final headers = await _getHeaders(requiresAuth: requiresAuth);

    final response = await http.delete(uri, headers: headers);
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decoded;
    try {
      if (response.body.isNotEmpty) {
        decoded = jsonDecode(response.body);
      }
    } catch (_) {
      decoded = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String errorMsg = 'An unexpected error occurred (${response.statusCode})';
    if (decoded is Map && decoded['message'] != null) {
      if (decoded['message'] is List) {
        errorMsg = (decoded['message'] as List).join(', ');
      } else {
        errorMsg = decoded['message'].toString();
      }
    }

    throw ApiException(
      message: errorMsg,
      statusCode: response.statusCode,
      details: decoded,
    );
  }
}

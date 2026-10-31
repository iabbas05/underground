import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'i18n.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, this.status);

  @override
  String toString() => message;
}

List<Map<String, dynamic>> asMaps(dynamic v) =>
    (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

Map<String, dynamic> asMap(dynamic v) => Map<String, dynamic>.from(v as Map);

double dbl(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// Who is signed in. Saved on the device so the app opens straight to the home screen.
class Session {
  static String? token;
  static Map<String, dynamic>? user;
  static final ValueNotifier<bool> signedIn = ValueNotifier<bool>(false);

  static bool get isAdmin => user?['role'] == 'admin';
  static int? get branchId => user?['branch_id'] as int?;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('lang');
    if (lang == 'ar' || lang == 'en') langNotifier.value = lang!;
    token = prefs.getString('token');
    final saved = prefs.getString('user');
    if (token != null && saved != null) {
      user = asMap(jsonDecode(saved));
      try {
        await Lookups.load();
        signedIn.value = true;
      } on ApiException catch (e) {
        // 401 already cleared the session. Offline: still open the app.
        if (e.status != 401) signedIn.value = true;
      }
    }
  }

  static Future<void> start(String newToken, Map<String, dynamic> newUser) async {
    token = newToken;
    user = newUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', newToken);
    await prefs.setString('user', jsonEncode(newUser));
    try {
      await Lookups.load();
    } catch (_) {}
    signedIn.value = true;
  }

  static Future<void> end() async {
    token = null;
    user = null;
    Lookups.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    signedIn.value = false;
  }

  static Future<void> setLang(String lang) async {
    langNotifier.value = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', lang);
  }
}

/// Branches and plans are small lists we load once after sign-in.
class Lookups {
  static List<Map<String, dynamic>> branches = [];
  static List<Map<String, dynamic>> plans = [];

  static List<Map<String, dynamic>> get gymBranches =>
      branches.where((b) => b['kind'] == 'gym').toList();

  static Future<void> load() async {
    branches = asMaps(await Api.get('/api/branches'));
    plans = asMaps(await Api.get('/api/plans'));
  }

  static void clear() {
    branches = [];
    plans = [];
  }

  static Map<String, dynamic>? branch(int? id) {
    for (final b in branches) {
      if (b['id'] == id) return b;
    }
    return null;
  }
}

class Api {
  static Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    var uri = Uri.parse('$apiBase$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final req = http.Request(method, uri);
    req.headers['Content-Type'] = 'application/json';
    if (auth && Session.token != null) {
      req.headers['Authorization'] = 'Bearer ${Session.token}';
    }
    if (body != null) req.body = jsonEncode(body);

    http.Response res;
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 20));
      res = await http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException(tr('err_network'), 0);
    }

    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    final message = (data is Map && data['error'] is String)
        ? data['error'] as String
        : 'Error ${res.statusCode}';
    if (res.statusCode == 401 && auth) await Session.end();
    throw ApiException(message, res.statusCode);
  }

  static Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  static Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = true}) =>
      _send('POST', path, body: body, auth: auth);

  static Future<dynamic> put(String path, Map<String, dynamic> body) =>
      _send('PUT', path, body: body);

  static Future<dynamic> delete(String path) => _send('DELETE', path);
}

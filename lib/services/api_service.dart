import 'dart:convert';
import 'dart:io';

class ApiResult {
  const ApiResult({required this.code, required this.msg, this.data});

  final String code;
  final String msg;
  final dynamic data;

  bool get success => code == '0';

  factory ApiResult.fromJson(Map<String, dynamic> json) {
    return ApiResult(
      code: json['code']?.toString() ?? json['Code']?.toString() ?? '',
      msg: json['msg']?.toString() ?? json['Msg']?.toString() ?? '',
      data: json['data'] ?? json['Data'],
    );
  }
}

class ApiService {
  ApiService({this.baseUrl = 'http://101.201.215.20:8000'});

  final String baseUrl;

  Future<ApiResult> login({
    required String username,
    required String password,
    required String deviceId,
    required String os,
    required String deviceType,
    required String deviceName,
  }) {
    return post('/api/client/login', body: {
      'username': username,
      'password': password,
      'deviceId': deviceId,
      'os': os,
      'deviceType': deviceType,
      'deviceName': deviceName,
    });
  }

  Future<ApiResult> register({
    required String username,
    required String password,
    required String deviceId,
    required String email,
    String? inviteCode,
    String? verifyCode,
  }) {
    return post('/api/client/register', body: {
      'username': username,
      'password': password,
      'deviceId': deviceId,
      'email': email,
      if (inviteCode != null) 'inviteCode': inviteCode,
      if (verifyCode != null) 'verifyCode': verifyCode,
    });
  }

  Future<ApiResult> resetPassword({
    required String email,
    required String newPassword,
    required String verifyCode,
  }) {
    return post('/api/client/reset-password', body: {
      'email': email,
      'newPassword': newPassword,
      'verifyCode': verifyCode,
    });
  }

  Future<ApiResult> sendCode(String email, {String? token}) {
    return post('/api/client/send-code', token: token, body: {'email': email});
  }

  Future<ApiResult> createOauthLoginTask({
    required String provider,
    required String deviceId,
    required String os,
    required String deviceType,
    required String deviceName,
    String? redirectUri,
  }) {
    return post('/api/client/task/create', body: {
      'provider': provider,
      'deviceId': deviceId,
      'os': os,
      'deviceType': deviceType,
      'deviceName': deviceName,
      if (redirectUri != null && redirectUri.isNotEmpty)
        'redirectUri': redirectUri,
    });
  }

  Future<ApiResult> pollOauthLogin(String taskId) {
    final query = Uri(queryParameters: {'taskId': taskId}).query;
    return get('/api/client/task/result?$query');
  }

  Future<void> completeOauthCallback({
    required String code,
    required String state,
  }) async {
    final query = Uri(queryParameters: {'code': code, 'state': state}).query;
    await getRaw('/api/client/oauth/callback?$query');
  }

  Future<ApiResult> getUserInfo(String token) {
    return get('/api/client/user-info', token: token);
  }

  Future<ApiResult> updateUserInfo({
    required String token,
    String? nick,
    String? country,
    String? username,
    String? verifyCode,
  }) {
    return post('/api/client/update-user-info', token: token, body: {
      if (nick != null) 'nick': nick,
      if (country != null) 'country': country,
      if (username != null) 'username': username,
      if (verifyCode != null) 'verifyCode': verifyCode,
    });
  }

  Future<ApiResult> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) {
    return post('/api/client/change-password', token: token, body: {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
  }

  Future<ApiResult> lineList(String token) {
    return get('/api/client/line-list', token: token);
  }

  Future<ApiResult> activityRankList(String token) {
    return get('/api/client/activity-rank-list', token: token);
  }

  Future<ApiResult> paymentOrders(String token) {
    return get('/api/client/payment/orders', token: token);
  }

  Future<ApiResult> orderStatusBySubmitToken(String submitToken, String token) {
    return get("/api/client/payment/orderStatusBySubmitToken?submitToken=$submitToken", token: token);
  }

  Future<ApiResult> orderStatus(String orderNo, String token) {
    return get('/api/client/payment/orderStatus?orderNo=$orderNo', token: token);
  }

  Future<ApiResult> joinActivity(String token, String auditLink) {
    return post('/api/client/activity-join',
        token: token, body: {'auditLink': auditLink});
  }

  Future<ApiResult> get(String path, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      if (token != null && token.isNotEmpty) {
        request.headers.add('token', token);
      }
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return _decodeResult(text);
    } finally {
      client.close();
    }
  }

  Future<String> getRaw(String path, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      if (token != null && token.isNotEmpty) {
        request.headers.add('token', token);
      }
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}: $text', uri: uri);
      }
      return text;
    } finally {
      client.close();
    }
  }

  Future<ApiResult> post(String path,
      {String? token, Map<String, String>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      if (token != null && token.isNotEmpty) {
        request.headers.add('token', token);
      }
      request.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      final payload = Uri(queryParameters: body ?? {}).query;
      request.write(payload);
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return _decodeResult(text);
    } finally {
      client.close();
    }
  }

  ApiResult _decodeResult(String text) {
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) {
      return ApiResult.fromJson(decoded);
    }
    return ApiResult(code: '-1', msg: 'Unexpected response', data: decoded);
  }
}

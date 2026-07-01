import 'dart:io';

import 'package:dio/dio.dart';

import 'dio_factory.dart';

/// Injects Emby device identification and optional access token on every request.
class EmbyAuthInterceptor extends Interceptor {
  EmbyAuthInterceptor({required this.deviceInfo, this.accessToken});

  final EmbyDeviceInfo deviceInfo;
  String? accessToken;

  void updateToken(String? token) => accessToken = token;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[HttpHeaders.authorizationHeader] = deviceInfo.authorizationHeader;
    final token = accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['X-Emby-Token'] = token;
    }
    handler.next(options);
  }
}

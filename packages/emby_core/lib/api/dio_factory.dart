import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../auth/emby_request_context.dart';
import 'emby_auth_interceptor.dart';

/// Device identification sent in Emby `Authorization` / `X-Emby-Authorization` headers.
class EmbyDeviceInfo {
  const EmbyDeviceInfo({
    this.clientName = 'EmbyPlayer',
    required this.deviceName,
    required this.deviceId,
    this.version = '1.0.0',
  });

  final String clientName;
  final String deviceName;
  final String deviceId;
  final String version;

  String get authorizationHeader =>
      'MediaBrowser Client="$clientName", Device="$deviceName", DeviceId="$deviceId", Version="$version"';
}

/// Normalizes a user-supplied server URL for Dio [BaseOptions.baseUrl].
String normalizeEmbyBaseUrl(String url) {
  var trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
    trimmed = 'http://$trimmed';
  }
  while (trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

/// Factory for configured [Dio] instances used by [EmbyApiService].
class DioFactory {
  DioFactory._();

  static Dio create({
    required String baseUrl,
    required EmbyDeviceInfo deviceInfo,
    String? accessToken,
    List<Interceptor> extraInterceptors = const [],
    bool allowSelfSignedCertificates = true,
    int connectTimeoutMs = 30000,
    int receiveTimeoutMs = 30000,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: normalizeEmbyBaseUrl(baseUrl),
        connectTimeout: Duration(milliseconds: connectTimeoutMs),
        receiveTimeout: Duration(milliseconds: receiveTimeoutMs),
        sendTimeout: Duration(milliseconds: connectTimeoutMs),
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 600,
        headers: {HttpHeaders.acceptHeader: 'application/json'},
      ),
    );

    dio.interceptors.add(
      EmbyAuthInterceptor(deviceInfo: deviceInfo, accessToken: accessToken),
    );
    dio.interceptors.addAll(extraInterceptors);

    if (allowSelfSignedCertificates) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) {
            if (host == 'localhost' || host == '127.0.0.1') return true;
            if (host.startsWith('192.168.') || host.startsWith('10.')) return true;
            if (host.startsWith('172.')) {
              final second = int.tryParse(host.split('.')[1]);
              if (second != null && second >= 16 && second <= 31) return true;
            }
            return false;
          };
          return client;
        },
      );
    }

    return dio;
  }

  static Dio createWithContext({
    required String baseUrl,
    required EmbyRequestContext context,
    String? accessToken,
  }) {
    return create(
      baseUrl: baseUrl,
      deviceInfo: EmbyDeviceInfo(
        clientName: context.clientName,
        deviceName: context.deviceName,
        deviceId: context.deviceId,
        version: context.clientVersion,
      ),
      accessToken: accessToken,
    );
  }
}

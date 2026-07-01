import 'package:emby_core/api/dio_factory.dart';
import 'package:emby_core/api/emby_api_service.dart';
import 'package:emby_core/api/emby_endpoints.dart';
import 'package:emby_core/auth/emby_request_context.dart';
import 'package:emby_core/models/authentication_result.dart';

/// High-level authentication against an Emby server.
class EmbyAuthService {
  EmbyAuthService({EmbyRequestContext? context})
      : context = context ?? EmbyRequestContext();

  final EmbyRequestContext context;

  /// Probe server without credentials.
  Future<Map<String, dynamic>> probePublic(String baseUrl) async {
    final dio = DioFactory.createWithContext(baseUrl: baseUrl, context: context);
    final response = await dio.get<Map<String, dynamic>>(EmbyEndpoints.systemInfoPublic);
    if (response.statusCode != 200 || response.data == null) {
      throw StateError('Server probe failed: HTTP ${response.statusCode}');
    }
    return response.data!;
  }

  /// Authenticate and return [AuthenticationResult].
  Future<AuthenticationResult> authenticateByName({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final dio = DioFactory.createWithContext(baseUrl: baseUrl, context: context);
    final api = EmbyApiService(dio: dio, userId: null);
    return api.authenticate(username, password);
  }
}

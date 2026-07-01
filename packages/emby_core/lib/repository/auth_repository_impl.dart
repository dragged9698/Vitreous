import 'package:emby_core/auth/emby_auth_service.dart';
import 'package:emby_core/auth/emby_request_context.dart';
import 'package:emby_core/models/authentication_result.dart';
import 'package:emby_core/repository/auth_repository.dart';

/// In-memory auth repository suitable for tests and CLI smoke tools.
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository({EmbyRequestContext? context})
      : _auth = EmbyAuthService(context: context);

  final EmbyAuthService _auth;

  String? _serverUrl;
  String? _accessToken;
  String? _userId;
  String? _username;

  @override
  Future<AuthenticationResult> authenticate(
    String serverUrl,
    String username,
    String password,
  ) async {
    final result = await _auth.authenticateByName(
      baseUrl: serverUrl,
      username: username,
      password: password,
    );
    _serverUrl = serverUrl;
    _accessToken = result.accessToken;
    _userId = result.user?.id;
    _username = username;
    return result;
  }

  @override
  Future<bool> isAuthenticated() async => _accessToken != null && _accessToken!.isNotEmpty;

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getUserId() async => _userId;

  @override
  Future<void> logout() async {
    _serverUrl = null;
    _accessToken = null;
    _userId = null;
    _username = null;
  }

  String? get serverUrl => _serverUrl;
  String? get username => _username;
}

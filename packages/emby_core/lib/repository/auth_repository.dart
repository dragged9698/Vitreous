import 'package:emby_core/models/authentication_result.dart';

/// Credential persistence contract for Emby authentication.
abstract interface class AuthRepository {
  Future<AuthenticationResult> authenticate(String serverUrl, String username, String password);

  Future<bool> isAuthenticated();

  Future<String?> getAccessToken();

  Future<String?> getUserId();

  Future<void> logout();
}

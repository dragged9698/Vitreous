/// Standalone Emby REST API client (auth, DTOs, repositories).
library;

export 'api/dio_factory.dart';
export 'api/emby_api_service.dart';
export 'api/emby_auth_interceptor.dart';
export 'api/emby_endpoints.dart';
export 'auth/emby_auth_service.dart';
export 'auth/emby_request_context.dart';
export 'models/authentication_result.dart';
export 'models/base_item_dto.dart';
export 'models/chapter_info.dart';
export 'models/media_source_info.dart';
export 'models/media_stream.dart';
export 'models/playback_info.dart';
export 'models/query_result.dart';
export 'models/user_dto.dart';
export 'models/user_item_data.dart';
export 'repository/auth_repository.dart';
export 'repository/auth_repository_impl.dart';
export 'repository/media_repository.dart';

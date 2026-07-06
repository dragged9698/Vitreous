import '../utils/app_logger.dart';
import '../utils/log_redaction_manager.dart';

/// Structured diagnostics for decypharr / virtual-mount playback issues.
/// Grep logs for `[EmbyPlayback]`.
void logEmbyPlayback(String stage, Map<String, Object?> fields) {
  appLogger.i('[EmbyPlayback] $stage', error: fields);
}

bool _hasUrl(Object? raw) {
  return raw is String && raw.trim().isNotEmpty;
}

/// Key MediaSource flags without dumping full JSON.
Map<String, Object?> embyMediaSourceDebugFields(Map<String, dynamic> source) {
  final path = source['Path'];
  return {
    'supportsDirectPlay': source['SupportsDirectPlay'],
    'supportsDirectStream': source['SupportsDirectStream'],
    'supportsTranscoding': source['SupportsTranscoding'],
    'requiresOpening': source['RequiresOpening'],
    'requiresClosing': source['RequiresClosing'],
    'isRemote': source['IsRemote'],
    'hasOpenToken': _hasUrl(source['OpenToken']),
    'liveStreamId': source['LiveStreamId'],
    'mediaSourceId': source['Id'],
    'size': source['Size'],
    'container': source['Container'],
    'path': path is String ? path : null,
    'hasDirectStreamUrl': _hasUrl(source['DirectStreamUrl']),
    'hasTranscodingUrl': _hasUrl(source['TranscodingUrl']),
    'transcodeReasons': source['TranscodeReasons'],
    'directStreamUrl': embyRedactStreamUrl(source['DirectStreamUrl'] as String?),
    'transcodingUrl': embyRedactStreamUrl(source['TranscodingUrl'] as String?),
  };
}

String embyRedactStreamUrl(String? url) {
  if (url == null || url.trim().isEmpty) return '(none)';
  return LogRedactionManager.redact(url);
}

/// Query flags on the resolved URL MPV will open.
Map<String, Object?> embyResolvedUrlDebugFields(String? url) {
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null) {
    return {'url': url == null ? '(null)' : embyRedactStreamUrl(url)};
  }
  return {
    'url': embyRedactStreamUrl(url),
    'static': uri.queryParameters['Static'],
    'liveStreamId': uri.queryParameters['LiveStreamId'],
    'mediaSourceId': uri.queryParameters['MediaSourceId'],
    'playSessionId': uri.queryParameters['PlaySessionId'] != null ? '(set)' : null,
    'startTimeTicks': uri.queryParameters['StartTimeTicks'],
    'pathSuffix': uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null,
  };
}

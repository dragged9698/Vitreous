import 'tracker_constants.dart';

class TrackerApiException implements Exception {
  final TrackerService service;
  final int statusCode;
  final String body;

  const TrackerApiException({required this.service, required this.statusCode, required this.body});

  /// Trakt returns HTTP 423 when the user's collection exceeds 100k items.
  bool get isAccountLocked => statusCode == 423;

  @override
  String toString() => 'TrackerApiException(${service.name}, HTTP $statusCode): $body';
}

class TrackerAuthException implements Exception {
  final TrackerService service;
  final String message;
  final int? statusCode;
  final bool isPermanent;

  const TrackerAuthException({required this.service, required this.message, this.statusCode, this.isPermanent = false});

  @override
  String toString() => 'TrackerAuthException(${service.name}): $message';
}

class TrackerRateLimitException implements Exception {
  final TrackerService service;
  final int? retryAfterSeconds;

  const TrackerRateLimitException({required this.service, this.retryAfterSeconds});

  @override
  String toString() => 'TrackerRateLimitException(${service.name}, retry-after: $retryAfterSeconds s)';
}

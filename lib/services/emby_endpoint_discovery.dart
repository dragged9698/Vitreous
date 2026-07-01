import 'dart:async';

import 'package:http/http.dart' as http;

import '../exceptions/media_server_exceptions.dart';
import '../utils/endpoint_race.dart';
import '../utils/log_redaction_manager.dart';
import '../utils/media_server_http_client.dart';
import '../utils/media_server_timeouts.dart';
import '../utils/url_utils.dart';

/// Result of a successful Emby URL probe (`/System/Info/Public`).
class EmbyServerInfo {
  final String serverName;

  /// Server's `Id` field — Emby's machine identifier (UUID hex).
  final String machineId;

  /// Server's reported version string.
  final String version;

  const EmbyServerInfo({required this.serverName, required this.machineId, required this.version});
}

class EmbyEndpointRaceResult {
  final String activeBaseUrl;
  final List<String> baseUrls;
  final EmbyServerInfo serverInfo;

  const EmbyEndpointRaceResult({required this.activeBaseUrl, required this.baseUrls, required this.serverInfo});
}

class EmbyEndpointProbeResult {
  final bool success;
  final int latencyMs;
  final EmbyServerInfo? serverInfo;
  final String? error;

  const EmbyEndpointProbeResult({required this.success, required this.latencyMs, this.serverInfo, this.error});
}

class EmbyEndpointCandidate {
  final String url;
  final int index;

  const EmbyEndpointCandidate({required this.url, required this.index});
}

class EmbyEndpointUserInputCandidates {
  final List<String> probeBaseUrls;
  final List<String> explicitBaseUrls;
  final List<List<String>> validationBaseUrlGroups;

  const EmbyEndpointUserInputCandidates({
    required this.probeBaseUrls,
    required this.explicitBaseUrls,
    required this.validationBaseUrlGroups,
  });
}

class EmbyEndpointDiscovery {
  static const int defaultPort = 8096;

  EmbyEndpointDiscovery({http.Client Function()? testHttpClientFactory})
    : _testHttpClientFactory = testHttpClientFactory;

  final http.Client Function()? _testHttpClientFactory;

  MediaServerHttpClient _buildHttpClient({required String baseUrl}) {
    LogRedactionManager.registerServerUrl(baseUrl);
    return MediaServerHttpClient(baseUrl: baseUrl, client: _testHttpClientFactory?.call());
  }

  /// Probe the server identified by [baseUrl] without authenticating.
  Future<EmbyServerInfo> probe(String baseUrl, {Duration timeout = MediaServerTimeouts.embyProbe}) async {
    final normalised = normalizeBaseUrl(baseUrl);
    final client = _buildHttpClient(baseUrl: normalised);
    try {
      final response = await client.get('/System/Info/Public', timeout: timeout);
      throwIfHttpError(response);
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw MediaServerUrlException('Server response was not JSON');
      }
      final id = data['Id'];
      final name = data['ServerName'] ?? data['LocalAddress'];
      if (id is! String || name is! String) {
        throw MediaServerUrlException('Server response missing Id/ServerName — not a Emby server?');
      }
      return EmbyServerInfo(serverName: name, machineId: id, version: data['Version'] as String? ?? '');
    } on MediaServerUrlException {
      rethrow;
    } on MediaServerHttpException catch (e) {
      throw MediaServerUrlException('Server probe failed: ${e.message}');
    } on TimeoutException {
      throw MediaServerUrlException('Server did not respond in time');
    } catch (e) {
      throw MediaServerUrlException('Server probe failed: $e');
    } finally {
      client.close();
    }
  }

  Future<EmbyEndpointRaceResult> raceEndpoints(
    Iterable<String> baseUrls, {
    String? preferredUrl,
    String? expectedMachineId,
    Iterable<String>? baseUrlsToPersist,
    Iterable<String>? baseUrlsToValidate,
    Iterable<Iterable<String>>? baseUrlValidationGroups,
  }) async {
    final urls = normalizeBaseUrls(baseUrls);
    if (urls.isEmpty) {
      throw MediaServerUrlException('Enter at least one Emby server URL');
    }

    final persistUrls = baseUrlsToPersist == null ? urls : normalizeBaseUrls(baseUrlsToPersist);
    final validateUrls = baseUrlsToValidate == null ? urls : normalizeBaseUrls(baseUrlsToValidate);
    final validateUrlSet = validateUrls.toSet();
    final validationGroups = baseUrlValidationGroups == null ? null : _normalizeBaseUrlGroups(baseUrlValidationGroups);

    final preferred = preferredUrl == null || preferredUrl.trim().isEmpty ? null : normalizeBaseUrl(preferredUrl);
    final candidates = [for (var i = 0; i < urls.length; i++) EmbyEndpointCandidate(url: urls[i], index: i)];

    EndpointRaceSelection<EmbyEndpointCandidate, EmbyEndpointProbeResult>? firstSelection;
    EndpointRaceSelection<EmbyEndpointCandidate, EmbyEndpointProbeResult>? bestSelection;

    await for (final selection in raceEndpointCandidates<EmbyEndpointCandidate, EmbyEndpointProbeResult>(
      label: 'Emby server URL',
      candidates: candidates,
      preferredUrl: preferred,
      urlOf: (candidate) => candidate.url,
      failureLogFields: (candidate, result) => {'error': result.error, 'latencyMs': result.latencyMs},
      probe: (candidate, timeout) => _probeWithLatency(candidate.url, timeout: timeout),
      measure: (candidate) => _probeWithAverageLatency(candidate.url, attempts: 2),
      isSuccess: (result) => result.success,
      selectBestCandidate: (results) => _selectLowestLatencyCandidate(results),
    )) {
      if (selection.phase == EndpointRacePhase.first) {
        firstSelection = selection;
      } else {
        bestSelection = selection;
      }
    }

    final selected = bestSelection ?? firstSelection;
    if (selected == null || selected.result.serverInfo == null) {
      throw MediaServerUrlException('No reachable Emby server found');
    }

    final Map<EmbyEndpointCandidate, EmbyEndpointProbeResult> successfulResults =
        bestSelection?.successfulResults ?? firstSelection?.successfulResults ?? const {};
    var selectedCandidate = selected.candidate;
    var selectedResult = selected.result;

    final expectedMachineIdTrimmed = expectedMachineId?.trim();
    final hasExpectedMachineId = expectedMachineIdTrimmed?.isNotEmpty == true;
    if (hasExpectedMachineId) {
      final matchingResults = Map<EmbyEndpointCandidate, EmbyEndpointProbeResult>.fromEntries(
        successfulResults.entries.where((entry) => entry.value.serverInfo?.machineId == expectedMachineIdTrimmed),
      );
      final matchingCandidate = _selectLowestLatencyCandidate(matchingResults);
      final matchingResult = matchingCandidate == null ? null : matchingResults[matchingCandidate];
      if (matchingCandidate != null && matchingResult != null) {
        selectedCandidate = matchingCandidate;
        selectedResult = matchingResult;
      }
    }

    final selectedInfo = selectedResult.serverInfo;
    if (selectedInfo == null) {
      throw MediaServerUrlException('No reachable Emby server found');
    }

    final expected = hasExpectedMachineId ? expectedMachineIdTrimmed! : selectedInfo.machineId;
    if (validationGroups != null) {
      if (validationGroups.length > 1) {
        for (final group in validationGroups) {
          final groupSet = group.toSet();
          final groupResults = Map<EmbyEndpointCandidate, EmbyEndpointProbeResult>.fromEntries(
            successfulResults.entries.where((entry) => groupSet.contains(entry.key.url)),
          );
          final candidate = _selectValidationCandidate(groupResults, expectedMachineId: expectedMachineIdTrimmed);
          final info = candidate == null ? null : groupResults[candidate]?.serverInfo;
          if (info != null && info.machineId != expected) {
            throw MediaServerUrlException('The URLs point to different Emby servers');
          }
        }
      }
    } else {
      for (final entry in successfulResults.entries) {
        if (!validateUrlSet.contains(entry.key.url)) continue;
        final info = entry.value.serverInfo;
        if (info != null && info.machineId != expected) {
          throw MediaServerUrlException('The URLs point to different Emby servers');
        }
      }
    }

    if (selectedInfo.machineId != expected) {
      throw MediaServerUrlException('The URL does not match this Emby server');
    }

    return EmbyEndpointRaceResult(
      activeBaseUrl: selectedCandidate.url,
      baseUrls: _activeFirst(selectedCandidate.url, persistUrls),
      serverInfo: selectedInfo,
    );
  }

  Future<EmbyEndpointProbeResult> _probeWithLatency(String baseUrl, {required Duration timeout}) async {
    final stopwatch = Stopwatch()..start();
    try {
      final info = await probe(baseUrl, timeout: timeout);
      stopwatch.stop();
      return EmbyEndpointProbeResult(success: true, latencyMs: stopwatch.elapsedMilliseconds, serverInfo: info);
    } catch (e) {
      stopwatch.stop();
      return EmbyEndpointProbeResult(success: false, latencyMs: stopwatch.elapsedMilliseconds, error: e.toString());
    }
  }

  Future<EmbyEndpointProbeResult> _probeWithAverageLatency(String baseUrl, {required int attempts}) async {
    final results = <EmbyEndpointProbeResult>[];
    EmbyServerInfo? info;
    for (var i = 0; i < attempts; i++) {
      final result = await _probeWithLatency(baseUrl, timeout: MediaServerTimeouts.connectionRace);
      if (!result.success) {
        return EmbyEndpointProbeResult(success: false, latencyMs: result.latencyMs, error: result.error);
      }
      info = result.serverInfo;
      results.add(result);
    }
    final avgLatency = results.map((result) => result.latencyMs).reduce((a, b) => a + b) ~/ results.length;
    return EmbyEndpointProbeResult(success: true, latencyMs: avgLatency, serverInfo: info);
  }

  EmbyEndpointCandidate? _selectLowestLatencyCandidate(
    Map<EmbyEndpointCandidate, EmbyEndpointProbeResult> results,
  ) {
    if (results.isEmpty) return null;
    final entries = results.entries.toList()
      ..sort((a, b) {
        final latency = a.value.latencyMs.compareTo(b.value.latencyMs);
        if (latency != 0) return latency;
        return a.key.index.compareTo(b.key.index);
      });
    return entries.first.key;
  }

  EmbyEndpointCandidate? _selectValidationCandidate(
    Map<EmbyEndpointCandidate, EmbyEndpointProbeResult> results, {
    required String? expectedMachineId,
  }) {
    if (expectedMachineId?.isNotEmpty == true) {
      final matchingResults = Map<EmbyEndpointCandidate, EmbyEndpointProbeResult>.fromEntries(
        results.entries.where((entry) => entry.value.serverInfo?.machineId == expectedMachineId),
      );
      final match = _selectLowestLatencyCandidate(matchingResults);
      if (match != null) return match;
    }
    return _selectLowestLatencyCandidate(results);
  }

  /// Normalizes a concrete Emby base URL without inventing a scheme or port.
  static String normalizeBaseUrl(String input) => stripTrailingSlash(input);

  /// Expands a user-typed add/edit form entry into temporary probe candidates.
  /// These guesses are for discovery only; failed guesses should not be stored.
  static List<String> expandInputToBaseUrls(String input) {
    final trimmed = stripTrailingSlash(input);
    if (trimmed.isEmpty) return const [];
    if (_hasScheme(trimmed)) return [trimmed];

    final parsed = Uri.tryParse('http://$trimmed');
    if (parsed == null || parsed.host.isEmpty) return [trimmed];

    final result = <String>[];
    final seen = <String>{};
    void add(Uri uri) {
      final normalized = stripTrailingSlash(uri.replace(query: null, fragment: null).toString());
      if (normalized.isEmpty || !seen.add(normalized)) return;
      result.add(normalized);
    }

    if (parsed.hasPort) {
      add(parsed.replace(scheme: 'http'));
      add(parsed.replace(scheme: 'https'));
    } else {
      add(parsed.replace(scheme: 'http', port: defaultPort));
      add(parsed.replace(scheme: 'https'));
      add(parsed.replace(scheme: 'https', port: defaultPort));
      add(parsed.replace(scheme: 'http'));
    }
    return List.unmodifiable(result);
  }

  static EmbyEndpointUserInputCandidates buildUserInputCandidates(Iterable<String> input) {
    final probeBaseUrls = <String>[];
    final explicitBaseUrls = <String>[];
    final validationBaseUrlGroups = <List<String>>[];
    final seenProbe = <String>{};
    final seenExplicit = <String>{};

    void addProbe(String url) {
      final normalized = normalizeBaseUrl(url);
      if (normalized.isEmpty || !seenProbe.add(normalized)) return;
      probeBaseUrls.add(normalized);
    }

    void addExplicit(String url) {
      final normalized = normalizeBaseUrl(url);
      if (normalized.isEmpty || !seenExplicit.add(normalized)) return;
      explicitBaseUrls.add(normalized);
    }

    for (final raw in input) {
      final normalized = normalizeBaseUrl(raw);
      if (normalized.isEmpty) continue;
      if (_hasScheme(normalized)) {
        addProbe(normalized);
        addExplicit(normalized);
        validationBaseUrlGroups.add([normalized]);
      } else {
        final group = <String>[];
        for (final candidate in expandInputToBaseUrls(normalized)) {
          addProbe(candidate);
          group.add(candidate);
        }
        if (group.isNotEmpty) {
          validationBaseUrlGroups.add(List.unmodifiable(group));
        }
      }
    }

    return EmbyEndpointUserInputCandidates(
      probeBaseUrls: List.unmodifiable(probeBaseUrls),
      explicitBaseUrls: List.unmodifiable(explicitBaseUrls),
      validationBaseUrlGroups: List.unmodifiable(validationBaseUrlGroups),
    );
  }

  static List<String> normalizeBaseUrls(Iterable<String> input) {
    final result = <String>[];
    final seen = <String>{};
    for (final raw in input) {
      final normalized = normalizeBaseUrl(raw);
      if (normalized.isEmpty || !seen.add(normalized)) continue;
      result.add(normalized);
    }
    return List.unmodifiable(result);
  }

  static List<List<String>> _normalizeBaseUrlGroups(Iterable<Iterable<String>> groups) {
    final result = <List<String>>[];
    for (final group in groups) {
      final normalized = normalizeBaseUrls(group);
      if (normalized.isNotEmpty) result.add(normalized);
    }
    return List.unmodifiable(result);
  }

  static bool _hasScheme(String input) => RegExp(r'^[a-zA-Z][a-zA-Z\d+.-]*://').hasMatch(input);

  static List<String> _activeFirst(String activeBaseUrl, List<String> urls) {
    final result = <String>[];
    final seen = <String>{};
    void add(String url) {
      if (url.isEmpty || !seen.add(url)) return;
      result.add(url);
    }

    add(activeBaseUrl);
    for (final url in urls) {
      add(url);
    }
    return List.unmodifiable(result);
  }
}

typedef JellyfinEndpointRaceResult = EmbyEndpointRaceResult;
typedef JellyfinEndpointDiscovery = EmbyEndpointDiscovery;
typedef JellyfinServerInfo = EmbyServerInfo;
typedef JellyfinEndpointUserInputCandidates = EmbyEndpointUserInputCandidates;

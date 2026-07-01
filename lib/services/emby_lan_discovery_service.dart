import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../utils/app_logger.dart';
import '../utils/udp_broadcast_sockets.dart';
import 'emby_endpoint_discovery.dart';

class DiscoveredEmbyServer {
  final String address;
  final String id;
  final String name;

  DiscoveredEmbyServer({required this.address, required this.id, required this.name});
}

class EmbyLanDiscoveryService {
  static const int discoveryPort = 7359;
  static const String discoveryMessage = 'who is EmbyServer?';

  /// Sends two discovery packets 350 ms apart, then listens for
  /// [responseWindow] after the second packet.
  Future<List<DiscoveredEmbyServer>> discover({
    Duration responseWindow = const Duration(seconds: 2),
    InternetAddress? broadcastAddress,
  }) async {
    UdpBroadcastSocketSet? socketSet;
    final discovered = <String, DiscoveredEmbyServer>{};
    try {
      socketSet = await UdpBroadcastSockets.bind();
      socketSet.listen((datagram) {
        final server = parseDiscoveryResponse(datagram.data);
        if (server == null) return;
        discovered.putIfAbsent(server.id, () => server);
      }, debugLabel: 'Emby LAN discovery');

      final data = utf8.encode(discoveryMessage);
      final target = broadcastAddress ?? UdpBroadcastSockets.limitedBroadcastAddress;
      socketSet.send(data, target, discoveryPort);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      socketSet.send(data, target, discoveryPort);
      await Future<void>.delayed(responseWindow);
    } catch (e, st) {
      appLogger.w('Emby LAN discovery failed', error: e, stackTrace: st);
    } finally {
      await socketSet?.close();
    }

    return sortDiscoveredServers(discovered.values);
  }

  static List<DiscoveredEmbyServer> sortDiscoveredServers(Iterable<DiscoveredEmbyServer> servers) {
    final sorted = servers.toList()
      ..sort((a, b) {
        final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (name != 0) return name;
        final address = a.address.compareTo(b.address);
        if (address != 0) return address;
        return a.id.compareTo(b.id);
      });
    return List.unmodifiable(sorted);
  }

  static DiscoveredEmbyServer? parseDiscoveryResponse(List<int> data) {
    try {
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded is! Map<String, dynamic>) return null;

      final address = _stringValue(decoded, 'Address') ?? _stringValue(decoded, 'address');
      final id = _stringValue(decoded, 'Id') ?? _stringValue(decoded, 'id');
      final name = _stringValue(decoded, 'Name') ?? _stringValue(decoded, 'name');
      if (address == null || id == null || name == null) return null;

      final normalized = EmbyEndpointDiscovery.normalizeBaseUrl(address);
      if (normalized.isEmpty || id.trim().isEmpty || name.trim().isEmpty) return null;
      return DiscoveredEmbyServer(address: normalized, id: id.trim(), name: name.trim());
    } catch (_) {
      return null;
    }
  }

  static String? _stringValue(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

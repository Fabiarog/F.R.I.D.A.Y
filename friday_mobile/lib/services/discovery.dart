// F.R.I.D.A.Y. Mobile — Hub Discovery Service
// Varre a rede local em busca de instâncias do F.R.I.D.A.Y. Hub Central.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

class HubInfo {
  final String ip;
  final int    port;
  final String hostname;
  final String version;

  const HubInfo({
    required this.ip,
    required this.port,
    required this.hostname,
    required this.version,
  });

  String get wsUrl  => 'ws://$ip:$port/ws';
  String get apiUrl => 'http://$ip:$port';

  @override
  String toString() => '$hostname ($ip:$port)';
}

class DiscoveryService {
  static const int _defaultPort = 8000;
  static const Duration _timeout = Duration(milliseconds: 600);

  /// Descobre todos os Hubs F.R.I.D.A.Y. na sub-rede local.
  /// Varre o range /24 do IP atual do dispositivo.
  static Future<List<HubInfo>> scanLocalNetwork({
    void Function(int progress, int total)? onProgress,
  }) async {
    final info = NetworkInfo();
    final myIp = await info.getWifiIP();
    if (myIp == null) return [];

    // Extrai o prefixo da rede (ex: "192.168.1")
    final parts   = myIp.split('.');
    if (parts.length < 3) return [];
    final prefix  = '${parts[0]}.${parts[1]}.${parts[2]}';
    final hosts   = List.generate(254, (i) => '$prefix.${i + 1}');
    final results = <HubInfo>[];

    debugPrint('[Discovery] Varrendo $prefix.1–254 na porta $_defaultPort...');

    // Varre em paralelo com concorrência limitada (20 ao mesmo tempo)
    const concurrency = 20;
    for (int i = 0; i < hosts.length; i += concurrency) {
      final batch = hosts.skip(i).take(concurrency).toList();
      final futures = batch.map((host) => _probeHost(host, _defaultPort));
      final batchResults = await Future.wait(futures);
      for (final r in batchResults) {
        if (r != null) results.add(r);
      }
      onProgress?.call(i + batch.length, hosts.length);
    }

    debugPrint('[Discovery] Encontrados: ${results.length} hub(s).');
    return results;
  }

  /// Tenta conectar a um host específico e verificar se é um Hub F.R.I.D.A.Y.
  static Future<HubInfo?> _probeHost(String ip, int port) async {
    try {
      final uri = Uri.parse('http://$ip:$port/api/info');
      final response = await http
          .get(uri)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['service'] == 'friday_hub') {
          return HubInfo(
            ip:       ip,
            port:     port,
            hostname: data['hostname'] as String? ?? ip,
            version:  data['version']  as String? ?? '?',
          );
        }
      }
    } catch (_) {
      // Host não respondeu ou não é um Hub — ignorar
    }
    return null;
  }

  /// Verifica se um Hub específico ainda está online.
  static Future<bool> isHubAlive(String ip, int port) async {
    final result = await _probeHost(ip, port);
    return result != null;
  }

  /// Obtém info detalhada de um Hub por IP conhecido.
  static Future<HubInfo?> getHubInfo(String ip, int port) async {
    return _probeHost(ip, port);
  }
}

// F.R.I.D.A.Y. Mobile — WebSocket Service
// Singleton com reconexão automática exponencial, heartbeat e stream de telemetria.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Estados de conexão ────────────────────────────────────────────────────────
enum WsStatus { disconnected, connecting, connected, error }

// ── Dados de Telemetria ───────────────────────────────────────────────────────
class TelemetryData {
  final double cpuPct;
  final double ramPct;
  final double gpuPct;
  final double gpuVramUsed;
  final double gpuVramTotal;
  final int    gpuTempC;
  final String gpuName;
  final double diskPct;
  final int    clientsConnected;
  final DateTime timestamp;

  const TelemetryData({
    this.cpuPct = 0,
    this.ramPct = 0,
    this.gpuPct = 0,
    this.gpuVramUsed = 0,
    this.gpuVramTotal = 0,
    this.gpuTempC = 0,
    this.gpuName = 'N/A',
    this.diskPct = 0,
    this.clientsConnected = 0,
    required this.timestamp,
  });

  factory TelemetryData.fromJson(Map<String, dynamic> j) {
    final cpu  = j['cpu']  as Map<String, dynamic>? ?? {};
    final ram  = j['ram']  as Map<String, dynamic>? ?? {};
    final gpu  = j['gpu']  as Map<String, dynamic>? ?? {};
    final disk = j['disk'] as Map<String, dynamic>? ?? {};

    return TelemetryData(
      cpuPct:          (cpu['pct']         as num? ?? 0).toDouble(),
      ramPct:          (ram['pct']         as num? ?? 0).toDouble(),
      gpuPct:          (gpu['load_pct']    as num? ?? 0).toDouble(),
      gpuVramUsed:     (gpu['vram_used']   as num? ?? 0).toDouble(),
      gpuVramTotal:    (gpu['vram_total']  as num? ?? 0).toDouble(),
      gpuTempC:        (gpu['temp_c']      as num? ?? 0).toInt(),
      gpuName:         gpu['name']         as String? ?? 'N/A',
      diskPct:         (disk['pct']        as num? ?? 0).toDouble(),
      clientsConnected: j['clients_connected'] as int? ?? 0,
      timestamp:       DateTime.now(),
    );
  }
}

// ── WebSocket Service Singleton ───────────────────────────────────────────────
class WebSocketService extends ChangeNotifier {
  static final WebSocketService _instance = WebSocketService._();
  factory WebSocketService() => _instance;
  WebSocketService._();

  // ── Estado público ────────────────────────────────────────────────────
  WsStatus    status     = WsStatus.disconnected;
  TelemetryData? telemetry;
  String      hubHost    = '192.168.1.100';
  int         hubPort    = 8000;
  String?     lastError;
  int         latencyMs  = 0;

  // ── Streams ───────────────────────────────────────────────────────────
  final _telemetryController = StreamController<TelemetryData>.broadcast();
  final _eventController     = StreamController<Map<String, dynamic>>.broadcast();

  Stream<TelemetryData>         get telemetryStream => _telemetryController.stream;
  Stream<Map<String, dynamic>>  get eventStream     => _eventController.stream;

  // ── Internos ──────────────────────────────────────────────────────────
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _heartbeatInterval = Duration(seconds: 15);

  String get wsUrl => 'ws://$hubHost:$hubPort/ws';

  // ── Persistência ──────────────────────────────────────────────────────
  Future<void> loadSavedHost() async {
    final prefs = await SharedPreferences.getInstance();
    hubHost = prefs.getString('friday_host') ?? '192.168.1.100';
    hubPort = prefs.getInt('friday_port')    ?? 8000;
  }

  Future<void> saveHost(String host, int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('friday_host', host);
    await prefs.setInt('friday_port', port);
    hubHost = host;
    hubPort = port;
  }

  // ── Conexão ───────────────────────────────────────────────────────────
  Future<void> connect({String? host, int? port}) async {
    if (host != null) hubHost = host;
    if (port != null) hubPort = port;

    _reconnectAttempts = 0;
    await _connect();
  }

  Future<void> _connect() async {
    if (status == WsStatus.connected || status == WsStatus.connecting) return;

    _setStatus(WsStatus.connecting);
    debugPrint('[WS] Conectando em $wsUrl...');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;  // lança se falhar

      _setStatus(WsStatus.connected);
      _reconnectAttempts = 0;
      lastError = null;
      debugPrint('[WS] Conectado!');

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone:  _onDone,
      );

      _startHeartbeat();
    } catch (e) {
      lastError = e.toString();
      _setStatus(WsStatus.error);
      debugPrint('[WS] Falha de conexão: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';

      if (type == 'telemetry') {
        final t = TelemetryData.fromJson(data);
        telemetry = t;
        _telemetryController.add(t);
        // Latência aproximada: delta entre timestamp do servidor e agora
        final ts = data['timestamp'] as double?;
        if (ts != null) {
          final serverTime = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
          latencyMs = DateTime.now().difference(serverTime).inMilliseconds.abs();
        }
      } else if (type == 'pong') {
        // heartbeat confirmado
      } else {
        _eventController.add(data);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[WS] Parse error: $e');
    }
  }

  void _onError(dynamic error) {
    lastError = error.toString();
    _setStatus(WsStatus.error);
    debugPrint('[WS] Erro: $error');
    _scheduleReconnect();
  }

  void _onDone() {
    if (status == WsStatus.connected) {
      _setStatus(WsStatus.disconnected);
      debugPrint('[WS] Conexão encerrada pelo servidor.');
      _scheduleReconnect();
    }
  }

  // ── Heartbeat ─────────────────────────────────────────────────────────
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      sendCommand({'action': 'ping'});
    });
  }

  // ── Reconexão Exponencial ─────────────────────────────────────────────
  void _scheduleReconnect() {
    _heartbeatTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[WS] Máximo de tentativas atingido.');
      return;
    }

    final delay = Duration(
      seconds: min(30, pow(2, _reconnectAttempts).toInt()),
    );
    _reconnectAttempts++;
    debugPrint('[WS] Reconectando em ${delay.inSeconds}s (tentativa $_reconnectAttempts)...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
  }

  // ── Enviar Comando ────────────────────────────────────────────────────
  void sendCommand(Map<String, dynamic> payload) {
    if (status != WsStatus.connected) return;
    try {
      _channel?.sink.add(jsonEncode(payload));
    } catch (e) {
      debugPrint('[WS] Erro ao enviar: $e');
    }
  }

  // ── Helpers de Comando ────────────────────────────────────────────────
  void setGamingMode()    => sendCommand({'action': 'gaming_mode'});
  void setSilentMode()    => sendCommand({'action': 'silent_mode'});
  void setSmartHome()     => sendCommand({'action': 'smart_home_mode'});
  void mediaPlayPause()   => sendCommand({'action': 'media_play_pause'});
  void mediaNext()        => sendCommand({'action': 'media_next'});
  void mediaPrev()        => sendCommand({'action': 'media_prev'});
  void volumeUp()         => sendCommand({'action': 'volume_up', 'steps': 5});
  void volumeDown()       => sendCommand({'action': 'volume_down', 'steps': 5});
  void muteMic()          => sendCommand({'action': 'mute_toggle'});
  void sleepPc()          => sendCommand({'action': 'sleep'});
  void lockPc()           => sendCommand({'action': 'lock'});
  void launchApp(String t)=> sendCommand({'action': 'launch_app', 'target': t});
  void wakeOnLan(String m)=> sendCommand({'action': 'wake_on_lan', 'mac': m});

  // ── Desconectar ───────────────────────────────────────────────────────
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
    _setStatus(WsStatus.disconnected);
  }

  void _setStatus(WsStatus s) {
    status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _telemetryController.close();
    _eventController.close();
    super.dispose();
  }
}

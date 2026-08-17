// F.R.I.D.A.Y. Mobile — Home Screen (HUD Principal)
// Layout vertical adaptativo com orbe neural, telemetria, modos e controles IoT.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/neural_theme.dart';
import '../services/ws_service.dart';
import '../widgets/neural_orb.dart';
import '../widgets/telemetry_panel.dart';
import '../widgets/mode_button.dart';
import '../widgets/agent_card.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {

  OrbState _orbState = OrbState.standby;
  String   _activeMode = '';
  late AnimationController _headerCtrl;
  late Animation<double>   _headerAnim;

  // IoT switches simulados (conectar via MQTT no futuro)
  final Map<String, bool> _iotSwitches = {
    'Luz Escritório': false,
    'Monitor LED':    true,
    'Ventilador':     false,
    'Tomada PC':      true,
  };

  @override
  void initState() {
    super.initState();

    _headerCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..forward();
    _headerAnim = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic);

    // Ouve eventos do WebSocket
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ws = context.read<WebSocketService>();
      ws.eventStream.listen(_onWsEvent);
    });
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  void _onWsEvent(Map<String, dynamic> event) {
    final type = event['type'] as String? ?? '';
    if (type == 'response' && mounted) {
      final mode = event['mode'] as String?;
      if (mode != null) {
        setState(() {
          _activeMode = mode;
          _orbState = switch (mode) {
            'gaming'     => OrbState.gaming,
            'media'      => OrbState.media,
            'silent'     => OrbState.standby,
            'smart_home' => OrbState.standby,
            _            => OrbState.standby,
          };
        });
      }
    }
  }

  void _setMode(String mode) {
    final ws = context.read<WebSocketService>();
    HapticFeedback.mediumImpact();

    setState(() {
      _activeMode = mode;
      _orbState = switch (mode) {
        'gaming'     => OrbState.gaming,
        'media'      => OrbState.media,
        'listen'     => OrbState.listening,
        'smart_home' => OrbState.standby,
        _            => OrbState.standby,
      };
    });

    switch (mode) {
      case 'gaming':     ws.setGamingMode();  break;
      case 'media':      break; // apenas local por ora
      case 'listen':     break; // integração STT futura
      case 'smart_home': ws.setSmartHome();   break;
      case 'silent':     ws.setSilentMode();  break;
    }
  }

  void _cycleOrb() {
    HapticFeedback.lightImpact();
    setState(() {
      _orbState = switch (_orbState) {
        OrbState.standby   => OrbState.listening,
        OrbState.listening => OrbState.thinking,
        OrbState.thinking  => OrbState.standby,
        _                  => OrbState.standby,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<WebSocketService>();
    final telemetry = ws.telemetry;
    final isConnected = ws.status == WsStatus.connected;

    return Scaffold(
      backgroundColor: NColor.bgVoid,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _headerAnim,
                child: _buildHeader(ws, isConnected),
              ),
            ),

            // ── Neural Orb ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: NeuralOrb(
                    state: _orbState,
                    size: 200,
                    onTap: _cycleOrb,
                  ),
                ),
              ),
            ),

            // ── Status Label ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Center(
                child: Text(
                  _orbStateLabel,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: NColor.textMuted,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),

            // ── Modos de Operação ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(title: 'MODOS DE OPERAÇÃO'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: ModeButton(
                          icon: Icons.sports_esports,
                          label: 'GAMING',
                          activeColor: NColor.orange,
                          isActive: _activeMode == 'gaming',
                          onTap: () => _setMode('gaming'),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: ModeButton(
                          icon: Icons.mic,
                          label: 'ESCUTAR',
                          isActive: _activeMode == 'listen',
                          onTap: () => _setMode('listen'),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: ModeButton(
                          icon: Icons.disc_full,
                          label: 'MÍDIA',
                          activeColor: NColor.emerald,
                          isActive: _activeMode == 'media',
                          onTap: () => _setMode('media'),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: ModeButton(
                          icon: Icons.home_outlined,
                          label: 'CASA',
                          isActive: _activeMode == 'smart_home',
                          onTap: () => _setMode('smart_home'),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Telemetria ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: TelemetryPanel(data: telemetry),
              ),
            ),

            // ── Controles de Mídia ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _buildMediaPanel(ws),
              ),
            ),

            // ── Controles IoT ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _buildIoTPanel(ws),
              ),
            ),

            // ── Agentes Ativos ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _buildAgentsPanel(),
              ),
            ),

            // ── Ações de Energia ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: _buildPowerPanel(ws),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(WebSocketService ws, bool isConnected) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: panelDecoration(),
      child: Row(
        children: [
          // Status dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? NColor.emerald : NColor.red,
              boxShadow: isConnected
                  ? [BoxShadow(color: NColor.emerald.withOpacity(0.8), blurRadius: 8)]
                  : [],
            ),
          ),
          const SizedBox(width: 10),

          // Title
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'F.R.I.D.A.Y.',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: NColor.cyan,
                    letterSpacing: 3,
                  ),
                ),
                Text(
                  'CORE v4.2 — NEURAL HUB',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 8,
                    color: NColor.textMuted,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // Latency
          if (isConnected)
            Text(
              '${ws.latencyMs}ms',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: ws.latencyMs < 50 ? NColor.emerald
                     : ws.latencyMs < 150 ? NColor.orange
                     : NColor.red,
                letterSpacing: 1,
              ),
            ),

          const SizedBox(width: 12),

          // Settings button
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            child: const Icon(Icons.tune, color: NColor.textMuted, size: 20),
          ),
        ],
      ),
    );
  }

  // ── Mídia Panel ─────────────────────────────────────────────────────────────
  Widget _buildMediaPanel(WebSocketService ws) {
    return Container(
      decoration: panelDecoration(borderColor: NColor.emerald.withOpacity(0.25)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'CONTROLE DE MÍDIA'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MediaBtn(icon: Icons.skip_previous, onTap: ws.mediaPrev),
              _MediaBtn(icon: Icons.play_arrow, size: 32, onTap: ws.mediaPlayPause),
              _MediaBtn(icon: Icons.skip_next, onTap: ws.mediaNext),
              _MediaBtn(icon: Icons.volume_down, onTap: ws.volumeDown),
              _MediaBtn(icon: Icons.volume_up, onTap: ws.volumeUp),
              _MediaBtn(icon: Icons.volume_mute, onTap: ws.muteMic),
            ],
          ),
        ],
      ),
    );
  }

  // ── IoT Panel ───────────────────────────────────────────────────────────────
  Widget _buildIoTPanel(WebSocketService ws) {
    return Container(
      decoration: panelDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'DISPOSITIVOS IoT'),
          const SizedBox(height: 8),
          ..._iotSwitches.entries.map((e) => _IotSwitch(
            label: e.key,
            value: e.value,
            onChanged: (v) {
              setState(() => _iotSwitches[e.key] = v);
              HapticFeedback.selectionClick();
              // Futuramente: ws.sendCommand({'action': 'iot_toggle', 'device': e.key, 'state': v})
            },
          )),
        ],
      ),
    );
  }

  // ── Agents Panel ────────────────────────────────────────────────────────────
  Widget _buildAgentsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _SectionTitle(title: 'AGENTES NEURAIS'),
        ),
        AgentCard(
          name: 'RAG Pipeline',
          description: 'Recuperação semântica • 12k docs',
          status: AgentStatus.online,
        ),
        AgentCard(
          name: 'Voice Engine',
          description: 'STT/TTS • Whisper v3',
          status: AgentStatus.online,
        ),
        AgentCard(
          name: 'LLM Core',
          description: 'Inferência local • 87 tok/s',
          status: AgentStatus.busy,
        ),
        AgentCard(
          name: 'Automation Bot',
          description: 'Controle de sistema • Standby',
          status: AgentStatus.idle,
        ),
        AgentCard(
          name: 'Vision Module',
          description: 'Análise de imagem • Offline',
          status: AgentStatus.offline,
        ),
      ],
    );
  }

  // ── Power Panel ─────────────────────────────────────────────────────────────
  Widget _buildPowerPanel(WebSocketService ws) {
    return Container(
      decoration: panelDecoration(borderColor: NColor.red.withOpacity(0.2)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'CONTROLE DE ENERGIA'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _PowerBtn(
                label: 'Suspender',
                icon: Icons.bedtime_outlined,
                color: NColor.cyan,
                onTap: () => _confirm('Suspender o PC?', ws.sleepPc),
              )),
              const SizedBox(width: 10),
              Expanded(child: _PowerBtn(
                label: 'Bloquear',
                icon: Icons.lock_outline,
                color: NColor.orange,
                onTap: () => _confirm('Bloquear a sessão?', ws.lockPc),
              )),
              const SizedBox(width: 10),
              Expanded(child: _PowerBtn(
                label: 'Desligar',
                icon: Icons.power_settings_new,
                color: NColor.red,
                onTap: () => _confirm(
                  'Desligar o PC?',
                  () => ws.sendCommand({'action': 'shutdown', 'delay': 0}),
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(String msg, VoidCallback action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: NColor.bgDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: NColor.border),
        ),
        title: const Text('Confirmar', style: TextStyle(color: NColor.cyan, letterSpacing: 2)),
        content: Text(msg, style: const TextStyle(color: NColor.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: NColor.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar', style: TextStyle(color: NColor.cyan)),
          ),
        ],
      ),
    );
    if (ok == true) action();
  }

  String get _orbStateLabel => switch (_orbState) {
    OrbState.listening => 'MICROFONE ATIVO — OUVINDO...',
    OrbState.thinking  => 'PROCESSAMENTO NEURAL EM CURSO',
    OrbState.gaming    => 'MODO GAMING — MÁXIMA PERFORMANCE',
    OrbState.media     => 'CONTROLE DE MÍDIA ATIVO',
    _                  => 'SISTEMAS PRONTOS — TOQUE NO NÚCLEO',
  };
}

// ── Sub-widgets locais ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'monospace', fontSize: 9,
            color: NColor.cyan, letterSpacing: 2.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [NColor.cyan.withOpacity(0.4), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaBtn extends StatelessWidget {
  final IconData icon;
  final double   size;
  final VoidCallback onTap;

  const _MediaBtn({required this.icon, required this.onTap, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: NColor.bgPanel,
          border: Border.all(color: NColor.border),
        ),
        child: Icon(icon, color: NColor.cyan, size: size),
      ),
    );
  }
}

class _IotSwitch extends StatelessWidget {
  final String   label;
  final bool     value;
  final ValueChanged<bool> onChanged;

  const _IotSwitch({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                value ? Icons.circle : Icons.circle_outlined,
                size: 8,
                color: value ? NColor.emerald : NColor.textMuted,
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(
                color: NColor.textMuted, fontSize: 12,
              )),
            ],
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PowerBtn extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;

  const _PowerBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace', fontSize: 9,
                color: color, letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

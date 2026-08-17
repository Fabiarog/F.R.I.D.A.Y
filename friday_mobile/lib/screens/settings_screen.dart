// F.R.I.D.A.Y. Mobile — Settings Screen
// Configuração de IP do Hub, discovery automático e opções avançadas.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/neural_theme.dart';
import '../services/ws_service.dart';
import '../services/discovery.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ipCtrl   = TextEditingController();
  final _portCtrl = TextEditingController();

  bool _isScanning  = false;
  int  _scanProgress = 0;
  List<HubInfo> _found = [];
  String _scanStatus = '';

  @override
  void initState() {
    super.initState();
    final ws = context.read<WebSocketService>();
    _ipCtrl.text   = ws.hubHost;
    _portCtrl.text = ws.hubPort.toString();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _isScanning   = true;
      _scanProgress = 0;
      _found        = [];
      _scanStatus   = 'Varrendo rede local...';
    });

    final results = await DiscoveryService.scanLocalNetwork(
      onProgress: (done, total) {
        if (mounted) setState(() => _scanProgress = ((done / total) * 100).toInt());
      },
    );

    if (mounted) {
      setState(() {
        _found     = results;
        _isScanning = false;
        _scanStatus = results.isEmpty
            ? 'Nenhum Hub encontrado na rede.'
            : '${results.length} Hub(s) encontrado(s)!';
      });
    }
  }

  Future<void> _connect() async {
    final ip   = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 8000;
    if (ip.isEmpty) return;

    final ws = context.read<WebSocketService>();
    await ws.saveHost(ip, port);
    await ws.connect(host: ip, port: port);

    if (mounted) Navigator.pop(context);
  }

  void _selectHub(HubInfo hub) {
    _ipCtrl.text   = hub.ip;
    _portCtrl.text = hub.port.toString();
  }

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<WebSocketService>();

    return Scaffold(
      backgroundColor: NColor.bgVoid,
      appBar: AppBar(
        backgroundColor: NColor.bgDeep,
        foregroundColor: NColor.cyan,
        title: const Text(
          'CONFIGURAÇÕES DO HUB',
          style: TextStyle(
            fontFamily: 'monospace', fontSize: 13,
            letterSpacing: 3, color: NColor.cyan,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: NColor.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Status Atual ─────────────────────────────────────────
            Container(
              decoration: panelDecoration(),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ws.status == WsStatus.connected
                          ? NColor.emerald : NColor.red,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      switch (ws.status) {
                        WsStatus.connected    => 'Conectado em ${ws.hubHost}:${ws.hubPort}',
                        WsStatus.connecting   => 'Conectando...',
                        WsStatus.error        => 'Erro: ${ws.lastError ?? "desconhecido"}',
                        WsStatus.disconnected => 'Desconectado',
                      },
                      style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 11,
                        color: NColor.textMuted,
                      ),
                    ),
                  ),
                  if (ws.status == WsStatus.connected)
                    GestureDetector(
                      onTap: ws.disconnect,
                      child: const Text(
                        'DESCONECTAR',
                        style: TextStyle(
                          fontFamily: 'monospace', fontSize: 9,
                          color: NColor.red, letterSpacing: 1.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Discovery Automático ─────────────────────────────────
            Container(
              decoration: panelDecoration(),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DISCOVERY AUTOMÁTICO',
                        style: TextStyle(
                          fontFamily: 'monospace', fontSize: 9,
                          color: NColor.cyan, letterSpacing: 2,
                        ),
                      ),
                      if (!_isScanning)
                        GestureDetector(
                          onTap: _scan,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: NColor.border),
                              color: NColor.bgPanel,
                            ),
                            child: const Text(
                              'VARRER REDE',
                              style: TextStyle(
                                fontFamily: 'monospace', fontSize: 9,
                                color: NColor.cyan, letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  if (_isScanning) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _scanProgress / 100,
                      backgroundColor: NColor.bgPanel,
                      valueColor: const AlwaysStoppedAnimation(NColor.cyan),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Varrendo... $_scanProgress%',
                      style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 10,
                        color: NColor.textMuted,
                      ),
                    ),
                  ],

                  if (_scanStatus.isNotEmpty && !_isScanning) ...[
                    const SizedBox(height: 10),
                    Text(
                      _scanStatus,
                      style: TextStyle(
                        fontFamily: 'monospace', fontSize: 10,
                        color: _found.isNotEmpty ? NColor.emerald : NColor.textMuted,
                      ),
                    ),
                  ],

                  if (_found.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ..._found.map((hub) => GestureDetector(
                      onTap: () => _selectHub(hub),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: NColor.emerald.withOpacity(0.3)),
                          color: NColor.emerald.withOpacity(0.05),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.hub_outlined,
                                color: NColor.emerald, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${hub.hostname} — ${hub.ip}:${hub.port}',
                                style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 11,
                                  color: NColor.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              'v${hub.version}',
                              style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 9,
                                color: NColor.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Conexão Manual ────────────────────────────────────────
            Container(
              decoration: panelDecoration(),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONEXÃO MANUAL',
                    style: TextStyle(
                      fontFamily: 'monospace', fontSize: 9,
                      color: NColor.cyan, letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _NeuralTextField(
                    controller: _ipCtrl,
                    label: 'IP DO HUB',
                    hint: '192.168.1.100',
                    keyboard: TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 10),

                  _NeuralTextField(
                    controller: _portCtrl,
                    label: 'PORTA',
                    hint: '8000',
                    keyboard: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _connect,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: NColor.cyan.withOpacity(0.1),
                          border: Border.all(color: NColor.cyan.withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: NColor.cyan.withOpacity(0.2),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'CONECTAR AO HUB',
                            style: TextStyle(
                              fontFamily: 'monospace', fontSize: 12,
                              color: NColor.cyan,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Nota sobre Wake-on-LAN ────────────────────────────────
            Container(
              decoration: panelDecoration(),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WAKE-ON-LAN',
                    style: TextStyle(
                      fontFamily: 'monospace', fontSize: 9,
                      color: NColor.orange, letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Para ligar o PC remotamente, o WoL deve estar ativado na BIOS e o MAC address configurado abaixo.',
                    style: TextStyle(fontSize: 11, color: NColor.textMuted),
                  ),
                  const SizedBox(height: 10),
                  _NeuralTextField(
                    label: 'MAC ADDRESS',
                    hint: 'AA:BB:CC:DD:EE:FF',
                    keyboard: TextInputType.text,
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      // TODO: salvar e enviar WoL
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Magic Packet enviado!',
                              style: TextStyle(fontFamily: 'monospace')),
                          backgroundColor: NColor.bgDeep,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: NColor.orange.withOpacity(0.4)),
                        color: NColor.orange.withOpacity(0.07),
                      ),
                      child: const Center(
                        child: Text(
                          'ENVIAR MAGIC PACKET',
                          style: TextStyle(
                            fontFamily: 'monospace', fontSize: 10,
                            color: NColor.orange, letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Neural Text Field ─────────────────────────────────────────────────────────
class _NeuralTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String hint;
  final TextInputType keyboard;

  const _NeuralTextField({
    this.controller,
    required this.label,
    required this.hint,
    required this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace', fontSize: 9,
            color: NColor.textMuted, letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          style: const TextStyle(
            fontFamily: 'monospace', fontSize: 13,
            color: NColor.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: 'monospace', color: NColor.textMuted, fontSize: 12,
            ),
            filled: true,
            fillColor: NColor.bgPanel,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: NColor.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: NColor.cyan, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

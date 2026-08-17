// F.R.I.D.A.Y. Mobile — Neural Orb Widget
// CustomPainter com anéis giratórios e glow neon responsivo ao estado da IA.

import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/neural_theme.dart';

// ── Estados do Orbe ───────────────────────────────────────────────────────────
enum OrbState { standby, listening, thinking, gaming, media }

class NeuralOrb extends StatefulWidget {
  final OrbState state;
  final double   size;
  final VoidCallback? onTap;

  const NeuralOrb({
    super.key,
    this.state = OrbState.standby,
    this.size  = 200,
    this.onTap,
  });

  @override
  State<NeuralOrb> createState() => _NeuralOrbState();
}

class _NeuralOrbState extends State<NeuralOrb>
    with TickerProviderStateMixin {

  late AnimationController _ring1Ctrl;
  late AnimationController _ring2Ctrl;
  late AnimationController _ring3Ctrl;
  late AnimationController _pulseCtrl;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();

    _ring1Ctrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 20),
    )..repeat();

    _ring2Ctrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 14),
    )..repeat(reverse: false);

    _ring3Ctrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 8),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ring1Ctrl.dispose();
    _ring2Ctrl.dispose();
    _ring3Ctrl.dispose();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Color get _primaryColor {
    switch (widget.state) {
      case OrbState.gaming:    return NColor.orange;
      case OrbState.listening:
      case OrbState.media:     return NColor.emerald;
      default:                 return NColor.cyan;
    }
  }

  IconData get _icon {
    switch (widget.state) {
      case OrbState.listening: return Icons.mic;
      case OrbState.thinking:  return Icons.auto_awesome;
      case OrbState.gaming:    return Icons.sports_esports;
      case OrbState.media:     return Icons.disc_full;
      default:                 return Icons.mic_none;
    }
  }

  String get _stateLabel {
    switch (widget.state) {
      case OrbState.listening: return 'OUVINDO';
      case OrbState.thinking:  return 'PENSANDO';
      case OrbState.gaming:    return 'GAMING';
      case OrbState.media:     return 'MÍDIA';
      default:                 return 'STANDBY';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color  = _primaryColor;
    final s      = widget.size;
    final isLive = widget.state == OrbState.listening;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: s, height: s,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _ring1Ctrl, _ring2Ctrl, _ring3Ctrl,
            _pulseCtrl, _glowCtrl,
          ]),
          builder: (context, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // ── Anel Externo (dashed style via pintura) ────────────
                Transform.rotate(
                  angle: _ring1Ctrl.value * 2 * pi,
                  child: CustomPaint(
                    size: Size(s, s),
                    painter: _RingPainter(
                      color: color.withOpacity(0.15),
                      dashed: true,
                    ),
                  ),
                ),

                // ── Anel Médio (contra-rotação) ───────────────────────
                Transform.rotate(
                  angle: -_ring2Ctrl.value * 2 * pi,
                  child: CustomPaint(
                    size: Size(s * 0.82, s * 0.82),
                    painter: _RingPainter(
                      color: color.withOpacity(0.1),
                    ),
                  ),
                ),

                // ── Anel Interno (rápido, parcial) ────────────────────
                Transform.rotate(
                  angle: _ring3Ctrl.value * 2 * pi,
                  child: CustomPaint(
                    size: Size(s * 0.65, s * 0.65),
                    painter: _ArcRingPainter(color: color),
                  ),
                ),

                // ── Glow Pulsante ─────────────────────────────────────
                Container(
                  width: s * 0.55,
                  height: s * 0.55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(
                          isLive
                              ? 0.25 + 0.25 * _glowCtrl.value
                              : 0.15 + 0.1 * _pulseCtrl.value,
                        ),
                        blurRadius: 40 + 20 * _glowCtrl.value,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),

                // ── Núcleo ────────────────────────────────────────────
                Container(
                  width: s * 0.50,
                  height: s * 0.50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.7),
                    border: Border.all(
                      color: color.withOpacity(0.7),
                      width: 2,
                    ),
                    gradient: RadialGradient(
                      colors: [
                        color.withOpacity(0.18),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_icon, color: color, size: s * 0.13),
                      const SizedBox(height: 4),
                      Text(
                        _stateLabel,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: s * 0.045,
                          color: color.withOpacity(0.85),
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Pintores ──────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final Color color;
  final bool dashed;

  _RingPainter({required this.color, this.dashed = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    if (dashed) {
      const dashCount = 24;
      const dashAngle = 2 * pi / dashCount;
      for (int i = 0; i < dashCount; i += 2) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          i * dashAngle,
          dashAngle * 0.7,
          false,
          paint,
        );
      }
    } else {
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}

class _ArcRingPainter extends CustomPainter {
  final Color color;
  _ArcRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Topo brilhante
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, pi,
      false,
      Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    // Base suave
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi / 2, pi,
      false,
      Paint()
        ..color = color.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_ArcRingPainter old) => old.color != color;
}

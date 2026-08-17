// F.R.I.D.A.Y. Mobile — Telemetry Panel Widget
// Barras animadas de CPU, RAM, GPU e Disco com indicadores de threshold.

import 'package:flutter/material.dart';
import '../theme/neural_theme.dart';
import '../services/ws_service.dart';

class TelemetryPanel extends StatelessWidget {
  final TelemetryData? data;

  const TelemetryPanel({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: panelDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: NColor.cyan,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [BoxShadow(color: NColor.cyan.withOpacity(0.8), blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'TELEMETRIA DO SISTEMA',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: NColor.cyan,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (data == null)
            const Center(
              child: Text(
                'Aguardando dados do Hub...',
                style: TextStyle(color: NColor.textMuted, fontSize: 12),
              ),
            )
          else ...[
            _GaugeRow(label: 'CPU',   pct: data!.cpuPct,  unit: '%'),
            _GaugeRow(label: 'RAM',   pct: data!.ramPct,  unit: '%'),
            _GaugeRow(label: 'GPU',   pct: data!.gpuPct,  unit: '%',  color: NColor.emerald),
            _GaugeRow(label: 'DISCO', pct: data!.diskPct, unit: '%'),

            if (data!.gpuVramTotal > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'VRAM: ${data!.gpuVramUsed.toStringAsFixed(1)} / ${data!.gpuVramTotal.toStringAsFixed(0)} GB',
                    style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 10,
                      color: NColor.textMuted, letterSpacing: 1,
                    ),
                  ),
                  if (data!.gpuTempC > 0)
                    _TempBadge(tempC: data!.gpuTempC),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Gauge Row ─────────────────────────────────────────────────────────────────
class _GaugeRow extends StatelessWidget {
  final String label;
  final double pct;
  final String unit;
  final Color? color;

  const _GaugeRow({
    required this.label,
    required this.pct,
    required this.unit,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? gaugeColor(pct);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 10,
                  color: NColor.textMuted, letterSpacing: 1.5,
                ),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontFamily: 'monospace', fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: barColor,
                  letterSpacing: 1,
                ),
                child: Text('${pct.toStringAsFixed(0)}$unit'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              // Track
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Fill
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                widthFactor: (pct / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [barColor.withOpacity(0.6), barColor],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: barColor.withOpacity(0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Temperature Badge ─────────────────────────────────────────────────────────
class _TempBadge extends StatelessWidget {
  final int tempC;
  const _TempBadge({required this.tempC});

  @override
  Widget build(BuildContext context) {
    final color = tempC >= 85 ? NColor.red
                : tempC >= 70 ? NColor.orange
                :               NColor.emerald;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(4),
        color: color.withOpacity(0.08),
      ),
      child: Text(
        '$tempC°C',
        style: TextStyle(
          fontFamily: 'monospace', fontSize: 10,
          color: color, letterSpacing: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

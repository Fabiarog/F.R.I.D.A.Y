// F.R.I.D.A.Y. Mobile — Agent Card Widget
import 'package:flutter/material.dart';
import '../theme/neural_theme.dart';

enum AgentStatus { online, idle, busy, offline }

class AgentCard extends StatelessWidget {
  final String      name;
  final String      description;
  final AgentStatus status;
  final VoidCallback? onTap;

  const AgentCard({
    super.key,
    required this.name,
    required this.description,
    this.status = AgentStatus.idle,
    this.onTap,
  });

  Color get _statusColor {
    switch (status) {
      case AgentStatus.online:  return NColor.emerald;
      case AgentStatus.busy:    return NColor.orange;
      case AgentStatus.offline: return NColor.red;
      default:                  return NColor.cyanDim;
    }
  }

  String get _statusLabel {
    switch (status) {
      case AgentStatus.online:  return 'ONLINE';
      case AgentStatus.busy:    return 'OCUPADO';
      case AgentStatus.offline: return 'OFFLINE';
      default:                  return 'IDLE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: NColor.bgPanel,
          border: Border(
            left: BorderSide(color: color, width: 2),
            top:    BorderSide(color: NColor.border, width: 1),
            right:  BorderSide(color: NColor.border, width: 1),
            bottom: BorderSide(color: NColor.border, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: status != AgentStatus.idle
                    ? [BoxShadow(color: color.withOpacity(0.8), blurRadius: 6)]
                    : [],
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12,
                      color: NColor.textPrimary, letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 10, color: NColor.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: color.withOpacity(0.08),
                border: Border.all(color: color.withOpacity(0.35)),
              ),
              child: Text(
                _statusLabel,
                style: TextStyle(
                  fontFamily: 'monospace', fontSize: 8,
                  color: color, letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

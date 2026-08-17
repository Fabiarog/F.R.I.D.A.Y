// F.R.I.D.A.Y. Mobile — Mode Button Widget
import 'package:flutter/material.dart';
import '../theme/neural_theme.dart';

class ModeButton extends StatefulWidget {
  final IconData icon;
  final String   label;
  final Color?   activeColor;
  final bool     isActive;
  final VoidCallback? onTap;

  const ModeButton({
    super.key,
    required this.icon,
    required this.label,
    this.activeColor,
    this.isActive = false,
    this.onTap,
  });

  @override
  State<ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<ModeButton>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double>   _scaleAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) { _ctrl.forward(); setState(() => _pressed = true); }
  void _onTapUp(_)   { _ctrl.reverse(); setState(() => _pressed = false); }
  void _onCancel()   { _ctrl.reverse(); setState(() => _pressed = false); }

  @override
  Widget build(BuildContext context) {
    final color = widget.activeColor ?? NColor.cyan;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp:   _onTapUp,
      onTapCancel: _onCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: widget.isActive
                ? color.withOpacity(0.12)
                : NColor.bgPanel,
            border: Border.all(
              color: widget.isActive
                  ? color.withOpacity(0.6)
                  : NColor.border,
              width: widget.isActive ? 1.5 : 1,
            ),
            boxShadow: widget.isActive
                ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16)]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: widget.isActive ? color : NColor.textMuted,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: widget.isActive ? color : NColor.textMuted,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

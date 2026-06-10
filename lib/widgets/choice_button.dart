// ============================================================
//  widgets/choice_button.dart  —  Bouton de choix narratif
// ============================================================

import 'package:flutter/material.dart';
import '../models/game_theme.dart';

class ChoiceButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const ChoiceButton({
    super.key,
    required this.label,
    this.enabled = true,
    this.onTap,
  });

  @override
  State<ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<ChoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnimation = Tween(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => _pressController.forward() : null,
        onTapUp: widget.enabled ? (_) => _pressController.reverse() : null,
        onTapCancel: widget.enabled ? () => _pressController.reverse() : null,
        onTap: widget.enabled ? widget.onTap : null,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: widget.enabled
                  ? const Color(0xFF1A1600)
                  : const Color(0xFF141414),
              border: Border.all(
                color: widget.enabled
                    ? GraalTheme.amber
                    : GraalTheme.divider,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Text(
                  widget.enabled ? '▶' : '✕',
                  style: TextStyle(
                    color: widget.enabled
                        ? GraalTheme.amber
                        : GraalTheme.textDim,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: 'Crimson Text',
                      color: widget.enabled
                          ? GraalTheme.textPrimary
                          : GraalTheme.textDim,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

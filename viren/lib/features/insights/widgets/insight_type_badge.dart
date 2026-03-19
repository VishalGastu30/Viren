import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InsightTypeBadge — Standalone badge chip for alert type display.
// Used in InsightCard and anywhere else a type label is needed.
// ─────────────────────────────────────────────────────────────────────────────

class InsightTypeBadge extends StatelessWidget {
  final String label;
  final Color color;
  const InsightTypeBadge({
    required this.label,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

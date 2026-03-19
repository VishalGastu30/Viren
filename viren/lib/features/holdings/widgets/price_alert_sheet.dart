import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers/database_providers.dart';
import '../../../core/database/enums.dart';
import '../../../core/theme/design_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PriceAlertSheet — Bottom sheet for setting stop-loss and price targets.
//
// User-set alerts are stored as special alert rows in the Alerts table:
//   alertType = 'USER_STOP_LOSS'    → fire when price drops below threshold
//   alertType = 'USER_PRICE_TARGET' → fire when price rises above threshold
//
// triggerData JSON format:
//   { "targetPrice": 123.45, "setAt": "2025-01-01T00:00:00.000Z" }
//
// These rows stay alive (dismissedAt = null) until the user clears them
// or they are triggered. When triggered, InsightEngine dismisses them
// (sets dismissedAt) and fires a STOP_LOSS_HIT or PRICE_TARGET_HIT alert.
// ─────────────────────────────────────────────────────────────────────────────

class PriceAlertSheet extends ConsumerStatefulWidget {
  final Holding holding;
  final double? currentPrice;

  const PriceAlertSheet({
    required this.holding,
    this.currentPrice,
    super.key,
  });

  @override
  ConsumerState<PriceAlertSheet> createState() => _PriceAlertSheetState();
}

class _PriceAlertSheetState extends ConsumerState<PriceAlertSheet> {
  final _stopLossController = TextEditingController();
  final _targetController   = TextEditingController();
  bool _saving = false;

  // Existing alert IDs — null means no alert set yet for this type
  String? _existingStopLossId;
  String? _existingTargetId;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _stopLossController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final db = ref.read(appDatabaseProvider);
    final symbol = widget.holding.instrumentSymbol.toUpperCase();

    // Load any active (non-dismissed) user alerts for this symbol
    final existing = await (db.select(db.alerts)
          ..where((a) =>
              a.relatedInstrument.equals(symbol) &
              a.dismissedAt.isNull() &
              (a.alertType.equals('USER_STOP_LOSS') |
               a.alertType.equals('USER_PRICE_TARGET'))))
        .get();

    for (final alert in existing) {
      try {
        final data = jsonDecode(alert.triggerData) as Map<String, dynamic>;
        final price = (data['targetPrice'] as num?)?.toDouble();
        if (price == null) continue;

        if (alert.alertType == 'USER_STOP_LOSS') {
          _stopLossController.text = price.toStringAsFixed(2);
          _existingStopLossId = alert.id;
        } else if (alert.alertType == 'USER_PRICE_TARGET') {
          _targetController.text = price.toStringAsFixed(2);
          _existingTargetId = alert.id;
        }
      } catch (_) {
        continue;
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final db = ref.read(appDatabaseProvider);
    final symbol = widget.holding.instrumentSymbol.toUpperCase();
    final avgCost = widget.holding.averagePrice;
    final uuid = const Uuid();

    try {
      // ── Stop Loss ──────────────────────────────────────────────
      final slText = _stopLossController.text.trim();
      if (slText.isEmpty) {
        // User cleared it — dismiss any existing stop loss
        if (_existingStopLossId != null) {
          await (db.update(db.alerts)
                ..where((a) => a.id.equals(_existingStopLossId!)))
              .write(AlertsCompanion(
            dismissedAt: Value(DateTime.now()),
          ));
        }
      } else {
        final slPrice = double.tryParse(slText);
        if (slPrice != null && slPrice > 0) {
          final data = jsonEncode({
            'targetPrice': slPrice,
            'setAt': DateTime.now().toIso8601String(),
          });

          if (_existingStopLossId != null) {
            // Update existing
            await (db.update(db.alerts)
                  ..where((a) => a.id.equals(_existingStopLossId!)))
                .write(AlertsCompanion(
              triggerData: Value(data),
              dismissedAt: const Value(null),
            ));
          } else {
            // Create new
            final pctBelow = avgCost > 0
                ? ((avgCost - slPrice) / avgCost * 100).toStringAsFixed(1)
                : '?';
            await db.into(db.alerts).insert(
              AlertsCompanion.insert(
                id: uuid.v4(),
                alertType: 'USER_STOP_LOSS',
                severity: AlertSeverity.critical,
                title: 'Stop loss set for $symbol at ₹${slPrice.toStringAsFixed(2)}',
                description:
                    'You will be notified when $symbol falls below '
                    '₹${slPrice.toStringAsFixed(2)} ($pctBelow% below your avg cost '
                    'of ₹${avgCost.toStringAsFixed(2)}).',
                confidence: const Value(100),
                relatedInstrument: Value(symbol),
                triggerData: Value(data),
              ),
            );
          }
        }
      }

      // ── Price Target ───────────────────────────────────────────
      final ptText = _targetController.text.trim();
      if (ptText.isEmpty) {
        if (_existingTargetId != null) {
          await (db.update(db.alerts)
                ..where((a) => a.id.equals(_existingTargetId!)))
              .write(AlertsCompanion(
            dismissedAt: Value(DateTime.now()),
          ));
        }
      } else {
        final ptPrice = double.tryParse(ptText);
        if (ptPrice != null && ptPrice > 0) {
          final data = jsonEncode({
            'targetPrice': ptPrice,
            'setAt': DateTime.now().toIso8601String(),
          });

          if (_existingTargetId != null) {
            await (db.update(db.alerts)
                  ..where((a) => a.id.equals(_existingTargetId!)))
                .write(AlertsCompanion(
              triggerData: Value(data),
              dismissedAt: const Value(null),
            ));
          } else {
            final pctAbove = avgCost > 0
                ? ((ptPrice - avgCost) / avgCost * 100).toStringAsFixed(1)
                : '?';
            await db.into(db.alerts).insert(
              AlertsCompanion.insert(
                id: uuid.v4(),
                alertType: 'USER_PRICE_TARGET',
                severity: AlertSeverity.warning,
                title: 'Price target set for $symbol at ₹${ptPrice.toStringAsFixed(2)}',
                description:
                    'You will be notified when $symbol reaches '
                    '₹${ptPrice.toStringAsFixed(2)} ($pctAbove% above your avg cost '
                    'of ₹${avgCost.toStringAsFixed(2)}).',
                confidence: const Value(100),
                relatedInstrument: Value(symbol),
                triggerData: Value(data),
              ),
            );
          }
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cmp     = widget.currentPrice;
    final avgCost = widget.holding.averagePrice;
    final symbol  = widget.holding.instrumentSymbol.toUpperCase();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price Alerts',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    symbol,
                    style: TextStyle(
                      color: DesignTokens.obsidianTeal,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Context chip: avg cost + current price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _ContextChip(
                    label: 'Avg cost',
                    value: '₹${avgCost.toStringAsFixed(2)}',
                    color: DesignTokens.textMediumContrast,
                  ),
                  if (cmp != null) ...[
                    const SizedBox(height: 4),
                    _ContextChip(
                      label: 'CMP',
                      value: '₹${cmp.toStringAsFixed(2)}',
                      color: cmp >= avgCost
                          ? DesignTokens.obsidianTeal
                          : DesignTokens.crimsonWarning,
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Stop loss field
          _AlertField(
            label: 'Stop Loss',
            sublabel: 'Notify me if price drops below',
            icon: Icons.arrow_downward_rounded,
            iconColor: DesignTokens.crimsonWarning,
            controller: _stopLossController,
            hint: avgCost > 0
                ? '${(avgCost * 0.95).toStringAsFixed(2)} (–5%)'
                : 'e.g. 540.00',
            onClear: _existingStopLossId != null
                ? () {
                    setState(() {
                      _stopLossController.clear();
                    });
                  }
                : null,
          ),

          const SizedBox(height: 16),

          // Price target field
          _AlertField(
            label: 'Price Target',
            sublabel: 'Notify me when price reaches',
            icon: Icons.arrow_upward_rounded,
            iconColor: DesignTokens.obsidianTeal,
            controller: _targetController,
            hint: avgCost > 0
                ? '${(avgCost * 1.10).toStringAsFixed(2)} (+10%)'
                : 'e.g. 650.00',
            onClear: _existingTargetId != null
                ? () {
                    setState(() {
                      _targetController.clear();
                    });
                  }
                : null,
          ),

          const SizedBox(height: 8),
          Text(
            'Leave a field empty to remove that alert.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.textMediumContrast
                      .withValues(alpha: 0.5),
                ),
          ),

          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _saving
                      ? DesignTokens.obsidianTeal.withValues(alpha: 0.4)
                      : DesignTokens.obsidianTeal,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save Alerts',
                          style: TextStyle(
                            color: DesignTokens.graphiteBase,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────

class _AlertField extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color iconColor;
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onClear;

  const _AlertField({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.iconColor,
    required this.controller,
    required this.hint,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteBase,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: DesignTokens.textHighContrast,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  sublabel,
                  style: TextStyle(
                    color: DesignTokens.textMediumContrast,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: TextStyle(
                      color: DesignTokens.textHighContrast,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        color: DesignTokens.textMediumContrast
                            .withValues(alpha: 0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.normal,
                      ),
                      prefix: Text(
                        '₹',
                        style: TextStyle(
                          color: DesignTokens.textMediumContrast,
                          fontSize: 14,
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                if (onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: DesignTokens.textMediumContrast
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ContextChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label  ',
          style: TextStyle(
            color: DesignTokens.textMediumContrast,
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

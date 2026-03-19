import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/providers/database_providers.dart';
import '../../../core/insights/emotion_recall_service.dart';
import '../../../core/theme/design_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TradeNoteDialog — Add or edit a personal note on a trade.
//
// Shown when user taps the note icon on any buy row in
// StockDetailScreen's Investment Journey section.
//
// Notes are stored as EMOTION_NOTE alert rows by EmotionRecallService.
// ─────────────────────────────────────────────────────────────────────────────

class TradeNoteDialog extends ConsumerStatefulWidget {
  final String tradeId;
  final String symbol;
  final DateTime tradeDate;
  final double tradePrice;
  final String? existingNote;

  const TradeNoteDialog({
    required this.tradeId,
    required this.symbol,
    required this.tradeDate,
    required this.tradePrice,
    this.existingNote,
    super.key,
  });

  @override
  ConsumerState<TradeNoteDialog> createState() =>
      _TradeNoteDialogState();
}

class _TradeNoteDialogState extends ConsumerState<TradeNoteDialog> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.existingNote ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final db = ref.read(appDatabaseProvider);
    final service = EmotionRecallService(db);

    await service.saveNote(
      tradeId: widget.tradeId,
      symbol: widget.symbol,
      noteText: _controller.text,
      tradeDate: widget.tradeDate,
      tradePrice: widget.tradePrice,
    );

    if (mounted) Navigator.pop(context, _controller.text.trim());
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    final db = ref.read(appDatabaseProvider);
    final service = EmotionRecallService(db);

    await service.deleteNote(
      tradeId: widget.tradeId,
      symbol: widget.symbol,
    );

    if (mounted) Navigator.pop(context, '');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DesignTokens.graphiteSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note_rounded,
                    color: DesignTokens.obsidianTeal, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Trade Note',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Why did you make this trade?',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DesignTokens.textMediumContrast,
                  ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: DesignTokens.graphiteBase,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 4,
                minLines: 2,
                maxLength: 280,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DesignTokens.textHighContrast,
                    ),
                decoration: InputDecoration(
                  hintText:
                      'e.g. "Buying because RBI paused rates. Thesis: gold rally ahead."',
                  hintStyle: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: DesignTokens.textMediumContrast
                            .withValues(alpha: 0.4),
                      ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                  counterStyle: TextStyle(
                    color: DesignTokens.textMediumContrast
                        .withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.existingNote != null &&
                    widget.existingNote!.isNotEmpty)
                  TextButton.icon(
                    onPressed: _saving ? null : _delete,
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 16,
                        color: DesignTokens.crimsonWarning),
                    label: Text(
                      'Delete',
                      style: TextStyle(
                          color: DesignTokens.crimsonWarning,
                          fontSize: 13),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                        color: DesignTokens.textMediumContrast),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _saving ? null : _save,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _saving
                          ? DesignTokens.obsidianTeal
                              .withValues(alpha: 0.4)
                          : DesignTokens.obsidianTeal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _saving ? 'Saving...' : 'Save',
                      style: TextStyle(
                        color: DesignTokens.graphiteBase,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

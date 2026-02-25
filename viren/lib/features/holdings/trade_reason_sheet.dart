import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';
import '../../mock_data/holdings_mock.dart';

class TradeReasonSheet extends StatefulWidget {
  final String symbol;
  final String? existingReason;
  final List<ConvictionTag> existingTags;
  final EmotionTag? existingEmotion;

  const TradeReasonSheet({
    super.key,
    required this.symbol,
    this.existingReason,
    this.existingTags = const [],
    this.existingEmotion,
  });

  @override
  State<TradeReasonSheet> createState() => _TradeReasonSheetState();
}

class _TradeReasonSheetState extends State<TradeReasonSheet> {
  late TextEditingController _reasonController;
  late List<ConvictionTag> _selectedTags;
  EmotionTag? _selectedEmotion;

  static const _tagLabels = {
    ConvictionTag.longTerm: 'Long-term',
    ConvictionTag.conviction: 'Conviction',
    ConvictionTag.experiment: 'Experiment',
    ConvictionTag.hedge: 'Hedge',
  };

  static const _emotionLabels = {
    EmotionTag.calm: 'Calm',
    EmotionTag.cautious: 'Cautious',
    EmotionTag.excited: 'Excited',
    EmotionTag.fearful: 'Fearful',
    EmotionTag.disciplined: 'Disciplined',
  };

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController(text: widget.existingReason ?? '');
    _selectedTags = List.from(widget.existingTags);
    _selectedEmotion = widget.existingEmotion;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 32 + bottomPad),
      decoration: const BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: DesignTokens.borderSubtle, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: DesignTokens.obsidianTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(widget.symbol, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.obsidianTeal, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ),
            const SizedBox(width: 12),
            Text('Investment Reason', style: Theme.of(context).textTheme.titleLarge),
          ]),
          const SizedBox(height: 6),
          Text(
            'Private. Never shared. Helps Viren surface intent-vs-outcome patterns.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Reason text field
          Container(
            decoration: BoxDecoration(
              color: DesignTokens.graphiteBase,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DesignTokens.borderSubtle),
            ),
            child: TextField(
              controller: _reasonController,
              maxLines: 3,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
              decoration: InputDecoration(
                hintText: 'Why did you enter this position?',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DesignTokens.textMediumContrast),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Conviction tags
          Text('Conviction Tags', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ConvictionTag.values.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) { _selectedTags.remove(tag); } else { _selectedTags.add(tag); }
                }),
                child: AnimatedContainer(
                  duration: AnimationPresets.durationFast,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? DesignTokens.obsidianTeal.withValues(alpha: 0.15) : DesignTokens.graphiteBase,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isSelected ? DesignTokens.obsidianTeal.withValues(alpha: 0.6) : DesignTokens.borderSubtle),
                  ),
                  child: Text(
                    _tagLabels[tag]!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected ? DesignTokens.obsidianTeal : DesignTokens.textMediumContrast,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Emotion tag
          Text('Mood at Entry  (optional, private)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: EmotionTag.values.map((emotion) {
              final isSelected = _selectedEmotion == emotion;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedEmotion = isSelected ? null : emotion;
                }),
                child: AnimatedContainer(
                  duration: AnimationPresets.durationFast,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? DesignTokens.ashGold.withValues(alpha: 0.12) : DesignTokens.graphiteBase,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isSelected ? DesignTokens.ashGold.withValues(alpha: 0.5) : DesignTokens.borderSubtle),
                  ),
                  child: Text(
                    _emotionLabels[emotion]!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected ? DesignTokens.ashGold : DesignTokens.textMediumContrast,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.obsidianTeal,
                foregroundColor: DesignTokens.graphiteBase,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Save Reason', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

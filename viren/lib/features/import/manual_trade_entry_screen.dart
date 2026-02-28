import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';
import '../../core/database/providers/database_providers.dart';
import '../../core/database/enums.dart';

class ManualTradeEntryScreen extends ConsumerStatefulWidget {
  const ManualTradeEntryScreen({super.key});

  @override
  ConsumerState<ManualTradeEntryScreen> createState() =>
      _ManualTradeEntryScreenState();
}

class _ManualTradeEntryScreenState
    extends ConsumerState<ManualTradeEntryScreen> {
  final _symbolController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _reasonController = TextEditingController();
  final _dateController = TextEditingController(text: 'Today');

  String? _selectedAction = 'BUY';
  String? _selectedEmotion;
  bool _isSaving = false;

  final List<String> _tags = [];
  final _availableTags = ['Long-term', 'Conviction', 'Experiment', 'Hedge', 'Speculative'];
  final _emotions = ['Calm', 'Cautious', 'Excited', 'Fearful', 'Disciplined'];

  @override
  void dispose() {
    _symbolController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _reasonController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_tags.contains(tag)) {
        _tags.remove(tag);
      } else {
        _tags.add(tag);
      }
    });
  }

  Future<void> _saveTrade() async {
    final symbol = _symbolController.text.trim();
    final quantityText = _quantityController.text.trim();
    final priceText = _priceController.text.trim();

    if (symbol.isEmpty || quantityText.isEmpty || priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Symbol, Quantity, and Price are required.'),
          backgroundColor: DesignTokens.crimsonWarning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final quantity = double.tryParse(quantityText);
    final price = double.tryParse(priceText);

    if (quantity == null || quantity <= 0 || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Quantity and Price must be valid positive numbers.'),
          backgroundColor: DesignTokens.crimsonWarning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(tradeRepositoryProvider);

      // Map emotion string to enum value.
      EmotionalState? emotionEnum;
      if (_selectedEmotion != null) {
        emotionEnum = EmotionalState.values.firstWhere(
          (e) => e.name.toLowerCase() == _selectedEmotion!.toLowerCase(),
          orElse: () => EmotionalState.calm,
        );
      }

      await repo.insertTrade(
        instrumentSymbol: symbol.toUpperCase(),
        instrumentName: symbol.toUpperCase(), // Name resolved later via price data
        tradeType: _selectedAction == 'BUY' ? TradeType.buy : TradeType.sell,
        quantity: quantity,
        pricePerUnit: price,
        tradeTimestamp: DateTime.now().toUtc(),
        source: TradeSource.manual,
        reasonText: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
        tags: List.from(_tags),
        emotionalState: emotionEnum,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trade for $symbol recorded.'),
            backgroundColor: DesignTokens.obsidianTeal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving trade: ${e.toString()}'),
            backgroundColor: DesignTokens.crimsonWarning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        title: Text('Manual Entry', style: Theme.of(context).textTheme.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          _isSaving 
            ? const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: DesignTokens.obsidianTeal))))
            : TextButton(
                onPressed: _saveTrade,
                child: Text('Save', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: DesignTokens.obsidianTeal, fontWeight: FontWeight.w600)),
              ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action & Symbol
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: DesignTokens.graphiteSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: DesignTokens.borderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedAction,
                        dropdownColor: DesignTokens.graphiteSurface,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: DesignTokens.textMediumContrast),
                        items: ['BUY', 'SELL'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: Theme.of(context).textTheme.titleMedium))).toList(),
                        onChanged: (v) => setState(() => _selectedAction = v),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _buildTextField(_symbolController, 'Symbol', textCapitalization: TextCapitalization.characters),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Quantity & Price
            Row(
              children: [
                Expanded(child: _buildTextField(_quantityController, 'Shares', isNumber: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(_priceController, 'Price', isNumber: true, prefix: '₹')),
              ],
            ),
            
            const SizedBox(height: 16),
            _buildTextField(_dateController, 'Date (Optional)'),

            const SizedBox(height: 36),
            Text('Why this trade?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Capturing your thesis now helps Viren hold you accountable later.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, height: 1.4)),
            const SizedBox(height: 16),
            
            _buildTextField(_reasonController, 'Investment reason or thesis (Optional)', maxLines: 3),
            
            const SizedBox(height: 24),
            Text('Conviction Tags', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTags.map((tag) {
                final isSelected = _tags.contains(tag);
                return GestureDetector(
                  onTap: () => _toggleTag(tag),
                  child: AnimatedContainer(
                    duration: AnimationPresets.durationFast,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? DesignTokens.obsidianTeal.withValues(alpha: 0.15) : DesignTokens.graphiteBase,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? DesignTokens.obsidianTeal.withValues(alpha: 0.5) : DesignTokens.graphiteSurface),
                    ),
                    child: Text(
                      tag,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isSelected ? DesignTokens.obsidianTeal : DesignTokens.textMediumContrast,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),
            Text('Private Emotion Label', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('How are you feeling about this decision?', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emotions.map((emo) {
                final isSelected = _selectedEmotion == emo;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmotion = isSelected ? null : emo),
                  child: AnimatedContainer(
                    duration: AnimationPresets.durationFast,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? DesignTokens.ashGold.withValues(alpha: 0.15) : DesignTokens.graphiteSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? DesignTokens.ashGold.withValues(alpha: 0.5) : Colors.transparent),
                    ),
                    child: Text(
                      emo,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isSelected ? DesignTokens.ashGold : DesignTokens.textMediumContrast,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false, int maxLines = 1, String? prefix, TextCapitalization textCapitalization = TextCapitalization.none}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.borderSubtle),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        maxLines: maxLines,
        textCapitalization: textCapitalization,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DesignTokens.textMediumContrast),
          border: InputBorder.none,
          prefixText: prefix != null ? '$prefix ' : null,
          prefixStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(color: DesignTokens.textMediumContrast),
        ),
      ),
    );
  }
}

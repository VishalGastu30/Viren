import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

class ColumnMappingScreen extends StatefulWidget {
  const ColumnMappingScreen({super.key});

  @override
  State<ColumnMappingScreen> createState() => _ColumnMappingScreenState();
}

class _ColumnMappingScreenState extends State<ColumnMappingScreen> {
  // Mock extracted headers
  final List<String> _csvHeaders = ['Date', 'Stock Symbol', 'Transaction Type', 'Qty', 'Execution Price', 'Brokerage', 'ISIN'];
  
  // Target schema fields required by Viren
  final List<String> _targetFields = ['date', 'symbol', 'action', 'quantity', 'price'];
  
  // Current mapping state (target field -> source header index)
  final Map<String, int?> _mapping = {};

  @override
  void initState() {
    super.initState();
    // Auto-map some obvious ones for the mock
    _mapping['date'] = 0;
    _mapping['symbol'] = 1;
    _mapping['action'] = 2;
    _mapping['quantity'] = 3;
    _mapping['price'] = 4;
  }

  void _finishMapping() {
    // Validate required fields
    if (_mapping.values.any((element) => element == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please map all required Viren fields.'),
          backgroundColor: DesignTokens.crimsonWarning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Simulate import success
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Mapped and starting import...'),
        backgroundColor: DesignTokens.obsidianTeal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        title: Text('Map Columns', style: Theme.of(context).textTheme.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _finishMapping,
            child: Text('Done', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: DesignTokens.obsidianTeal, fontWeight: FontWeight.w600)),
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
            Text('We found 7 columns in your file.', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            Text('Viren has auto-matched the obvious ones. Please confirm the mapping before we import the records.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DesignTokens.textMediumContrast, height: 1.4)),
            const SizedBox(height: 36),

            // Header Row
            Row(
              children: [
                Expanded(child: Text('VIREN FIELD', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, letterSpacing: 1))),
                const SizedBox(width: 16),
                Expanded(child: Text('YOUR CSV COLUMN', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, letterSpacing: 1))),
              ],
            ),
            const SizedBox(height: 16),

            // Mapping Rows
            ..._targetFields.map((field) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: DesignTokens.graphiteSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Text(field.toUpperCase(), style: Theme.of(context).textTheme.titleMedium),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: DesignTokens.graphiteSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _mapping[field] == null ? DesignTokens.crimsonWarning : DesignTokens.obsidianTeal.withValues(alpha: 0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            dropdownColor: DesignTokens.graphiteSurface,
                            icon: const Icon(Icons.arrow_drop_down_rounded, color: DesignTokens.textMediumContrast),
                            value: _mapping[field],
                            hint: Text('Select...', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DesignTokens.textMediumContrast)),
                            items: _csvHeaders.asMap().entries.map((e) {
                              return DropdownMenuItem<int>(
                                value: e.key,
                                child: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _mapping[field] = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: DesignTokens.ashGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DesignTokens.ashGold.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: DesignTokens.ashGold, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Unmapped columns like "Brokerage" and "ISIN" will be ignored. Your original file is never modified or uploaded to any server.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.ashGold, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

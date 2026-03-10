import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

/// Top-level entry point. Parses a model response and renders
/// text blocks, tables, stat cards, and ranked lists natively.
class MessageRenderer extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;

  const MessageRenderer({
    super.key,
    required this.text,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = _ResponseParser.parse(text);
    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks.map((b) => _renderBlock(context, b)).toList(),
    );
  }

  Widget _renderBlock(BuildContext context, _Block block) {
    switch (block.type) {
      case _BlockType.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            block.content,
            style: textStyle ??
                Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DesignTokens.textHighContrast,
                      height: 1.65,
                    ),
          ),
        );
      case _BlockType.table:
        return _TableWidget(rows: block.rows);
      case _BlockType.statCard:
        return _StatCardWidget(label: block.label, value: block.value);
      case _BlockType.rankedList:
        return _RankedListWidget(items: block.items);
    }
  }
}

// ─── Parser ───────────────────────────────────────────────────────────────────

enum _BlockType { text, table, statCard, rankedList }

class _Block {
  final _BlockType type;

  // text block
  final String content;

  // table block
  final List<String> rows;

  // stat card
  final String label;
  final String value;

  // ranked list
  final List<_RankedItem> items;

  const _Block.text(this.content)
      : type = _BlockType.text,
        rows = const [],
        label = '',
        value = '',
        items = const [];

  const _Block.table(this.rows)
      : type = _BlockType.table,
        content = '',
        label = '',
        value = '',
        items = const [];



  const _Block.rankedList(this.items)
      : type = _BlockType.rankedList,
        content = '',
        rows = const [],
        label = '',
        value = '';
}

class _RankedItem {
  final int rank;
  final String symbol;
  final String metric;
  final bool isPositive;
  final double? magnitude; // 0.0 to 1.0 for bar width

  const _RankedItem({
    required this.rank,
    required this.symbol,
    required this.metric,
    required this.isPositive,
    this.magnitude,
  });
}

class _ResponseParser {
  static List<_Block> parse(String raw) {
    final blocks = <_Block>[];
    final lines = raw.trim().split('\n');

    final textBuffer = StringBuffer();
    List<String>? tableRows;
    bool inTable = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line == 'TABLE:') {
        // Flush text before table
        _flushText(textBuffer, blocks);
        tableRows = [];
        inTable = true;
        continue;
      }

      if (line == 'END_TABLE') {
        if (tableRows != null && tableRows.isNotEmpty) {
          blocks.add(_Block.table(tableRows));
        }
        tableRows = null;
        inTable = false;
        continue;
      }

      if (inTable) {
        if (line.isNotEmpty) tableRows!.add(line);
        continue;
      }

      textBuffer.writeln(line);
    }

    // Handle incomplete table — model ran out of tokens before END_TABLE
    if (inTable && tableRows != null && tableRows.isNotEmpty) {
      blocks.add(_Block.table(tableRows));
    }

    // Flush remaining text
    _flushText(textBuffer, blocks);

    // Post-process: detect stat cards and ranked lists from text blocks
    return _detectSpecialBlocks(blocks);
  }

  static void _flushText(StringBuffer buffer, List<_Block> blocks) {
    final text = buffer.toString().trim();
    if (text.isNotEmpty) {
      blocks.add(_Block.text(text));
    }
    buffer.clear();
  }

  /// Detect patterns in text blocks and convert to richer types.
  static List<_Block> _detectSpecialBlocks(List<_Block> blocks) {
    final result = <_Block>[];

    for (final block in blocks) {
      if (block.type != _BlockType.text) {
        result.add(block);
        continue;
      }

      // Try ranked list detection
      final ranked = _tryParseRankedList(block.content);
      if (ranked != null) {
        result.add(ranked);
        continue;
      }

      result.add(block);
    }

    return result;
  }

  /// Detects numbered ranking patterns like:
  /// "1. INFY - +18.4%"
  /// "1) TCS: +12.1%"
  static _Block? _tryParseRankedList(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.length < 2) return null;

    // Must have at least 2 lines that look like ranked items
    final rankPattern = RegExp(
        r'^(\d+)[.)]\s+([A-Z]{1,10})[\s\-:]+(.+)$',
        caseSensitive: false);

    final items = <_RankedItem>[];
    for (final line in lines) {
      final match = rankPattern.firstMatch(line);
      if (match == null) break;

      final rank = int.tryParse(match.group(1)!) ?? items.length + 1;
      final symbol = match.group(2)!.toUpperCase();
      final metric = match.group(3)!.trim();

      // Extract sign and magnitude from metric
      final isPositive = !metric.contains('-') || metric.contains('+');
      double? magnitude;
      final pctMatch =
          RegExp(r'(\d+\.?\d*)%').firstMatch(metric);
      if (pctMatch != null) {
        final pct = double.tryParse(pctMatch.group(1)!) ?? 0;
        magnitude = (pct / 50).clamp(0.0, 1.0); // normalise to 0-1
      }

      items.add(_RankedItem(
        rank: rank,
        symbol: symbol,
        metric: metric,
        isPositive: isPositive,
        magnitude: magnitude,
      ));
    }

    if (items.length >= 2) return _Block.rankedList(items);
    return null;
  }
}

// ─── Table Widget ─────────────────────────────────────────────────────────────

class _TableWidget extends StatelessWidget {
  final List<String> rows;
  const _TableWidget({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final headers =
        rows.first.split('|').map((h) => h.trim()).toList();
    final dataRows = rows.skip(1).map((r) {
      final cells = r.split('|').map((c) => c.trim()).toList();
      // Pad or trim to match header count
      while (cells.length < headers.length) {
        cells.add('—');
      }
      return cells.take(headers.length).toList();
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: DesignTokens.obsidianTeal.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row
              _buildHeaderRow(headers),
              // Divider under header
              Container(
                height: 1,
                color: DesignTokens.obsidianTeal.withValues(alpha: 0.35),
              ),
              // Data rows
              ...dataRows.asMap().entries.map((entry) {
                final isLast = entry.key == dataRows.length - 1;
                return Column(
                  children: [
                    _buildDataRow(entry.value, entry.key, headers.length),
                    if (!isLast)
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(List<String> headers) {
    return Container(
      color: DesignTokens.obsidianTeal.withValues(alpha: 0.1),
      child: IntrinsicHeight(
        child: Row(
          children: headers.asMap().entries.map((entry) {
            final isLast = entry.key == headers.length - 1;
            return _buildCell(
              text: entry.value,
              isHeader: true,
              showRightBorder: !isLast,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDataRow(List<String> cells, int rowIndex, int colCount) {
    final isAlt = rowIndex.isOdd;
    return Container(
      color: isAlt
          ? Colors.white.withValues(alpha: 0.015)
          : Colors.transparent,
      child: IntrinsicHeight(
        child: Row(
          children: cells.asMap().entries.map((entry) {
            final isLast = entry.key == cells.length - 1;
            final text = entry.value;

            // Detect positive/negative values for colour coding
            final isPositive =
                text.contains('+') && !text.startsWith('-');
            final isNegative = text.startsWith('-') ||
                (text.contains('-') && !text.contains('+'));

            return _buildCell(
              text: text,
              isHeader: false,
              showRightBorder: !isLast,
              valueColor: isPositive
                  ? const Color(0xFF4ECDC4)
                  : isNegative
                      ? const Color(0xFFFF6B6B)
                      : null,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCell({
    required String text,
    required bool isHeader,
    required bool showRightBorder,
    Color? valueColor,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 72, maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: showRightBorder
            ? Border(
                right: BorderSide(
                  color: DesignTokens.obsidianTeal.withValues(alpha: 0.2),
                ),
              )
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isHeader
              ? DesignTokens.obsidianTeal
              : valueColor ?? DesignTokens.textHighContrast,
          fontSize: isHeader ? 11 : 13,
          fontWeight:
              isHeader ? FontWeight.w700 : FontWeight.w400,
          letterSpacing: isHeader ? 0.8 : 0,
          height: 1.4,
        ),
      ),
    );
  }
}

// ─── Stat Card Widget ─────────────────────────────────────────────────────────

class _StatCardWidget extends StatelessWidget {
  final String label;
  final String value;
  const _StatCardWidget({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isPositive =
        value.contains('+') || (!value.contains('-') && value.contains('%'));
    final isNegative = value.startsWith('-');

    final valueColor = isPositive
        ? const Color(0xFF4ECDC4)
        : isNegative
            ? const Color(0xFFFF6B6B)
            : DesignTokens.ashGold;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: valueColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: DesignTokens.textMediumContrast,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 28,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ranked List Widget ───────────────────────────────────────────────────────

class _RankedListWidget extends StatelessWidget {
  final List<_RankedItem> items;
  const _RankedListWidget({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: DesignTokens.obsidianTeal.withValues(alpha: 0.2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final isLast = i == items.length - 1;

          final barColor = item.isPositive
              ? const Color(0xFF4ECDC4)
              : const Color(0xFFFF6B6B);

          final metricColor = item.isPositive
              ? const Color(0xFF4ECDC4)
              : const Color(0xFFFF6B6B);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  children: [
                    // Rank number
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: item.rank == 1
                            ? DesignTokens.obsidianTeal
                                .withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: item.rank == 1
                              ? DesignTokens.obsidianTeal
                                  .withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${item.rank}',
                          style: TextStyle(
                            color: item.rank == 1
                                ? DesignTokens.obsidianTeal
                                : DesignTokens.textMediumContrast,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Symbol
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.symbol,
                        style: TextStyle(
                          color: DesignTokens.textHighContrast,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    // Bar + metric
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item.metric,
                            style: TextStyle(
                              color: metricColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (item.magnitude != null) ...[
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: item.magnitude!,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.06),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                  barColor.withValues(alpha: 0.7),
                                ),
                                minHeight: 3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
